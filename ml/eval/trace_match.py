#!/usr/bin/env python3
"""Record a dh-env match as `arena.trace.v1` so the Godot arena can REPLAY it.

R51, and it exists because of an asymmetry: the arena is watchable (the console
spawns it with --spectate and you see the fight), while dh-env is a headless C++
library with no renderer at all. So the only way to *watch* what the trainer's
environment actually did is to have it hand out what it did, per tick, and let
the arena act it out.

WHAT A TRACE IS. One episode, one file. Per tick it carries, for BOTH sides,
where the body was (pos, aim, hp, windup, i-frames) and what the mind COMMANDED
(move, act, and whether the commit was refused by the action budget). Side B's
command is the valuable half: the internal opponent — native, scripted or an mlp
— is otherwise invisible from outside the sim, and "the opponent did something
different" is the commonest parity bug there is.

WHY IT IS ALSO THE PARITY INSTRUMENT. game/arena/trace_policy.gd feeds the
recorded commands back into real ArenaFighter bodies while the arena draws the
recorded positions as ghosts on top. Identical commands into two runtimes should
produce identical motion; where the ghost and the body come apart is exactly
where dh-env and the arena disagree, localised to a tick and a body. The env
parity probe (ml/eval/env_parity.py) can only ever report that the totals
differ — hp_frac alone can never say WHERE.

    # the deployed net for a key, the same one the gate would run
    python3 -m ml.eval.trace_match --key fen_boar --build core.arena.fen_boar
    # a specific net, a longer episode, an explicit destination
    python3 -m ml.eval.trace_match --build core.arena.cinder_drake \
        --policy ml/runs/ppo/best.json --ticks 2400 --out /tmp/drake.json
    # no net at all: the five-rule teacher, which still beats every net we train
    python3 -m ml.eval.trace_match --build core.arena.bog_golem --policy heuristic

Then, in Godot:

    godot --path game res://arena/arena.tscn -- --replay <path> --spectate

Side A is driven from OUTSIDE the sim (that is what dh-env is for), so --policy
takes a net JSON or `heuristic`, never `native`/`scripted`: those live inside the
sim and would be a different experiment than the one the probe and the gate run.
--opp, which IS the sim's internal mind, takes them freely.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from ml.env.dh_env import (DhEnv, balance_specs, make_spec,   # noqa: E402
                           mask_args, supports_dodge_flag, tick_hz)
from ml.eval.env_parity import act_from, deployed_json        # noqa: E402
from ml.training.distill import TeacherNet                    # noqa: E402
from ml.training.heuristic import teacher_for                 # noqa: E402

SCHEMA = "arena.trace.v1"
DEFAULT_DIR = ROOT / "ml" / "runs" / "traces"   # gitignored: traces are output


def driver(policy: str, build: str):
    """The mind on side A. Anything with TeacherNet's two methods works, which
    is the whole reason `heuristic` costs one line here: ml/training/heuristic.py
    already mimics that interface so the distiller needs no special case."""
    if policy in ("native", "scripted"):
        raise SystemExit(
            f"trace_match: '{policy}' is one of the sim's INTERNAL minds, and "
            "dh-env drives side A from outside. Pass it as --opp to put it on "
            "side B, or use --policy heuristic / a net JSON for side A.")
    if policy == "heuristic":
        return teacher_for(build)
    if not Path(policy).exists():
        raise SystemExit(f"trace_match: no such net '{policy}'")
    return TeacherNet(policy)


def record(build: str, policy: str, opp: str, seed: int, ticks: int) -> dict:
    """One episode, captured. Everything a replay needs is in the return value:
    the trace itself plus the identities and units it is measured in."""
    if not supports_dodge_flag():
        raise SystemExit(
            "trace_match: libdh-env.so predates the dodge flag, so the policy's "
            "dodge output would be dropped and the replay would act out a match "
            "nobody ran. Rebuild: cmake --build sim/build --target dh-env")
    net = driver(policy, build)
    emb = net.embedding(build.split(".")[-1])
    env = DhEnv(build, build, opp=opp, seed=seed)
    # Mirror matchup, so balance_specs is a no-op — but go through it anyway,
    # because DhEnv did, and the health bars the replay labels have to be the
    # pool the sim actually fought with.
    sa, sb = balance_specs(make_spec(build), make_spec(build))
    kit_count, is_player = mask_args(build)
    try:
        cap = env.trace_begin(ticks)
        obs = env.reset(seed)          # rewinds the trace to THIS spawn
        for _ in range(ticks):
            y = net.forward(np.concatenate([obs, emb])[None, :])[0]
            move, act = act_from(y, obs, kit_count, is_player)
            done, obs = env.step(move, act)
            if done:
                break
        frames = env.trace_frames()
        doc = {
            "schema": SCHEMA,
            "a": build, "b": build,
            "policy": getattr(net, "path", policy), "opp": opp,
            "seed": seed,
            # the replay maps a frame index to a wall-clock instant with this,
            # and must never assume 30 or 60: dh::sim::kArenaDt is the authority
            "tick_hz": tick_hz(),
            "ticks": int(env.tick),
            "seconds": float(env.seconds),
            "winner": int(env.winner),
            "hp": [float(env.hp_frac(0)), float(env.hp_frac(1))],
            "hp_max": [float(sa.max_hp), float(sb.max_hp)],
            "stride": int(frames.shape[1]) if frames.size else
                      1 + 2 * DhEnv.TRACE_SIDE_FIELDS,
            "side_fields": DhEnv.TRACE_SIDE_FIELDS,
            "fields": list(DhEnv.TRACE_FIELDS),
            "truncated": bool(env.tick >= cap - 1),
            # 4 decimals: sub-micron on a 416 px arena, and it halves the file
            "frames": [[round(float(v), 4) for v in row] for row in frames],
        }
    finally:
        env.close()
    return doc


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build", required=True, help="content id, e.g. core.arena.fen_boar")
    ap.add_argument("--key", default="", help="registry key; uses its DEPLOYED net")
    ap.add_argument("--policy", default="", help="net JSON path, or 'heuristic'")
    ap.add_argument("--opp", default="native", help="side B's internal mind")
    ap.add_argument("--seed", type=int, default=7)
    # the sim's own episode cap (dh::sim::kMaxTicks = 90 s), so the default
    # trace covers a WHOLE match and `truncated` means the cap was the reason
    ap.add_argument("--ticks", type=int, default=5400, help="cap; capture stops here")
    ap.add_argument("--out", default="", help="destination JSON (default: ml/runs/traces/)")
    a = ap.parse_args(argv)

    policy = a.policy or (deployed_json(a.key) if a.key else "heuristic")
    doc = record(a.build, policy, a.opp, a.seed, max(a.ticks, 1))

    if a.out:
        out = Path(a.out)
    else:
        stem = Path(policy).stem if policy.endswith(".json") else policy
        out = DEFAULT_DIR / f"{a.build.split('.')[-1]}-{stem}-s{a.seed}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc))

    print(f"{out}  {len(doc['frames'])} frames  {doc['seconds']:.2f}s  "
          f"winner={doc['winner']}  hp={doc['hp'][0]:.2f}/{doc['hp'][1]:.2f}"
          f"{'  TRUNCATED' if doc['truncated'] else ''}")
    print(f"godot --path game res://arena/arena.tscn -- --replay {out} --spectate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
