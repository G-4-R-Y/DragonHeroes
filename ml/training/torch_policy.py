"""Torch policy/value net — the GPU twin of ml/training/policy_net.py.

Same contract (so anything trained here still DEPLOYS to the Godot arena):
  input  = obs[31] ++ embedding[16]          (arena.obs.v1 + content row)
  hidden = arch.hidden, arch.activation      ([64, 64] tanh by default)
  heads  = move[2] (RAW — the runtime clips, see below), act logits[7],
           dodge logit[1]
plus a PPO value head (NOT exported — the Godot runtime is policy-only).

The shape comes from ml.training.arch — the SAME Arch the numpy stack and the
Godot runtime use, so `--net relu-wide` means one thing across all of them
(Ricardo, 2026-09-13: "net hyperparams should be configurable, as to test new
architectures"). Only the hidden activation is configurable: the heads are fixed
by the arena's action contract, not by the architecture.

Continuity: `from_policy_net` warm-starts from the numpy ES registry weights,
`export_policy_v1` writes schema "arena.policy.v1" JSON that
game/arena/neural_policy.gd loads verbatim — ES → PPO → Godot, one format.
"""
from __future__ import annotations

import json

import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn

ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ml.training.arch import Arch  # noqa: E402
from ml.env.dh_env import MASK_NEG, MASK_SCHEMA  # noqa: E402

OBS_DIM = 31
EMB_DIM = 16
ACTION_LOGITS = 7
HIDDEN = (64, 64)
LEAKY_SLOPE = 0.01      # must equal ml.training.arch.LEAKY_SLOPE
POLICY_SCHEMA = "arena.policy.v1"


def _activate(x: torch.Tensor, name: str) -> torch.Tensor:
    """The torch twin of ml.training.arch.apply_activation. Exactness across the
    two is NOT required here (torch trains, it never serves) — but the SHAPE of
    the function is, or the exported weights mean something else in the arena."""
    if name == "tanh":
        return torch.tanh(x)
    if name == "relu":
        return torch.relu(x)
    if name == "leaky_relu":
        return torch.nn.functional.leaky_relu(x, LEAKY_SLOPE)
    return x


def _init_linear(lin: nn.Linear, arch: Arch) -> None:
    fan_in = lin.weight.shape[1]
    if arch.init == "he":
        nn.init.normal_(lin.weight, 0.0, (2.0 / fan_in) ** 0.5)
    elif arch.init == "xavier":
        nn.init.normal_(lin.weight, 0.0, (1.0 / fan_in) ** 0.5)
    else:
        nn.init.normal_(lin.weight, 0.0, arch.init_scale)
    nn.init.zeros_(lin.bias)


class TorchGRUPolicyNet(nn.Module):
    """Recurrent variant (the architecture-diversity tier, docs/tech/32):
    obs+emb -> GRU(64) -> same heads. Carries temporal state so kiting
    patterns, windup baits and combo windows become learnable — things the
    Markov-ish MLP cannot represent. PPO threads the hidden state through
    rollouts and stores per-horizon h0 for the update (truncated BPTT).

    NOTE: exports as MLP-shaped policy_v1 are NOT supported (the Godot runtime
    is stateless MLP today) — GRU candidates gate via dh-env eval until the
    Godot neural policy grows a recurrent path.
    """

    def __init__(self, keys: list[str] | None = None, obs_dim: int = OBS_DIM):
        super().__init__()
        self.keys = list(keys or ["*"])
        self.key_to_idx = {k: i for i, k in enumerate(self.keys)}
        self.embeddings = nn.Embedding(len(self.keys), EMB_DIM)
        nn.init.normal_(self.embeddings.weight, 0.0, 0.1)
        self.input = nn.Linear(obs_dim + EMB_DIM, HIDDEN[0])
        nn.init.normal_(self.input.weight, 0.0, 0.1)
        nn.init.zeros_(self.input.bias)
        self.gru = nn.GRUCell(HIDDEN[0], HIDDEN[1])
        self.head_move = nn.Linear(HIDDEN[-1], 2)
        self.head_act = nn.Linear(HIDDEN[-1], ACTION_LOGITS)
        self.head_dodge = nn.Linear(HIDDEN[-1], 1)
        self.head_value = nn.Linear(HIDDEN[-1], 1)
        for h in (self.head_move, self.head_act, self.head_dodge):
            nn.init.normal_(h.weight, 0.0, 0.01)
            nn.init.zeros_(h.bias)
        nn.init.normal_(self.head_value.weight, 0.0, 1.0)
        nn.init.zeros_(self.head_value.bias)

    def initial_state(self, batch: int, device) -> torch.Tensor:
        return torch.zeros(batch, HIDDEN[1], device=device)

    def forward(self, obs: torch.Tensor, key: str, h: torch.Tensor):
        """obs[B,31], h[B,64] -> (raw move, logits, dodge, value, h')."""
        idx = torch.full((obs.shape[0],), self.key_to_idx.get(key, 0),
                         dtype=torch.long, device=obs.device)
        x = torch.tanh(self.input(torch.cat([obs, self.embeddings(idx)], -1)))
        h = self.gru(x, h)
        return (self.head_move(h), self.head_act(h),
                self.head_dodge(h).squeeze(-1), self.head_value(h).squeeze(-1), h)


# WHY THE MOVE HEAD IS NOT SQUASHED (2026-09-14)
# The runtime contract is CLIP, not tanh: policy_net.act does
# `np.clip(y[0:2], -1, 1)`, export_policy_v1 folds the three heads into one
# "linear" layer, and pack_for_cpp hands the same raw weights to the C++
# self-play opponent. Squashing here made the learner a DIFFERENT function of
# the same weights than both the net it played against and the net the gate
# ran. It stayed invisible while the move head was untrained and its outputs
# sat near zero; once move actually learned, 40% of outputs passed +-1 and the
# train/runtime gap measured 0.076 mean (0.238 max) — a net that scored 0.90
# against its own snapshot and 0.00 at the gate. One contract now: the head
# emits a raw vector, whoever uses it clips. Gradient still flows everywhere,
# which a clamp() here would not give.
def mask_heads(logits: torch.Tensor, dodge: torch.Tensor, obs: torch.Tensor,
               kit_count: int, is_player: bool) -> tuple[torch.Tensor, torch.Tensor]:
    """arena.mask.v1 (ml.env.dh_env.action_mask), batched in torch: the action
    logits of unavailable actions and the dodge logit without a charge go to
    MASK_NEG. Applied to the logits the trainer SAMPLES from and to the ones the
    UPDATE recomputes, so log pi_theta(a|s) and the entropy are those of the
    masked policy — the one every serving runtime argmaxes."""
    ready = obs[..., 5] <= 0.0
    cols = [torch.ones_like(ready), ready,
            (obs[..., 6] <= 0.0) if is_player else ready]
    for k in range(4):
        cols.append((obs[..., 7 + k] <= 0.0) if k < kit_count
                    else torch.zeros_like(ready))
    allowed = torch.stack(cols, dim=-1)
    neg = torch.full_like(logits, MASK_NEG)
    logits = torch.where(allowed, logits, neg)
    dodge = torch.where(obs[..., 12] > 0.0, dodge, torch.full_like(dodge, MASK_NEG))
    return logits, dodge


class TorchPolicyNet(nn.Module):
    def __init__(self, keys: list[str] | None = None, obs_dim: int = OBS_DIM,
                 hidden: tuple[int, ...] | None = None, arch: Arch | None = None):
        """`arch` carries width, activation and init together; `hidden` is the
        older width-only shortcut and still overrides the arch's width, so
        existing callers keep their exact meaning."""
        super().__init__()
        self.keys = list(keys or ["*"])
        self.key_to_idx = {k: i for i, k in enumerate(self.keys)}
        self.arch = arch or Arch()
        if hidden and tuple(hidden) != self.arch.hidden:
            self.arch = Arch.from_dict({**self.arch.to_dict(), "hidden": list(hidden)},
                                       name=self.arch.name)
        self.hidden = self.arch.hidden
        self.embeddings = nn.Embedding(len(self.keys), EMB_DIM)
        nn.init.normal_(self.embeddings.weight, 0.0, 0.1)
        sizes = [obs_dim + EMB_DIM, *self.hidden]
        self.layers = nn.ModuleList()
        for i in range(len(sizes) - 1):
            lin = nn.Linear(sizes[i], sizes[i + 1])
            # Same init rule as the numpy twin — a relu net warm-started from a
            # 0.1-normal trunk starts half-dead, which looks like a bad seed
            # rather than the wrong initialiser.
            _init_linear(lin, self.arch)
            self.layers.append(lin)
        self.head_move = nn.Linear(self.hidden[-1], 2)
        self.head_act = nn.Linear(self.hidden[-1], ACTION_LOGITS)
        self.head_dodge = nn.Linear(self.hidden[-1], 1)
        self.head_value = nn.Linear(self.hidden[-1], 1)
        for h in (self.head_move, self.head_act, self.head_dodge):
            nn.init.normal_(h.weight, 0.0, 0.01)
            nn.init.zeros_(h.bias)
        nn.init.normal_(self.head_value.weight, 0.0, 1.0)
        nn.init.zeros_(self.head_value.bias)

    def _trunk(self, obs: torch.Tensor, key: str) -> torch.Tensor:
        idx = torch.full((obs.shape[0],), self.key_to_idx.get(key, 0),
                         dtype=torch.long, device=obs.device)
        x = torch.cat([obs, self.embeddings(idx)], dim=-1)
        for lin in self.layers:
            x = _activate(lin(x), self.arch.activation)
        return x

    def forward(self, obs: torch.Tensor, key: str = "*"):
        """raw move[2], act logits[7], dodge logit[1], value[1] — batched.
        UNMASKED: the trainer applies mask_heads() to what it samples from and
        what it computes the ratio on, so the policy it optimizes is the one
        the serving runtimes execute."""
        h = self._trunk(obs, key)
        return (self.head_move(h), self.head_act(h),
                self.head_dodge(h).squeeze(-1), self.head_value(h).squeeze(-1))

    # ---- continuity with the numpy ES stack ---------------------------------

    def from_policy_net(self, net) -> None:
        """Warm-start from ml.training.policy_net.PolicyNet (ES registry)."""
        with torch.no_grad():
            for lin, w, b in zip(self.layers, net.weights, net.biases):
                lin.weight.copy_(torch.from_numpy(np.asarray(w)))
                lin.bias.copy_(torch.from_numpy(np.asarray(b)))
            for k, row in net.embeddings.items():
                idx = self.key_to_idx.get(k, self.key_to_idx.get("*", 0))
                self.embeddings.weight[idx].copy_(torch.from_numpy(np.asarray(row)))

    def export_policy_v1(self, path: str, explore: float = 0.0) -> None:
        """Schema arena.policy.v1 — the exact JSON ArenaNeuralPolicy loads."""
        with torch.no_grad():
            layers = [{"w": lin.weight.cpu().numpy().tolist(),
                       "b": lin.bias.cpu().numpy().tolist(),
                       "act": self.arch.activation}
                      for lin in self.layers]
            # fold the three policy heads into one logits layer, move first:
            # [move_x, move_y, act x7, dodge] == policy_net.HEAD_DIM order
            w = torch.cat([self.head_move.weight, self.head_act.weight,
                           self.head_dodge.weight], dim=0)
            b = torch.cat([self.head_move.bias, self.head_act.bias,
                           self.head_dodge.bias], dim=0)
            # "linear", not the old "logits": one vocabulary across every
            # exporter now that activations are an enum. The runtime still
            # accepts "logits" as an alias, for the nets already in ml/serving.
            layers.append({"w": w.cpu().numpy().tolist(),
                           "b": b.cpu().numpy().tolist(), "act": "linear"})
            emb = {k: self.embeddings.weight[i].cpu().numpy().tolist()
                   for k, i in self.key_to_idx.items()}
        json.dump({"schema": POLICY_SCHEMA, "obs_dim": OBS_DIM, "emb_dim": EMB_DIM,
                   "hidden": list(self.hidden), "arch": self.arch.to_dict(),
                   "layers": layers, "embeddings": emb, "explore": explore,
                   # provenance only — every runtime applies arena.mask.v1
                   # unconditionally; this records that the net was TRAINED
                   # under it (nets exported before 2026-09-19 were not)
                   "action_mask": MASK_SCHEMA},
                  open(path, "w"))
