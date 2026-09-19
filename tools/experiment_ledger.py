#!/usr/bin/env python3
"""Every training run, as ONE table — from what the runs already wrote.

R54 (Ricardo, 2026-09-19): "make sure to properly document all our experiments,
with different hyperparameters". tools/train_run.sh writes config.json (every
knob), summary.txt (gate verdicts) and logs/<key>.log per run under ml/runs/.
This turns those into the markdown table in docs/tech/39-experiment-ledger.md,
so a row is never typed by hand and never forgotten.

    python3 tools/experiment_ledger.py            # print the table
    python3 tools/experiment_ledger.py --write    # replace the auto block in tech/39
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RUNS = REPO / "ml" / "runs"
DOC = REPO / "docs" / "tech" / "39-experiment-ledger.md"
START, END = "<!-- ledger:auto:start -->", "<!-- ledger:auto:end -->"

VERDICT = re.compile(r"^([a-z_]+) v([0-9.]+) (pass|fail)\b(.*)$")
GATE_LINE = re.compile(r"\[gate\] ([a-z_]+) v([0-9.]+): (PASS|FAIL)")
FINAL_LINE = re.compile(r"\[ppo:[a-z_]+\] final: (.*)$")


def knobs(cfg: dict) -> str:
    mode = cfg.get("mode", "?")
    if mode == "ppo":
        p = cfg.get("ppo", {})
        parts = [f"steps {p.get('steps'):,}" if isinstance(p.get("steps"), int) else f"steps {p.get('steps')}",
                 f"envs {p.get('envs')}", f"arch {p.get('arch')}", f"sp {p.get('selfplay_every')}"]
        for k, label in (("promote_wr", "promote"), ("promote_hold", "hold"), ("eval_envs", "probes"),
                         ("demote_wr", "demote"), ("reservoir", "reservoir"), ("entropy_final", "β→"),
                         ("move_std_final", "std→"), ("plateau_updates", "plateau"), ("clone", "clone"),
                         ("action_mask", "mask")):
            if p.get(k) not in (None, "", 0):
                parts.append(f"{label} {p[k]}")
        if cfg.get("net") not in (None, "", "default"):
            parts.append(f"net {cfg['net']}")
        return ", ".join(parts)
    if mode == "es":
        e = cfg.get("es", {})
        return (f"gens {e.get('generations')}, pop {e.get('pop')}, eps {e.get('episodes')}, "
                f"jobs {e.get('jobs')}, seed {e.get('seed')}, speed {e.get('speed')}"
                + (f", opponents {e['opponents']}" if e.get("opponents") else ""))
    if mode == "tournament":
        t = cfg.get("tournament", {})
        return f"methods {t.get('methods')}, best-of {t.get('best_of')}, teacher {t.get('teacher') or '-'}"
    return cfg.get("knobs", "")


def verdicts(run: Path) -> list[str]:
    out: list[str] = []
    summ = run / "summary.txt"
    if summ.exists():
        for line in summ.read_text(errors="replace").splitlines():
            m = VERDICT.match(line.strip())
            if m:
                out.append(f"{m.group(1)} v{m.group(2)} **{m.group(3).upper()}**")
    if not out:
        for lg in sorted((run / "logs").glob("*.log")) if (run / "logs").exists() else []:
            last_gate, last_final = None, None
            for line in lg.read_text(errors="replace").splitlines():
                g = GATE_LINE.search(line)
                if g:
                    last_gate = f"{g.group(1)} v{g.group(2)} **{g.group(3)}**"
                f = FINAL_LINE.search(line)
                if f:
                    last_final = f.group(1)
            if last_gate:
                out.append(last_gate + (f" ({last_final})" if last_final else ""))
            elif last_final:
                out.append(f"{lg.stem}: {last_final} (no gate line)")
    return out or ["no verdict recorded"]


def rows() -> list[str]:
    out = []
    for run in sorted(RUNS.iterdir()) if RUNS.exists() else []:
        if not run.is_dir():
            continue
        cfg_p = run / "config.json"
        if not cfg_p.exists():
            out.append(f"| `{run.name}` | ? | ? | no config.json | — | {'; '.join(verdicts(run))} |")
            continue
        cfg = json.loads(cfg_p.read_text())
        wall = ""
        summ = run / "summary.txt"
        if summ.exists():
            m = re.search(r"^wall:\s*(\S+)", summ.read_text(errors="replace"), re.M)
            wall = m.group(1) if m else ""
        env = cfg.get("env", {})
        head = env.get("git_head", "?") + ("*" if env.get("git_dirty") else "")
        note = (cfg.get("note") or "").strip().replace("\n", " ").replace("|", "/")
        out.append(f"| `{run.name}` | {cfg.get('started', '')[:16]} | {cfg.get('mode')} · "
                   f"{cfg.get('keys_label', '')} | {knobs(cfg)} | {wall or '—'} · `{head}` | "
                   f"{'; '.join(verdicts(run))}{(' — ' + note) if note else ''} |")
    return out


def table() -> str:
    hdr = ("| run | started | trainer · keys | hyperparameters | wall · git | verdicts |\n"
           "|-----|---------|----------------|-----------------|------------|----------|\n")
    return hdr + "\n".join(rows()) + "\n"


def main() -> None:
    t = table()
    if "--write" in sys.argv:
        s = DOC.read_text()
        a, b = s.index(START) + len(START), s.index(END)
        DOC.write_text(s[:a] + "\n" + t + s[b:])
        print(f"wrote {len(rows())} rows into {DOC.relative_to(REPO)}")
    else:
        print(t)


if __name__ == "__main__":
    main()
