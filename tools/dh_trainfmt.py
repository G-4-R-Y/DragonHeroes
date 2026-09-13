#!/usr/bin/env python3
"""Live, themed trainer output — the filter that stands between a league run and
Ricardo's terminal.

Ricardo, 2026-09-13: "make sure to make logs constant and pretty in those
files." Before this, tools/train_run.sh piped each trainer through `tail -2`
AND spawned it without `python3 -u`, so a 200-generation run printed nothing at
all for ten minutes per key and then dumped two lines. Now every generation
lands the moment it closes, with a bar, the fitness trace, throughput and an
ETA; candidate lines animate in place on a terminal and are dropped entirely
when the output is a pipe or a file, so logs stay clean.

    python3 -u -m ml.training.league train ... 2>&1 \\
        | tee run.log | python3 -u tools/dh_trainfmt.py --key fen_boar --generations 200

The raw trainer text is what goes into run.log (via tee, upstream of this) —
this filter only decorates what a human sees. It never swallows a line it does
not recognise: unknown output passes through dimmed, so tracebacks survive.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import time

SPARK = "▁▂▃▄▅▆▇█"
ISTTY = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None \
    and os.environ.get("TERM", "dumb") != "dumb"


def c(code: str, s: str) -> str:
    return f"\033[{code}m{s}\033[0m" if ISTTY else s


EMBER = "38;2;255;154;60"
GOLD = "38;2;255;214;148"
PALE = "38;2;217;212;199"
DIM = "38;2;128;125;115"
CYAN = "38;2;127;216;255"
GREEN = "38;2;126;217;87"
RED = "38;2;231;76;60"

RE_GEN = re.compile(r"^\[(?:train:)?([\w.]+)\] g(\d+) best=([-\d.]+) mean=([-\d.]+)")
RE_CAND = re.compile(r"^\[(?:train:)?([\w.]+)\] g(\d+) cand(\d+) fitness=([-\d.]+)")
RE_REG = re.compile(r"registered v(\d+)")
RE_GATE = re.compile(r"^\[gate\]")
RE_PPO = re.compile(r"^\[ppo:[\w.]+\] it=(\d+) steps=([\d,]+)/([\d,]+) "
                    r"sps=([\d,]+) win_rate\(last \d+\)=([\d.]+) eta=(\S+)")


def hhmmss(s: float) -> str:
    s = int(max(s, 0))
    return f"{s // 3600:d}:{(s % 3600) // 60:02d}:{s % 60:02d}" if s >= 3600 \
        else f"{s // 60:02d}:{s % 60:02d}"


def spark(vals: list[float], width: int = 22) -> str:
    if not vals:
        return ""
    v = vals[-width:]
    lo, hi = min(v), max(v)
    span = (hi - lo) or 1.0
    return "".join(SPARK[min(int((x - lo) / span * (len(SPARK) - 1) + 0.5), 7)] for x in v)


def bar(done: int, total: int, width: int = 20) -> str:
    total = max(total, 1)
    f = max(0, min(width, round(done / total * width)))
    return c(EMBER, "█" * f) + c(DIM, "░" * (width - f))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", default="")
    ap.add_argument("--generations", type=int, default=0)
    ap.add_argument("--pop", type=int, default=0)
    a = ap.parse_args()

    t0 = time.time()
    best_hist: list[float] = []
    gen_t: list[float] = []
    last_gen = 0
    last_it = 0
    transient = False

    def clear():
        nonlocal transient
        if transient:
            sys.stdout.write("\r\033[2K")
            transient = False

    for raw in sys.stdin:
        line = raw.rstrip("\n")

        m = RE_CAND.match(line)
        if m:
            if ISTTY:
                g, cand, fit = int(m.group(2)), int(m.group(3)), float(m.group(4))
                pop = a.pop or (cand + 1)
                sys.stdout.write(
                    "\r\033[2K  " + c(DIM, "evaluating") +
                    f"  g{g + 1}/{a.generations or '?'}  cand {cand + 1}/{pop}  "
                    + c(PALE, f"fit {fit:+.3f}") + c(DIM, f"   {hhmmss(time.time() - t0)} elapsed"))
                sys.stdout.flush()
                transient = True
            continue

        m = RE_PPO.match(line)
        if m:
            clear()
            it, done, total, sps, wr, eta = m.groups()
            last_it = int(it)
            d, tot = int(done.replace(",", "")), int(total.replace(",", ""))
            best_hist.append(float(wr))
            print(f"  {bar(d, tot)} {c(GOLD, f'it{int(it):>3}')}"
                  f"{c(DIM, f'  {d:,}/{tot:,} steps')}  "
                  f"win {c(PALE, f'{float(wr):.2f}')}  "
                  f"{c(EMBER, spark(best_hist))}  "
                  f"{c(DIM, f'{sps} steps/s  eta {eta}')}", flush=True)
            continue

        m = RE_GEN.match(line)
        if m:
            clear()
            g, best, mean = int(m.group(2)), float(m.group(3)), float(m.group(4))
            best_hist.append(best)
            gen_t.append(time.time())
            last_gen = g + 1
            per = ((gen_t[-1] - t0) / last_gen) if last_gen else 0.0
            eta = per * (a.generations - last_gen) if a.generations else 0.0
            trend = ""
            if len(best_hist) > 1:
                d = best_hist[-1] - best_hist[-2]
                trend = c(GREEN, "▲") if d > 1e-6 else c(RED, "▼") if d < -1e-6 else c(DIM, "=")
            print(f"  {bar(last_gen, a.generations or last_gen)} "
                  f"{c(GOLD, f'g{last_gen:>3}')}{c(DIM, '/' + str(a.generations or '?'))}  "
                  f"best {c(PALE, f'{best:+.3f}')}{trend} mean {c(DIM, f'{mean:+.3f}')}  "
                  f"{c(EMBER, spark(best_hist))}  "
                  f"{c(DIM, f'{per:4.1f}s/gen  eta {hhmmss(eta)}')}", flush=True)
            continue

        clear()
        if RE_GATE.match(line):
            low = line.lower()
            colour = GREEN if ("pass" in low and "fail" not in low) else \
                RED if ("fail" in low or "error" in low) else CYAN
            print("  " + c(colour, line), flush=True)
            continue
        m = RE_REG.search(line)
        if m:
            print("  " + c(CYAN, "✦ " + line.strip()), flush=True)
            continue
        if line.strip():
            print("  " + c(DIM, line), flush=True)

    clear()
    if best_hist:
        wall = time.time() - t0
        unit = f"{last_it} iterations" if last_it else f"{last_gen} generations"
        print(f"  {c(GOLD, 'done')} {unit} in {c(PALE, hhmmss(wall))}  "
              f"best {c(PALE, f'{max(best_hist):+.3f}')}  "
              f"first {c(DIM, f'{best_hist[0]:+.3f}')} → last {c(DIM, f'{best_hist[-1]:+.3f}')}",
              flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
