"""Arena policy network — the numpy twin of game/arena/neural_policy.gd.

ONE architecture serves both nets Ricardo asked for (docs/design/23):
  - per-species nets: fine-tuned per creature type / build (embedding row "*")
  - the GLOBAL net: one weight set + one embedding row per content id
    (species / build), learning from every episode of every matchup
    (canon §9 §5: new content = new embedding rows, never new tensor shapes).

Layout (must match the GDScript runtime exactly):
  input  = obs[OBS_DIM] ++ embedding[EMB_DIM]
  hidden = arch.hidden, arch.activation — [64, 64] tanh by default
  head   = HEAD_DIM linear: [move_x, move_y, logit x ACTION_LOGITS, dodge_logit]

WIDTH IS A PARAMETER (Ricardo, 2026-09-13: "train bigger models and use them to
distill smaller ones"). The Godot runtime reads whatever layer shapes the JSON
carries, so a wide net LOADS and RUNS — it is just slower: 7,744 MACs costs
105 us/tick in C++, a 256x256 net is 80,128 MACs and ~1.09 ms, and fifteen of
those eat a whole 60 FPS frame. So a wide net is a TEACHER, never a shipped
policy; ml/training/distill.py turns one into a 64x64 student that can ship.
Only the DEFAULT is (64, 64) — pass `hidden=` to build something else.

THE SHAPE IS A PARAMETER TOO (Ricardo, 2026-09-13: "net hyperparams should be
configurable, as to test new architectures"). Width, activation, init and init
scale all live in one ml.training.arch.Arch, named in
ml/training/architectures.json, and every trainer takes the same `--net` flag.
A net carries its own arch in both its .npz and its exported JSON, so a relu
teacher loads and runs as a relu teacher no matter what the default says.

Weights are stored as .npz for training and exported as JSON (schema
"arena.policy.v1") for the Godot runtime.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ml.training.arch import (Arch, activation_grad,  # noqa: E402
                              apply_activation, resolve)

OBS_DIM = 31
EMB_DIM = 16
ACTION_LOGITS = 7
HEAD_DIM = 2 + ACTION_LOGITS + 1
HIDDEN = (64, 64)
POLICY_SCHEMA = "arena.policy.v1"

INIT_SCALE = 0.1        # the default Arch's scale; kept as a name for old callers
DEFAULT_ARCH = Arch()


def parse_hidden(spec: str | None) -> tuple[int, ...]:
    """"256,256" -> (256, 256). Empty/None -> the default HIDDEN."""
    if not spec:
        return HIDDEN
    sizes = tuple(int(x) for x in str(spec).replace(" ", "").split(",") if x)
    if not sizes or any(n < 1 for n in sizes):
        raise ValueError(f"bad hidden spec {spec!r} — want e.g. '256,256'")
    return sizes


def layer_sizes(hidden: tuple[int, ...] | None = None) -> list[int]:
    return [OBS_DIM + EMB_DIM, *(hidden or HIDDEN), HEAD_DIM]


def macs(hidden: tuple[int, ...] | None = None) -> int:
    """Multiply-accumulates per forward pass — the number that decides whether a
    net can run in the game at all (see the module docstring)."""
    sizes = layer_sizes(hidden)
    return sum(sizes[i] * sizes[i + 1] for i in range(len(sizes) - 1))


class PolicyNet:
    """A small MLP + content-id embedding table."""

    def __init__(self, seed: int = 0, hidden: tuple[int, ...] | str | None = None,
                 arch: Arch | None = None):
        """`arch` is the whole shape; `hidden` is the older width-only shortcut and
        still works (it overrides the arch's width, so `PolicyNet(hidden=...)` in
        existing code keeps meaning exactly what it meant)."""
        self.arch = arch or DEFAULT_ARCH
        if hidden:
            h = parse_hidden(hidden) if isinstance(hidden, str) else tuple(hidden)
            if h != self.arch.hidden:
                self.arch = Arch.from_dict({**self.arch.to_dict(), "hidden": list(h)},
                                           name=self.arch.name)
        self.hidden = self.arch.hidden
        rng = np.random.default_rng(seed)
        sizes = layer_sizes(self.hidden)
        self.weights = [
            self.arch.init_weight(rng, sizes[i + 1], sizes[i]).astype(np.float32)
            for i in range(len(sizes) - 1)
        ]
        self.biases = [np.zeros(sizes[i + 1], dtype=np.float32) for i in range(len(sizes) - 1)]
        self.embeddings: dict[str, np.ndarray] = {}

    @property
    def acts(self) -> list[str]:
        """Per-layer activation names, the hidden ones from the arch and the head
        always linear. This list IS the contract the runtimes read."""
        return self.arch.layer_acts(len(self.weights))

    # ---- embeddings ---------------------------------------------------------

    def ensure_embedding(self, key: str, seed: int = 0) -> np.ndarray:
        """New content = a new embedding row, initialized from the table mean
        (canon §9 §5 warm-start rule) — never a new tensor shape."""
        if key not in self.embeddings:
            rng = np.random.default_rng(abs(hash((key, seed))) % (2**32))
            if self.embeddings:
                mean = np.mean(np.stack(list(self.embeddings.values())), axis=0)
                self.embeddings[key] = (mean + rng.normal(0.0, 0.01, EMB_DIM)).astype(np.float32)
            else:
                self.embeddings[key] = rng.normal(0.0, INIT_SCALE, EMB_DIM).astype(np.float32)
        return self.embeddings[key]

    # ---- forward ------------------------------------------------------------

    def forward(self, obs: np.ndarray, key: str = "*") -> np.ndarray:
        assert obs.shape[-1] == OBS_DIM, f"obs must be [{OBS_DIM}] (arena.obs.v1)"
        x = np.concatenate([obs, self.ensure_embedding(key)])
        for (w, b, a) in zip(self.weights, self.biases, self.acts):
            x = apply_activation(w @ x + b, a)
        return x

    def act(self, obs: np.ndarray, key: str = "*") -> tuple[np.ndarray, int, bool]:
        """Mirror of the GDScript _act: move vector, argmax action, dodge flag."""
        y = self.forward(obs, key)
        move = np.clip(y[0:2], -1.0, 1.0)
        pick = int(np.argmax(y[2 : 2 + ACTION_LOGITS]))
        dodge = bool(y[2 + ACTION_LOGITS] > 0.0)
        return move, pick, dodge

    # ---- flat parameter vector (ES / evolution) -------------------------------

    def flat(self) -> np.ndarray:
        parts = [w.ravel() for w in self.weights] + [b.ravel() for b in self.biases]
        parts += [e.ravel() for e in self.embeddings.values()]
        return np.concatenate(parts)

    def set_flat(self, vec: np.ndarray) -> None:
        i = 0
        for w in self.weights:
            w[:] = vec[i : i + w.size].reshape(w.shape)
            i += w.size
        for b in self.biases:
            b[:] = vec[i : i + b.size]
            i += b.size
        for e in self.embeddings.values():
            e[:] = vec[i : i + e.size].reshape(e.shape)
            i += e.size

    def clone(self) -> "PolicyNet":
        other = PolicyNet(arch=self.arch)
        other.weights = [w.copy() for w in self.weights]
        other.biases = [b.copy() for b in self.biases]
        other.embeddings = {k: v.copy() for k, v in self.embeddings.items()}
        return other

    # ---- serialization ---------------------------------------------------------

    def save_npz(self, path: str | Path) -> None:
        payload = {f"w{i}": w for i, w in enumerate(self.weights)}
        payload.update({f"b{i}": b for i, b in enumerate(self.biases)})
        keys = list(self.embeddings.keys())
        payload["emb_keys"] = np.array(keys)
        payload["hidden"] = np.array(self.hidden, dtype=np.int64)
        # The whole arch, not just the width: a relu teacher that reloaded as a
        # tanh teacher would silently be a DIFFERENT net with the same weights.
        payload["arch"] = np.array(json.dumps(self.arch.to_dict()))
        for k in keys:
            payload[f"emb:{k}"] = self.embeddings[k]
        np.savez(path, **payload)

    @staticmethod
    def load_npz(path: str | Path) -> "PolicyNet":
        data = np.load(path, allow_pickle=False)
        # Depth comes from the file, not from the module default: a teacher
        # saved at 256x256 has to load as 256x256 even while HIDDEN says 64x64.
        # `hidden` was added with variable width, so nets saved before it fall
        # back to counting w{i} keys — which gives the old shape exactly.
        n_layers = sum(1 for k in data.files if k.startswith("w") and k[1:].isdigit())
        hidden = (tuple(int(x) for x in data["hidden"]) if "hidden" in data.files
                  else tuple(data[f"w{i}"].shape[0] for i in range(n_layers - 1)))
        # Same story for the rest of the arch: `arch` arrived with configurable
        # hyperparameters, and every net saved before it was tanh/normal/0.1.
        arch = (Arch.from_dict(json.loads(str(data["arch"]))) if "arch" in data.files
                else Arch(hidden=hidden))
        net = PolicyNet(arch=arch, hidden=hidden)
        net.weights = [data[f"w{i}"] for i in range(n_layers)]
        net.biases = [data[f"b{i}"] for i in range(n_layers)]
        net.embeddings = {str(k): data[f"emb:{k}"] for k in data["emb_keys"]}
        return net

    def export_game_json(self, path: str | Path, explore: float = 0.05) -> None:
        """The exact file game/arena/neural_policy.gd consumes."""
        acts = self.acts
        doc = {
            "schema": POLICY_SCHEMA,
            "obs_dim": OBS_DIM,
            "emb_dim": EMB_DIM,
            "explore": explore,
            # Metadata: the runtime reads the layer shapes and each layer's "act"
            # and ignores these, but a net on disk should be able to say how big
            # it is and which preset it came from.
            "hidden": list(self.hidden),
            "macs": macs(self.hidden),
            "arch": self.arch.to_dict(),
            "embeddings": {k: [float(x) for x in v] for k, v in self.embeddings.items()},
            "layers": [
                {"w": [[float(x) for x in row] for row in w], "b": [float(x) for x in b], "act": a}
                for w, b, a in zip(self.weights, self.biases, acts)
            ],
        }
        Path(path).write_text(json.dumps(doc))
