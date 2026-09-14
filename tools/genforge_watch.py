#!/usr/bin/env python3
"""The forge window for ASSETS — a live, themed view of the content pipeline.

Ricardo, 2026-09-14: asked whether the assets console had a terminal watcher
like `tools/train_watch.py`; it did not. This is it.

It is the twin of tools/train_watch.py, with one honest difference. A training
run emits a JSONL feed, so that window TAILS a stream. GenForge has no feed: a
build is a short command that either produces an immutable bundle or does not.
So this window WATCHES STATE ON DISK — releases, bundles, blockers, provenance
findings and approvals — and repaints when any of it changes. That means it is
useful both while a build runs (the bundle appears, blockers resolve) and as a
standing dashboard of what is ready and what is not.

It re-uses genforge.py's OWN data functions (`list_data`, `audit_data`), so the
rules live in exactly one place: this window can never call an asset fine when
`tools/genforge.py check` fails it. Read-only — it never builds, approves or
rejects anything.

    tools/genforge_watch.py                 every pack, repainting
    tools/genforge_watch.py fen_bells       one pack, with its findings
    tools/genforge_watch.py --once          one frame, no clear (for logs/CI)
    tools/genforge_watch.py --interval 5    seconds between repaints (default 3)

Ctrl-C only closes the window; nothing in the pipeline is touched.
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.genforge import audit_data, list_data, BAD, WARN, OK  # noqa: E402

ART = ROOT / "tools" / "art" / "dragon.txt"
EMBER_RAMP = [(255, 214, 148), (255, 178, 92), (255, 154, 60), (232, 118, 40),
              (198, 86, 28), (158, 60, 20), (120, 42, 14), (92, 32, 12)]

TTY = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None \
    and os.environ.get("TERM", "dumb") != "dumb"

# the arena console's palette, shared with tools/dh_term.sh and train_watch.py
EMBER, PALE, DIM = "255;154;60", "217;212;199", "128;125;115"
CYAN, GREEN, RED, GOLD = "127;216;255", "126;217;87", "231;76;60", "255;214;148"
PACK_W = 18


def c(code: str, s: str) -> str:
    return f"\033[38;2;{code}m{s}\033[0m" if TTY else s


def state_colour(state: str) -> str:
    if state == "approved":
        return GREEN
    if state == "REJECTED":
        return RED
    if state == "no bundle":
        return DIM
    return EMBER


def frame(pack: str | None, width: int, with_art: bool) -> str:
    out: list[str] = []
    w = max(72, min(width, 110))
    if with_art and ART.exists():
        lines = ART.read_text(encoding="utf-8").splitlines()
        n = max(len(lines), 1)
        for i, line in enumerate(lines):
            r, g, b = EMBER_RAMP[min(int(i / n * len(EMBER_RAMP)),
                                     len(EMBER_RAMP) - 1)]
            out.append(f"\033[38;2;{r};{g};{b}m{line}\033[0m" if TTY else line)
        out.append("")

    out.append(c(GOLD, "  " + " ".join("DRAGON HEROES"))
               + c(DIM, "   the asset forge"))
    out.append(c(EMBER, "  " + "─" * (w - 2)))

    rows = list_data()["packs"]
    audit = audit_data(pack)
    by_pack = {p["pack"]: p for p in audit["packs"]}

    ready = sum(1 for p in by_pack.values() if p["ready"])
    blocked = sum(1 for p in by_pack.values() if p["failures"])
    out.append(f"  {c(DIM, 'packs')}    {c(PALE, str(len(rows)))}   "
               f"{c(DIM, 'ready')} {c(GREEN if ready else DIM, str(ready))}   "
               f"{c(DIM, 'blocked')} {c(RED if blocked else DIM, str(blocked))}   "
               f"{c(DIM, 'checked')} {time.strftime('%H:%M:%S')}")
    out.append("")
    out.append("  " + c(DIM, f"{'PACK':<{PACK_W}}{'STATE':<22}{'ART':>4}"
                              f"{'FAIL':>6}{'OPEN':>6}  {'HASH':<14}BUNDLE"))
    if not rows:
        out.append("  " + c(DIM, "no releases and no bundles yet"))
    for r in rows:
        a = by_pack.get(r["pack"], {})
        pack_name = r["pack"]
        if len(pack_name) > PACK_W - 2:
            pack_name = pack_name[:PACK_W - 3] + "\u2026"
        state = r["state"]
        fails = a.get("failures", 0)
        opens = a.get("open_items", 0)
        n_art = len(a.get("art", []))
        digest = (r["content_hash"] or "-")[:12]
        where = r["bundle"] or "never built"
        # Values first, then one format() — nesting the same quote inside an
        # f-string is a SyntaxError on the project's Python 3.10.
        row = "  {}{}{}{}{}  {}{}".format(
            c(PALE, "{:<{}}".format(pack_name, PACK_W)),
            c(state_colour(state), "{:<22}".format(state)),
            c(DIM, "{:>4}".format(n_art)),
            c(RED if fails else DIM, "{:>6}".format(fails)),
            c(EMBER if opens else DIM, "{:>6}".format(opens)),
            c(DIM, "{:<14}".format(digest)),
            c(DIM, where))
        out.append(row)
        # one pack asked for by name gets its findings spelled out
        if pack is not None:
            for f in a.get("findings", []):
                lvl = f["level"]
                mark = "\u2717" if lvl == BAD else "!" if lvl == WARN else "\u2713"
                tone = RED if lvl == BAD else EMBER if lvl == WARN else GREEN
                out.append("      {} {} {}".format(
                    c(tone, mark), c(PALE, f["who"]), c(DIM, f["message"])))
            ap_row = a.get("approval")
            if ap_row:
                out.append("      {} {}".format(
                    c(DIM, "approval"),
                    c(PALE, "{} \u00b7 {}".format(ap_row.get("decision", "?"),
                                                  ap_row.get("note", "")))))
    out.append("")
    out.append(c(DIM, "  ctrl-c closes this window; nothing here builds or approves"))
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pack", nargs="?", default=None)
    ap.add_argument("--once", action="store_true", help="one frame, no clear")
    ap.add_argument("--interval", type=float, default=3.0)
    ap.add_argument("--no-art", action="store_true")
    args = ap.parse_args()
    try:
        while True:
            width = os.get_terminal_size().columns if TTY else 100
            text = frame(args.pack, width, not args.no_art)
            if args.once:
                print(text)
                return 0
            sys.stdout.write("\033[H\033[J" + text + "\n")
            sys.stdout.flush()
            time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
