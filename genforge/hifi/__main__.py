"""CLI — python3 -m genforge.hifi <command>

  prompt    --creature KEY | --describe "..."  [--stance ...]   print the prompts
  process   IN.png... --creature KEY --out DIR                  enforce + gate any image
  generate  --creature KEY --out DIR [--n 2] [--backend NAME]   prompt -> model -> bundle
  score     PATH... [--creature KEY] [--json]                    scorecard for any PNG
  bench     --label NAME DIR [--label NAME DIR ...] --creature KEY   compare generators
  selftest  [--out DIR]                                          synthetic candidate end to end
  creatures                                                      list the registry
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import List, Optional

import numpy as np
from PIL import Image

from . import creatures as creatures_mod
from . import fixture, pipeline
from .scorecard import GateConfig, evaluate


def _spec(args) -> creatures_mod.CreatureSpec:
    if getattr(args, "describe", None):
        hue = None if args.emissive_hue is None else float(args.emissive_hue)
        return creatures_mod.custom(args.describe, hue, key=args.creature or "custom",
                                    grid_px=args.grid)
    return creatures_mod.get(args.creature or "orun")


def _add_creature(ap):
    ap.add_argument("--creature", help="registry key (default orun)")
    ap.add_argument("--describe", help="ad-hoc creature description (fills the prompt slot)")
    ap.add_argument("--emissive-hue", type=float, default=None,
                    help="OKLab hue (deg) of the ad-hoc creature's glow; omit = no core")
    ap.add_argument("--grid", type=int, default=256)


def _pngs(paths: List[str]) -> List[Path]:
    out: List[Path] = []
    for p in paths:
        pp = Path(p)
        if pp.is_dir():
            out += sorted(q for q in pp.iterdir() if q.suffix.lower() == ".png")
        else:
            out.append(pp)
    return out


def cmd_prompt(args) -> int:
    spec = _spec(args)
    ps = spec.prompt(args.stance)
    if args.json:
        print(json.dumps(ps.as_record(), indent=2))
    else:
        print("PROMPT:\n" + ps.positive + "\n\nNEGATIVE PROMPT:\n" + ps.negative)
        if args.folded:
            print("\nFOLDED (backends without a negative slot):\n" + ps.render(False)["prompt"])
    return 0


def cmd_process(args) -> int:
    spec = _spec(args)
    cfg = pipeline.ProcessConfig(outline_width=args.outline_width)
    results, names, raws = [], [], []
    for p in _pngs(args.inputs):
        r = pipeline.process(Image.open(p), spec, cfg)
        results.append(r); names.append(p.stem); raws.append(p)
        print(f"{p.name}: delivered {r.before.verdict} ({r.before.score}) -> "
              f"shipped {r.after.verdict} ({r.after.score})"
              + (f"  failures: {r.after.failures}" if r.after.failures else ""))
    if not results:
        print("no PNG inputs", file=sys.stderr); return 2
    rep = pipeline.write_bundle(Path(args.out), spec, results, frame_names=names,
                                prompt=spec.prompt(), raw_paths=raws, provider=None, cfg=cfg)
    print(f"HIFI BUNDLE {rep['verdict']} — {rep['out']} ({rep['frames']} frame(s))")
    return 0 if rep["verdict"] == "PASS" else 1


def cmd_generate(args) -> int:
    from genforge.pipeline.image_backend import get_image_backend
    spec = _spec(args)
    model = args.model or os.environ.get("GENFORGE_HIFI_IMAGE_MODEL", "").strip()
    backend = get_image_backend(args.backend, **({"model": model} if model else {}))
    cfg = pipeline.ProcessConfig(outline_width=args.outline_width)
    rep = pipeline.generate(spec, Path(args.out), backend=backend, n=args.n, size=args.size,
                            stance=args.stance, cfg=cfg, quality=args.quality)
    for c in rep["candidates"]:
        print(f"  {c['raw']}: delivered {c['before']} -> shipped {c['after']} {c['verdict']}"
              + (f" {c['failures']}" if c["failures"] else ""))
    print(f"HIFI GENERATE {rep['verdict']} — chose {rep['chosen']} -> {rep['out']}")
    return 0 if rep["verdict"] == "PASS" else 1


def cmd_score(args) -> int:
    spec = _spec(args)
    cfg = GateConfig(grid_px=spec.grid_px)
    rows = []
    for p in _pngs(args.paths):
        sc = evaluate(np.asarray(Image.open(p).convert("RGBA")), spec, cfg)
        rows.append({"path": str(p), **sc.as_dict()})
        if not args.json:
            print(f"== {p}\n{sc.table()}\n")
    if args.json:
        print(json.dumps(rows, indent=2))
    return 0 if rows and all(r["verdict"] == "PASS" for r in rows) else 1


def cmd_bench(args) -> int:
    """Same scorecard, every generator: raw candidates are graded as delivered
    AND after our post-process, so the table shows what each generator draws
    and what it ships through the same enforcement."""
    spec = _spec(args)
    cfg = pipeline.ProcessConfig()
    table = ["| generator | file | delivered | shipped | verdict | failures |", "|---|---|---|---|---|---|"]
    summary = {}
    for label, d in args.label:
        files = _pngs([d])
        s = summary.setdefault(label, {"n": 0, "delivered": [], "shipped": [], "pass": 0})
        for p in files:
            r = pipeline.process(Image.open(p), spec, cfg)
            s["n"] += 1; s["delivered"].append(r.before.score); s["shipped"].append(r.after.score)
            s["pass"] += r.after.verdict == "PASS"
            table.append(f"| {label} | {p.name} | {r.before.score} | {r.after.score} | {r.after.verdict} | "
                         f"{'; '.join(c.name for c in r.after.checks if c.hard and not c.passed) or '—'} |")
    print("\n".join(table))
    print("\n| generator | candidates | mean delivered | mean shipped | pass rate |\n|---|---|---|---|---|")
    for label, s in summary.items():
        if s["n"]:
            print(f"| {label} | {s['n']} | {np.mean(s['delivered']):.1f} | {np.mean(s['shipped']):.1f} | "
                  f"{s['pass'] / s['n']:.0%} |")
    return 0


def cmd_selftest(args) -> int:
    spec = creatures_mod.get("orun")
    cand = fixture.model_like_candidate()
    r = pipeline.process(cand, spec)
    ok = r.before.verdict == "FAIL" and r.after.verdict == "PASS"
    print(r.after.table())
    print(f"delivered {r.before.verdict} ({r.before.score}) -> shipped {r.after.verdict} ({r.after.score})")
    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        cand.save(out / "raw_fixture.png")
        rep = pipeline.write_bundle(out, spec, [r], frame_names=["fixture"], prompt=spec.prompt(),
                                    raw_paths=[out / "raw_fixture.png"])
        print(f"bundle -> {rep['out']}")
    print("HIFI SELFTEST OK" if ok else "HIFI SELFTEST FAILED")
    return 0 if ok else 1


def cmd_creatures(args) -> int:
    for k, s in creatures_mod.REGISTRY.items():
        glow = f"glow hue {s.emissive_hue_deg:g} ({s.emissive_label})" if s.has_emissive else "no core"
        print(f"{k:<20} {s.name:<38} {s.grid_px}px  {glow}")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(prog="python3 -m genforge.hifi", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("prompt"); _add_creature(p)
    p.add_argument("--stance"); p.add_argument("--json", action="store_true")
    p.add_argument("--folded", action="store_true", help="also print the single-prompt rendering")
    p.set_defaults(fn=cmd_prompt)

    p = sub.add_parser("process"); _add_creature(p)
    p.add_argument("inputs", nargs="+"); p.add_argument("--out", required=True)
    p.add_argument("--outline-width", type=int, default=1, choices=(1, 2))
    p.set_defaults(fn=cmd_process)

    p = sub.add_parser("generate"); _add_creature(p)
    p.add_argument("--out", required=True); p.add_argument("--n", type=int, default=2)
    p.add_argument("--backend", default=None); p.add_argument("--size", default="1024x1024")
    p.add_argument("--model", default=None, help="image model id (default: GENFORGE_HIFI_IMAGE_MODEL, then the seam's default)")
    p.add_argument("--stance"); p.add_argument("--quality", default=None)
    p.add_argument("--outline-width", type=int, default=1, choices=(1, 2))
    p.set_defaults(fn=cmd_generate)

    p = sub.add_parser("score"); _add_creature(p)
    p.add_argument("paths", nargs="+"); p.add_argument("--json", action="store_true")
    p.set_defaults(fn=cmd_score)

    p = sub.add_parser("bench"); _add_creature(p)
    p.add_argument("--label", nargs=2, action="append", metavar=("NAME", "DIR"), required=True)
    p.set_defaults(fn=cmd_bench)

    p = sub.add_parser("selftest"); p.add_argument("--out", default=None)
    p.set_defaults(fn=cmd_selftest)

    p = sub.add_parser("creatures"); p.set_defaults(fn=cmd_creatures)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
