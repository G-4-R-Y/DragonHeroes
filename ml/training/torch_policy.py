"""Torch policy/value net — the GPU twin of ml/training/policy_net.py.

Same contract (so anything trained here still DEPLOYS to the Godot arena):
  input  = obs[31] ++ embedding[16]          (arena.obs.v1 + content row)
  hidden = [64, 64] tanh
  heads  = move[2] (tanh-squashed), act logits[7], dodge logit[1]
plus a PPO value head (NOT exported — the Godot runtime is policy-only).

Continuity: `from_policy_net` warm-starts from the numpy ES registry weights,
`export_policy_v1` writes schema "arena.policy.v1" JSON that
game/arena/neural_policy.gd loads verbatim — ES → PPO → Godot, one format.
"""
from __future__ import annotations

import json

import numpy as np
import torch
import torch.nn as nn

OBS_DIM = 31
EMB_DIM = 16
ACTION_LOGITS = 7
HIDDEN = (64, 64)
POLICY_SCHEMA = "arena.policy.v1"


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
        """obs[B,31], h[B,64] -> (move, logits, dodge, value, h')."""
        idx = torch.full((obs.shape[0],), self.key_to_idx.get(key, 0),
                         dtype=torch.long, device=obs.device)
        x = torch.tanh(self.input(torch.cat([obs, self.embeddings(idx)], -1)))
        h = self.gru(x, h)
        return (torch.tanh(self.head_move(h)), self.head_act(h),
                self.head_dodge(h).squeeze(-1), self.head_value(h).squeeze(-1), h)


class TorchPolicyNet(nn.Module):
    def __init__(self, keys: list[str] | None = None, obs_dim: int = OBS_DIM,
                 hidden: tuple[int, ...] | None = None):
        super().__init__()
        self.keys = list(keys or ["*"])
        self.key_to_idx = {k: i for i, k in enumerate(self.keys)}
        self.hidden = tuple(hidden) if hidden else HIDDEN
        self.embeddings = nn.Embedding(len(self.keys), EMB_DIM)
        nn.init.normal_(self.embeddings.weight, 0.0, 0.1)
        sizes = [obs_dim + EMB_DIM, *self.hidden]
        self.layers = nn.ModuleList()
        for i in range(len(sizes) - 1):
            lin = nn.Linear(sizes[i], sizes[i + 1])
            nn.init.normal_(lin.weight, 0.0, 0.1)
            nn.init.zeros_(lin.bias)
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
            x = torch.tanh(lin(x))
        return x

    def forward(self, obs: torch.Tensor, key: str = "*"):
        """move[-1,1]^2, act logits[7], dodge logit[1], value[1] — batched."""
        h = self._trunk(obs, key)
        return (torch.tanh(self.head_move(h)), self.head_act(h),
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
                       "b": lin.bias.cpu().numpy().tolist(), "act": "tanh"}
                      for lin in self.layers]
            # fold the three policy heads into one logits layer, move first:
            # [move_x, move_y, act x7, dodge] == policy_net.HEAD_DIM order
            w = torch.cat([self.head_move.weight, self.head_act.weight,
                           self.head_dodge.weight], dim=0)
            b = torch.cat([self.head_move.bias, self.head_act.bias,
                           self.head_dodge.bias], dim=0)
            layers.append({"w": w.cpu().numpy().tolist(),
                           "b": b.cpu().numpy().tolist(), "act": "logits"})
            emb = {k: self.embeddings.weight[i].cpu().numpy().tolist()
                   for k, i in self.key_to_idx.items()}
        json.dump({"schema": POLICY_SCHEMA, "obs_dim": OBS_DIM, "emb_dim": EMB_DIM,
                   "layers": layers, "embeddings": emb, "explore": explore},
                  open(path, "w"))
