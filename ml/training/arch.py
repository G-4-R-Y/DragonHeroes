"""The network architecture, as one named thing (Ricardo, 2026-09-13: "net
hyperparams should be configurable, as to test new architectures").

Width arrived with distillation; everything else about the shape was still
hard-coded — tanh on every hidden layer, one init scale, and the optimiser knobs
scattered across per-trainer flags. An experiment should be `--net relu-wide`,
not twelve flags you have to remember to repeat identically for the next run.

    python3 -m ml.training.league train --net wide  --key k --build b
    ml/.venv/bin/python -m ml.training.ppo --net relu-wide --key k ...
    python3 -m ml.training.distill --net tiny --teacher ... --key k --build b
    python3 -m ml.training.arch                       # list the presets

Presets live in ml/training/architectures.json so adding one needs no code, and
individual flags (--hidden/--activation/--init/--init-scale) override whatever
the preset says.

FOUR RUNTIMES HAVE TO AGREE, or a net is a lie:
    ml/training/policy_net.py      numpy — ES and the distillation student
    ml/training/torch_policy.py    torch — the PPO learner
    game/arena/neural_policy.gd    GDScript — the arena and the game
    sim/libs/dh-godot DhPolicyNet  C++ — the same forward, BIT-IDENTICAL
    sim/libs/dh-sim Arena::mlp_act C++ — PPO's frozen self-play opponent
The last two are why the activation set here is small and boring. Every one of
these is exact in both GDScript and C++ with no library call except tanh (which
both already route to libm): relu is max(0, x), leaky_relu is a fixed 0.01 slope
written the same way on both sides, linear is nothing at all. Adding gelu or silu
means adding erf/exp to that equivalence proof, and an activation that disagrees
in the last bit between the two arena paths invalidates every trained weight.

ACTIVATION CODES are part of the on-disk contract (arena.policy.v1 carries the
NAME; the C++ boundary carries the code):
    0 linear   1 tanh   2 relu   3 leaky_relu
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, asdict, field
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
PRESETS_PATH = Path(__file__).with_name("architectures.json")

ACTIVATIONS = ("linear", "tanh", "relu", "leaky_relu")
ACT_CODE = {name: i for i, name in enumerate(ACTIVATIONS)}
# Read-side only: nets already on disk. The PPO exporter wrote "logits" for its
# folded head before activations were an enum, and four nets in ml/serving/weights
# still carry it. It always meant linear.
ACT_ALIASES = {"logits": "linear"}


def normalize_act(name: str) -> str:
    """The canonical name for an activation read off disk. Raises on an unknown
    one — a net we cannot run exactly is not a net we may guess at."""
    n = ACT_ALIASES.get(str(name), str(name))
    if n not in ACTIVATIONS:
        raise ValueError(f"unknown activation {name!r} — known: {', '.join(ACTIVATIONS)}")
    return n
LEAKY_SLOPE = 0.01          # fixed on purpose: a knob here is a knob in 4 runtimes
INITS = ("normal", "he", "xavier")


def apply_activation(x: np.ndarray, name: str) -> np.ndarray:
    if name == "tanh":
        return np.tanh(x)
    if name == "relu":
        return np.maximum(x, 0.0)
    if name == "leaky_relu":
        return np.where(x > 0.0, x, LEAKY_SLOPE * x)
    return x


def activation_grad(y: np.ndarray, name: str) -> np.ndarray:
    """d(act)/d(pre) expressed from the POST-activation value, which is what the
    backward pass has kept around. tanh' = 1 - y^2; relu' and leaky' read the
    sign of y, which matches the sign of the pre-activation for both."""
    if name == "tanh":
        return 1.0 - y ** 2
    if name == "relu":
        return (y > 0.0).astype(y.dtype)
    if name == "leaky_relu":
        return np.where(y > 0.0, 1.0, LEAKY_SLOPE)
    return np.ones_like(y)


@dataclass(frozen=True)
class Arch:
    """Everything about the net's SHAPE. Optimiser knobs stay with their trainer:
    sigma/lr mean different things to ES and PPO, the shape does not."""
    hidden: tuple[int, ...] = (64, 64)
    activation: str = "tanh"          # every hidden layer; the head is linear
    init: str = "normal"
    init_scale: float = 0.1           # used by init="normal"
    name: str = "default"

    def __post_init__(self) -> None:
        if self.activation not in ACTIVATIONS:
            raise ValueError(f"unknown activation {self.activation!r} — "
                             f"known: {', '.join(ACTIVATIONS)}")
        if self.init not in INITS:
            raise ValueError(f"unknown init {self.init!r} — known: {', '.join(INITS)}")
        if not self.hidden or any(int(n) < 1 for n in self.hidden):
            raise ValueError(f"bad hidden {self.hidden!r}")

    # ---- serialisation ------------------------------------------------------

    def to_dict(self) -> dict:
        d = asdict(self)
        d["hidden"] = list(self.hidden)
        return d

    @staticmethod
    def from_dict(d: dict, name: str = "") -> "Arch":
        return Arch(hidden=tuple(int(x) for x in d.get("hidden", (64, 64))),
                    activation=str(d.get("activation", "tanh")),
                    init=str(d.get("init", "normal")),
                    init_scale=float(d.get("init_scale", 0.1)),
                    name=name or str(d.get("name", "custom")))

    # ---- weights ------------------------------------------------------------

    def init_weight(self, rng: np.random.Generator, n_out: int, n_in: int) -> np.ndarray:
        if self.init == "he":            # relu-family: keep the forward variance
            return rng.normal(0.0, np.sqrt(2.0 / n_in), (n_out, n_in))
        if self.init == "xavier":        # tanh-family
            return rng.normal(0.0, np.sqrt(1.0 / n_in), (n_out, n_in))
        return rng.normal(0.0, self.init_scale, (n_out, n_in))

    def layer_acts(self, n_layers: int) -> list[str]:
        """Hidden layers get `activation`; the head is always linear — the
        runtime reads [move_x, move_y, logits..., dodge] raw."""
        return [self.activation] * (n_layers - 1) + ["linear"]


def presets() -> dict[str, dict]:
    if PRESETS_PATH.exists():
        return json.loads(PRESETS_PATH.read_text())
    return {}


def resolve(net: str = "", hidden: str = "", activation: str = "",
            init: str = "", init_scale: float | None = None) -> Arch:
    """A preset name, then per-flag overrides. Every trainer calls exactly this,
    so `--net wide --activation relu` means the same thing everywhere."""
    table = presets()
    base = table.get(net or "default", {})
    if net and net not in table:
        raise SystemExit(f"unknown --net {net!r} — known: {', '.join(sorted(table))}")
    arch = Arch.from_dict(base, name=net or "default")
    over: dict = {}
    if hidden:
        over["hidden"] = tuple(int(x) for x in str(hidden).replace(" ", "").split(",") if x)
    if activation:
        over["activation"] = activation
    if init:
        over["init"] = init
    if init_scale is not None:
        over["init_scale"] = float(init_scale)
    if over:
        d = arch.to_dict()
        d.update({k: (list(v) if k == "hidden" else v) for k, v in over.items()})
        arch = Arch.from_dict(d, name=(arch.name + "+overrides"))
    return arch


def add_arguments(ap: argparse.ArgumentParser) -> argparse.ArgumentParser:
    """The same five flags on every trainer."""
    ap.add_argument("--net", default="",
                    help=f"architecture preset from {PRESETS_PATH.name} "
                         f"({', '.join(sorted(presets())) or 'none'})")
    ap.add_argument("--hidden", default="",
                    help="override the widths, e.g. '256,256'. A wide net is a "
                         "TEACHER — it cannot ship; distill it (ml/training/distill.py)")
    ap.add_argument("--activation", default="", choices=["", *ACTIVATIONS],
                    help="hidden-layer activation (the head is always linear)")
    ap.add_argument("--init", default="", choices=["", *INITS])
    ap.add_argument("--init-scale", type=float, default=None)
    return ap


def from_args(args: argparse.Namespace) -> Arch:
    return resolve(getattr(args, "net", ""), getattr(args, "hidden", ""),
                   getattr(args, "activation", ""), getattr(args, "init", ""),
                   getattr(args, "init_scale", None))


def main() -> int:
    ap = argparse.ArgumentParser(prog="ml.training.arch", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    from ml.training.policy_net import macs
    table = presets()
    if args.json:
        print(json.dumps({k: {**v, "macs": macs(tuple(v.get("hidden", (64, 64))))}
                          for k, v in table.items()}, indent=1))
        return 0
    print(f"{'preset':<14} {'hidden':<18} {'act':<11} {'init':<8} {'MACs/tick':>10}  note")
    for name, spec in table.items():
        a = Arch.from_dict(spec, name=name)
        m = macs(a.hidden)
        note = spec.get("note", "")
        print(f"{name:<14} {str(list(a.hidden)):<18} {a.activation:<11} {a.init:<8} "
              f"{m:>10,}  {note}")
    print(f"\nthe shipping budget is ~105 us/tick at {macs():,} MACs in C++ "
          f"(~{macs() / 105:.0f} MACs/us); one forward runs per agent per tick.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
