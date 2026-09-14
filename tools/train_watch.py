#!/usr/bin/env python3
"""The forge window — a live, themed view of a training run.

Ricardo, 2026-09-13: "I'll run GENERATIONS=200 POP=10 EPISODES=6
tools/train_run.sh --all now and i want to keep track of it and have it
beautifully exhibited and themed in the terminal."

It reads the same JSONL progress feed the arena training console tails
(docs/design/25 §2) and repaints once a second: per-key progress bars, the
fitness trace as a sparkline, match throughput, gate verdicts and an ETA for
the whole sweep. It is read-only and byte-offset incremental, so watching a run
costs nothing and several windows can watch the same run at once.

    tools/train_watch.py                       # the newest run under ml/runs/
    tools/train_watch.py ml/runs/<run>         # a specific run
    tools/train_watch.py --deployed            # a plain run against ml/serving
    tools/train_watch.py <run> --once          # one frame, no clear (for logs/CI)

Ctrl-C only closes the window; the trainer keeps going.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNS = ROOT / "ml" / "runs"
DEPLOYED_PROGRESS = ROOT / "ml" / "data" / "progress"
ART = ROOT / "tools" / "art" / "dragon.txt"
SPARK = "▁▂▃▄▅▆▇█"
# The KEY column. 16 was exactly len("gloamfen_stalker"), so the longest name
# in the roster ran straight into the progress bar with no gap.
KEY_W = 18
EMBER_RAMP = [(255, 214, 148), (255, 178, 92), (255, 154, 60), (232, 118, 40),
              (198, 86, 28), (158, 60, 20), (120, 42, 14), (92, 32, 12)]

TTY = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None \
    and os.environ.get("TERM", "dumb") != "dumb"
EMBER, GOLD, PALE = "38;2;255;154;60", "38;2;255;214;148", "38;2;217;212;199"
DIM, CYAN, GREEN, RED = "38;2;128;125;115", "38;2;127;216;255", "38;2;126;217;87", "38;2;231;76;60"


def c(code: str, s: str) -> str:
    return f"\033[{code}m{s}\033[0m" if TTY else s


def hhmmss(s: float) -> str:
    s = int(max(s, 0))
    return f"{s // 3600:d}:{(s % 3600) // 60:02d}:{s % 60:02d}"


def spark(vals, width=18):
    if not vals:
        return ""
    v = vals[-width:]
    lo, hi = min(v), max(v)
    span = (hi - lo) or 1.0
    return "".join(SPARK[min(int((x - lo) / span * 7 + 0.5), 7)] for x in v)


def bar(done, total, width=14):
    total = max(total, 1)
    f = max(0, min(width, round(done / total * width)))
    return c(EMBER, "█" * f) + c(DIM, "░" * (width - f))


class KeyState:
    """One creature key's slice of the feed."""

    def __init__(self, key):
        self.key = key
        self.generations = 0
        self.pop = 0
        self.best: list[float] = []
        self.mean: list[float] = []
        self.gen = 0
        self.matches = 0
        self.cand = 0
        self.last_match = ""
        self.last_t = 0.0
        self.first_t = 0.0
        self.version = None
        self.gate = None          # True / False / None
        self.error = ""
        # --tournament: the key is trained once per METHOD, and every method's
        # subprocess writes to this same per-key feed with no --progress-file
        # (ml/training/league.py). So `generations` restarts from 0 when PPO
        # follows ES, and reading raw generations would show the key finished
        # when only the first method was done. Track the bracket explicitly.
        self.methods: list[str] = []
        self.mdone = 0
        self.method = ""
        self.bracket = False
        self.winner = ""
        self.last_bout = ""

    def feed(self, ev: dict):
        t = ev.get("t", 0.0)
        self.last_t = max(self.last_t, t)
        if not self.first_t:
            self.first_t = t
        name = ev.get("ev")
        if name == "tournament_start":
            self.bracket = True
            ms = ev.get("methods") or []
            self.methods = [str(m) for m in ms] if isinstance(ms, list) \
                else [m for m in str(ms).split(",") if m]
        elif name == "method_start":
            self.method = str(ev.get("method", ""))
            self.gen = 0           # a new method restarts the generation count
            self.generations = 0
            self.gate = None       # and re-opens the verdict
        elif name == "method_done":
            self.mdone += 1
            self.method = ""
        elif name == "bracket_start":
            self.last_bout = f"{ev.get('a', '?')} vs {ev.get('b', '?')}"
        elif name == "tournament_done":
            self.mdone = max(self.mdone, len(self.methods))
            self.winner = str(ev.get("winner", ""))
        elif name == "start":
            self.generations = int(ev.get("generations") or 0)
            self.pop = int(ev.get("pop") or 0)
        elif name == "match":
            self.matches += 1
            self.last_match = (f"g{int(ev.get('g', 0)) + 1} cand{ev.get('cand')} "
                               f"vs {str(ev.get('opp', '')).split('.')[-1]} "
                               f"score {float(ev.get('score', 0)):.2f} "
                               f"{float(ev.get('duration_s', 0)):.1f}s")
        elif name == "candidate":
            self.cand = int(ev.get("cand", 0)) + 1
        elif name == "generation":
            self.gen = int(ev.get("g", 0)) + 1
            self.best.append(float(ev.get("best", 0.0)))
            self.mean.append(float(ev.get("mean", 0.0)))
        elif name == "registered":
            self.version = ev.get("version")
        elif name == "gate":
            self.gate = bool(ev.get("pass"))
        elif name == "error":
            self.error = str(ev.get("message", ""))[:60]

    @property
    def frac(self) -> float:
        """How much of THIS key is done, 0..1 — the one number the sweep sums.

        A bracket key is (methods finished + the one in flight) / methods. PPO
        emits nothing between method_start and method_done, so a method with no
        generation feed counts as half — the same rule the arena console's
        sweep tracker uses, so the two surfaces never disagree."""
        if self.bracket:
            n = max(len(self.methods), 1)
            if self.mdone >= n:
                return 1.0
            inner = (self.gen / self.generations) if self.generations else 0.5
            return min(0.99, (self.mdone + inner) / n)
        if self.gate is not None:
            return 1.0
        if not self.generations:
            return 0.0
        return min(1.0, self.gen / self.generations)

    @property
    def state(self) -> tuple[str, str]:
        if self.error:
            return "error", RED
        if self.bracket:
            n = max(len(self.methods), 1)
            if self.mdone >= n:
                return (f"won: {self.winner}" if self.winner else "done"), GREEN
            return f"{self.method or 'bracket'} {self.mdone + 1}/{n}", EMBER
        if self.gate is True:
            return "PASS", GREEN
        if self.gate is False:
            return "fail", RED
        if self.version is not None:
            return "gating", CYAN
        if self.gen and self.generations and self.gen >= self.generations:
            return "done", CYAN
        if self.matches or self.gen:
            return "training", EMBER
        return "queued", DIM


class Watcher:
    def __init__(self, progress_dir: Path, run: Path | None):
        self.dir = progress_dir
        self.run = run
        self.keys: dict[str, KeyState] = {}
        self.offsets: dict[Path, int] = {}
        self.cfg = {}
        self._planned: int | None = None
        if run and (run / "config.json").exists():
            try:
                self.cfg = json.loads((run / "config.json").read_text())
            except Exception:
                self.cfg = {}

    def planned_keys(self) -> int:
        """How many keys this run will train: a --all sweep walks every creature
        build in game/arena/data/builds.json, one at a time."""
        if self._planned is not None:
            return self._planned
        self._planned = 1
        if str(self.cfg.get("keys_label", "")).startswith("all"):
            try:
                builds = json.loads((ROOT / "game" / "arena" / "data" /
                                     "builds.json").read_text())["builds"]
                self._planned = sum(1 for b in builds if b.get("kind") == "creature")
            except Exception:
                self._planned = 1
        return self._planned

    def poll(self):
        if not self.dir.is_dir():
            return
        for path in sorted(self.dir.glob("*.jsonl")):
            key = path.stem
            st = self.keys.setdefault(key, KeyState(key))
            off = self.offsets.get(path, 0)
            try:
                size = path.stat().st_size
            except OSError:
                continue
            if size < off:                      # truncated / restarted feed
                off = 0
                self.keys[key] = st = KeyState(key)
            if size == off:
                continue
            with path.open("r", encoding="utf-8", errors="replace") as f:
                f.seek(off)
                data = f.read()
            # only whole lines: the trainer may be mid-write
            cut = data.rfind("\n")
            if cut < 0:
                continue
            self.offsets[path] = off + len(data[:cut + 1].encode("utf-8"))
            for line in data[:cut].splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    st.feed(json.loads(line))
                except Exception:
                    pass

    # ---- rendering ------------------------------------------------------
    def frame(self, width: int, with_art: bool) -> str:
        out: list[str] = []
        w = max(72, min(width, 110))
        if with_art and ART.exists():
            lines = ART.read_text(encoding="utf-8").splitlines()
            n = max(len(lines), 1)
            for i, line in enumerate(lines):
                r, g, b = EMBER_RAMP[min(int(i / n * len(EMBER_RAMP)), len(EMBER_RAMP) - 1)]
                out.append(f"\033[38;2;{r};{g};{b}m{line}\033[0m" if TTY else line)
            out.append("")

        title = " ".join("DRAGON HEROES")
        out.append(c(GOLD, f"  {title}") + c(DIM, "   the forge window"))
        out.append(c(EMBER, "  " + "─" * (w - 2)))

        keys = list(self.keys.values())
        started = self.cfg.get("started", "")
        t0 = min([k.first_t for k in keys if k.first_t], default=0.0)
        now = time.time()
        # a feed with no line for five minutes is a finished (or dead) run:
        # freeze the clock at its last event instead of counting the hours
        # since. The window has to be generous -- a 13-episode match on a
        # contended box takes over a minute, and nothing is emitted until it
        # returns.
        last = max([k.last_t for k in keys], default=0.0)
        stale = bool(last) and (now - last) > 300.0
        elapsed = (last - t0) if (stale and t0) else (now - t0 if t0 else 0.0)

        done_keys = sum(1 for k in keys if k.frac >= 1.0)
        # a --all sweep trains the creature keys one after another, and only the
        # key in flight has a feed yet -- so the honest ETA counts the ones still
        # queued, not just what is on screen.
        planned = max(self.planned_keys(), len(keys), 1)
        # Progress is summed as per-key FRACTIONS, never as raw generations: a
        # --tournament key restarts its generation count once per method, so
        # summing generations both double-counts and finishes early.
        frac_done = sum(k.frac for k in keys)
        eta = ""
        if frac_done > 0.02 and not stale and planned > frac_done:
            eta = hhmmss(elapsed / frac_done * (planned - frac_done))
        gens_done = sum(k.gen for k in keys)
        per_key = max([k.generations for k in keys if k.generations], default=0)
        bracket = any(k.bracket for k in keys)
        gens_total = (per_key * planned) if (per_key and not bracket) else None

        if self.run:
            out.append(f"  {c(DIM, 'run')}      {c(PALE, self.run.name)}")
        if self.cfg:
            out.append(f"  {c(DIM, 'config')}   {self.cfg.get('mode', '?')} · "
                       f"{self.cfg.get('knobs', '')} · seeded from "
                       f"{self.cfg.get('seeded_from', '?')}")
        out.append(f"  {c(DIM, 'elapsed')}  {c(PALE, hhmmss(elapsed))}"
                   + (c(DIM, "  (idle)") if stale else "")
                   + (f"   {c(DIM, 'eta')} {c(PALE, '~' + eta)}" if eta else "")
                   + f"   {c(DIM, 'started')} {started}")
        matches = sum(k.matches for k in keys)
        rate = matches / elapsed if elapsed > 0.5 else 0.0
        out.append(f"  {c(DIM, 'matches')}  {c(PALE, str(matches))}   "
                   f"{c(DIM, f'{rate:.1f}/s')}   {c(DIM, 'keys')} "
                   f"{c(PALE, f'{done_keys}/{planned}')}   "
                   f"{bar(int(frac_done * 100), planned * 100, 16)} "
                   f"{c(PALE, f'{frac_done / planned * 100:3.0f}%')}"
                   + (f"   {c(DIM, 'generations')} "
                      f"{c(PALE, f'{gens_done}/{gens_total}')}" if gens_total else ""))
        out.append("")
        out.append("  " + c(DIM, f"{'KEY':<{KEY_W}}{'PROGRESS':<24}{'BEST':>8}"
                                 f"{'MEAN':>8}  {'TRACE':<19}{'MATCHES':>8}  STATE"))
        if not keys:
            out.append("  " + c(DIM, "waiting for the first progress line…"))
        for k in sorted(keys, key=lambda k: (-k.last_t, k.key)):
            label, colour = k.state
            if k.bracket:
                # generations restart per method, so the bar tracks the bracket
                count = f"{k.mdone}/{len(k.methods) or '?'}"
                prog = f"{bar(int(k.frac * 100), 100)} {count:>8}"
            else:
                prog = (f"{bar(k.gen, k.generations or max(k.gen, 1))} "
                        f"{k.gen:>3}/{k.generations or '?':<4}")
            best = f"{k.best[-1]:+.3f}" if k.best else "-"
            mean = f"{k.mean[-1]:+.3f}" if k.mean else "-"
            name = k.key if len(k.key) <= KEY_W - 2 else k.key[:KEY_W - 3] + "…"
            out.append(f"  {c(PALE, f'{name:<{KEY_W}}')}{prog}  {c(PALE, f'{best:>7}')}"
                       f"{c(DIM, f'{mean:>8}')}  {c(EMBER, f'{spark(k.best):<19}')}"
                       f"{c(DIM, f'{k.matches:>7}')}   {c(colour, label)}")
        bouts = [k for k in keys if k.last_bout and now - k.last_t < 300]
        if bouts:
            k = max(bouts, key=lambda k: k.last_t)
            out.append("")
            out.append(f"  {c(DIM, 'bracket')}     {c(PALE, k.key)} "
                       f"{c(DIM, k.last_bout)}")
        live = [k for k in keys if k.last_match and now - k.last_t < 120]
        if live:
            k = max(live, key=lambda k: k.last_t)
            out.append("")
            out.append(f"  {c(DIM, 'last match')}  {c(PALE, k.key)} {c(DIM, k.last_match)}")
        errs = [k for k in keys if k.error]
        for k in errs:
            out.append(f"  {c(RED, '✗ ' + k.key)} {c(DIM, k.error)}")
        if self.run and (self.run / "summary.txt").exists():
            out.append("")
            out.append(c(GREEN, "  run finished — ") + c(DIM, f"{self.run}/summary.txt"))
        out.append("")
        out.append(c(DIM, "  ctrl-c closes this window; the trainer keeps running"))
        return "\n".join(out)


def newest_run() -> Path | None:
    runs = sorted([p for p in RUNS.glob("*") if (p / "config.json").exists()])
    return runs[-1] if runs else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("run", nargs="?", default=None, help="ml/runs/<run> (default: newest)")
    ap.add_argument("--deployed", action="store_true",
                    help="watch ml/data/progress instead of a run folder")
    ap.add_argument("--once", action="store_true", help="print one frame and exit")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--no-art", action="store_true")
    a = ap.parse_args()

    run = None
    if a.deployed:
        pdir = DEPLOYED_PROGRESS
    else:
        run = Path(a.run).resolve() if a.run else newest_run()
        if run is None:
            print("no runs yet — start one with tools/train_run.sh --all", file=sys.stderr)
            return 2
        pdir = run / "progress"
    w = Watcher(pdir, run)

    try:
        while True:
            w.poll()
            size = shutil.get_terminal_size((100, 40))
            art = not a.no_art and size.lines >= 34 and not a.once
            frame = w.frame(size.columns, art)
            if a.once:
                print(frame)
                return 0
            sys.stdout.write("\033[H\033[J" + frame + "\n")
            sys.stdout.flush()
            time.sleep(max(a.interval, 0.1))
    except KeyboardInterrupt:
        sys.stdout.write("\n")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
