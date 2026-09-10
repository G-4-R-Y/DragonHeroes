"""Arena policy network — the numpy twin of game/arena/neural_policy.gd.

ONE architecture serves both nets Ricardo asked for (docs/design/23):
  - per-species nets: fine-tuned per creature type / build (embedding row "*")
  - the GLOBAL net: one weight set + one embedding row per content id
    (species / build), learning from every episode of every matchup
    (canon §9 §5: new content = new embedding rows, never new tensor shapes).

Layout (must match the GDScript runtime exactly):
  input  = obs[OBS_DIM] ++ embedding[EMB_DIM]
  hidden = [64, 64] tanh
  head   = HEAD_DIM linear: [move_x, move_y, logit x ACTION_LOGITS, dodge_logit]

Weights are stored as .npz for training and exported as JSON (schema
"arena.policy.v1") for the Godot runtime.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

OBS_DIM = 31
EMB_DIM = 16
ACTION_LOGITS = 7
HEAD_DIM = 2 + ACTION_LOGITS + 1
HIDDEN = (64, 64)
POLICY_SCHEMA = "arena.policy.v1"

INIT_SCALE = 0.1


def layer_sizes() -> list[int]:
    return [OBS_DIM + EMB_DIM, *HIDDEN, HEAD_DIM]


class PolicyNet:
    """A small MLP + content-id embedding table."""

    def __init__(self, seed: int = 0):
        rng = np.random.default_rng(seed)
        sizes = layer_sizes()
        self.weights = [
            rng.normal(0.0, INIT_SCALE, size=(sizes[i + 1], sizes[i])).astype(np.float32)
            for i in range(len(sizes) - 1)
        ]
        self.biases = [np.zeros(sizes[i + 1], dtype=np.float32) for i in range(len(sizes) - 1)]
        self.embeddings: dict[str, np.ndarray] = {}

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
        for i, (w, b) in enumerate(zip(self.weights, self.biases)):
            x = w @ x + b
            if i < len(self.weights) - 1:
                x = np.tanh(x)
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
        other = PolicyNet()
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
        for k in keys:
            payload[f"emb:{k}"] = self.embeddings[k]
        np.savez(path, **payload)

    @staticmethod
    def load_npz(path: str | Path) -> "PolicyNet":
        data = np.load(path, allow_pickle=False)
        net = PolicyNet()
        net.weights = [data[f"w{i}"] for i in range(len(layer_sizes()) - 1)]
        net.biases = [data[f"b{i}"] for i in range(len(layer_sizes()) - 1)]
        net.embeddings = {str(k): data[f"emb:{k}"] for k in data["emb_keys"]}
        return net

    def export_game_json(self, path: str | Path, explore: float = 0.05) -> None:
        """The exact file game/arena/neural_policy.gd consumes."""
        acts = ["tanh"] * (len(self.weights) - 1) + ["linear"]
        doc = {
            "schema": POLICY_SCHEMA,
            "obs_dim": OBS_DIM,
            "emb_dim": EMB_DIM,
            "explore": explore,
            "embeddings": {k: [float(x) for x in v] for k, v in self.embeddings.items()},
            "layers": [
                {"w": [[float(x) for x in row] for row in w], "b": [float(x) for x in b], "act": a}
                for w, b, a in zip(self.weights, self.biases, acts)
            ],
        }
        Path(path).write_text(json.dumps(doc))
