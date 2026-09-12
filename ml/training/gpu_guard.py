"""GPU guardrails (Ricardo: "cap based on my GPU capacity in VRAM — no OOMs").

Training runs local on the RTX 4050 (6 GB). The trainer caps its own process
fraction of VRAM up front instead of discovering the limit via a crash, and
clamps PPO batch sizes to what the cap can hold for the current net size.
"""
from __future__ import annotations

import torch

# Default: half the card (~3 GB on the 4050) — leaves headroom for the desktop,
# a second trainer, and fragmentation. Override via DH_VRAM_FRACTION.
DEFAULT_VRAM_FRACTION = 0.5

# Rollout-buffer budget in floats for obs+actions+logp+rewards+values+advantages.
# ~6 floats per obs element equivalent; 47-dim input, 10-dim head, PPO aux ~ 64/step.
FLOATS_PER_STEP = 64 * 4


def apply(vram_fraction: float = DEFAULT_VRAM_FRACTION) -> dict:
    """Call BEFORE any CUDA allocation. Returns the effective budget."""
    info = {"device": "cpu", "vram_fraction": 0.0, "max_steps_per_rollout": 0}
    if not torch.cuda.is_available():
        return info
    torch.cuda.set_per_process_memory_fraction(vram_fraction)
    torch.backends.cudnn.benchmark = True   # fixed shapes → autotuned kernels
    total = torch.cuda.get_device_properties(0).total_memory
    budget = int(total * vram_fraction)
    # reserve ~25% of the cap for activations/grads/optimizer state
    usable = int(budget * 0.75)
    max_steps = max(1024, usable // (FLOATS_PER_STEP * 4))  # float32 = 4 B
    info.update(device=torch.cuda.get_device_name(0),
                vram_fraction=vram_fraction,
                max_steps_per_rollout=max_steps)
    return info


def clamp_batch(requested: int, budget: dict) -> int:
    """Batch/rollout clamp: never schedule more steps than the VRAM budget."""
    cap = int(budget.get("max_steps_per_rollout", 0))
    if cap <= 0:
        return requested   # cpu: unclamped (RAM-bound instead)
    return max(64, min(requested, cap))
