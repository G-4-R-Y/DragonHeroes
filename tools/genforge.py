#!/usr/bin/env python3
"""GenForge: create, check and approve content — one command instead of five.

Ricardo, 2026-09-13: "create an interface to approve/check/create new content!".
The pipeline had all the pieces and no counter: drafting was
`genforge.living.draft`, building was `genforge.living.build`, validating was
`tools/validate_content.py`, provenance was whatever each art source happened to
carry, and approval was not written down anywhere at all.

    tools/genforge.py list                       what exists and where it stands
    tools/genforge.py check                      audit EVERYTHING (exit 1 if a
                                                 release or bundle has a problem)
    tools/genforge.py check fen_bells            one pack
    tools/genforge.py create --from bell_beneath_fen --pack ash_wake \
        --title "The Ash Wake" --build
    tools/genforge.py show ash_wake              the bundle, its blockers, the
                                                 browser review page
    tools/genforge.py approve ash_wake --note "art reviewed, frame-time captured"
    tools/genforge.py reject ash_wake --reason "bellwether has only idle"

WHAT APPROVAL IS, AND IS NOT
A built bundle is IMMUTABLE: its manifest.json hashes every file in it, and
build.py re-verifies those digests whenever it sees the bundle again. So approval
is never written inside a bundle. It goes in genforge/approvals/<content_hash>.json
and names the hash it approved — move a pixel and the bundle rebuilds under a new
hash, and the old approval no longer applies to anything. That is the point.

Approval is the HUMAN half of the gate: art reviewed, frame time captured,
playtested. `check` is the MACHINE half: schema, provenance, clip coverage, file
digests. Publishing needs both, and this tool will not say READY until it has
both. Nothing here writes to content/drops/ — promotion stays a separate,
deliberate step.

THE PROVENANCE CHECK IS THE SHARP ONE
An art source must carry provenance-v1.json (or the older provenance.json)
recording `sha256` of the image and `prompt_sha256` of the prompt that made it.
If the recorded hash does not match the file on disk, the image is not the one
the prompt produced and the bundle is not reproducible. A source with no
provenance at all cannot be verified in either direction — that is how
`bellwether`, the dungeon boss, got into the catalog unverifiable.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

RELEASES = ROOT / "genforge" / "releases"
BUNDLES = ROOT / "genforge" / "candidates" / "living"
APPROVALS = ROOT / "genforge" / "approvals"
PROVENANCE_NAMES = ("provenance-v1.json", "provenance.json")

OK, WARN, BAD = "ok", "warn", "bad"
MARK = {OK: "  ok  ", WARN: " warn ", BAD: " FAIL "}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def releases() -> dict[str, Path]:
    return {json.loads(p.read_text()).get("pack", p.stem): p
            for p in sorted(RELEASES.glob("*.json"))}


def bundles() -> dict[str, list[Path]]:
    """pack -> its built bundles, newest first. build.py names them
    <pack>-<content_hash[:16]>, so one pack can have several as it is iterated."""
    out: dict[str, list[Path]] = {}
    if BUNDLES.is_dir():
        for d in sorted(BUNDLES.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
            if (d / "manifest.json").is_file():
                out.setdefault(d.name.rsplit("-", 1)[0], []).append(d)
    return out


def approval_for(content_hash: str) -> dict | None:
    path = APPROVALS / f"{content_hash}.json"
    return json.loads(path.read_text()) if path.is_file() else None


# ---- the checks --------------------------------------------------------------------


def check_art(art: dict, findings: list[tuple[str, str, str]]) -> None:
    """Provenance for one art entry: the image, the prompt, and the record that
    ties them together."""
    name = art["id"]
    source = ROOT / art["source"]
    prompt = ROOT / art["prompt"]
    if not source.is_file():
        findings.append((BAD, name, f"source missing: {art['source']}"))
        return
    if not prompt.is_file():
        findings.append((BAD, name, f"prompt missing: {art['prompt']}"))

    folder = source.parent
    prov_path = next((folder / n for n in PROVENANCE_NAMES if (folder / n).is_file()), None)
    if prov_path is None:
        findings.append((BAD, name, f"NO provenance in {folder.relative_to(ROOT)}/ — the "
                                    f"image cannot be verified against its prompt"))
        return
    if prov_path.name != PROVENANCE_NAMES[0]:
        findings.append((WARN, name, f"{prov_path.name} is the unversioned format; "
                                     f"the pipeline writes {PROVENANCE_NAMES[0]} now"))
    prov = json.loads(prov_path.read_text())

    recorded = str(prov.get("sha256", ""))
    if not recorded:
        findings.append((BAD, name, f"{prov_path.name} records no sha256"))
    elif recorded != sha256(source):
        findings.append((BAD, name, f"sha256 MISMATCH — {source.name} is not the image "
                                    f"{prov_path.name} recorded"))
    else:
        findings.append((OK, name, f"image verified against {prov_path.name}"))

    p_recorded = str(prov.get("prompt_sha256", ""))
    if prompt.is_file() and p_recorded and p_recorded != sha256(prompt):
        findings.append((BAD, name, "prompt_sha256 MISMATCH — the prompt changed after "
                                    "the image was generated"))
    elif prompt.is_file() and not p_recorded:
        findings.append((WARN, name, f"{prov_path.name} records no prompt_sha256"))


def check_clips(art: dict, bundle: Path | None,
                findings: list[tuple[str, str, str]]) -> None:
    """required_clips vs what the bake actually produced. A boss with one clip
    still builds, still validates, and still looks broken in the game."""
    required = list(art.get("required_clips", []))
    if not required:
        return
    name = art["id"]
    if bundle is None:
        findings.append((WARN, name, f"{len(required)} required clip(s) unchecked — "
                                     f"no built bundle yet (run `build`)"))
        return
    atlas = bundle / "art" / name.split(".")[-1] / "atlas.json"
    if not atlas.is_file():
        findings.append((BAD, name, f"no atlas in the bundle at {atlas.relative_to(bundle)}"))
        return
    clips = json.loads(atlas.read_text()).get("clips", [])
    have = {c.get("name") for c in clips if isinstance(c, dict)}
    missing = [c for c in required if c not in have]
    if missing:
        findings.append((BAD, name, f"{len(have)}/{len(required)} clips — missing: "
                                    f"{', '.join(missing)}"))
    else:
        findings.append((OK, name, f"all {len(required)} required clips present"))


def check_bundle(bundle: Path, findings: list[tuple[str, str, str]]) -> dict:
    """Digest verification + the human half. build.py's verify_bundle raises on a
    mismatch; the manifest also carries the blockers the build refused to clear."""
    from genforge.living.build import verify_bundle
    manifest = json.loads((bundle / "manifest.json").read_text())
    tag = bundle.name
    try:
        verify_bundle(bundle)
        findings.append((OK, tag, f"{len(manifest.get('files', {}))} files match their digests"))
    except Exception as e:
        findings.append((BAD, tag, f"bundle digests do not verify: {e}"))
    for b in manifest.get("blockers", []):
        findings.append((WARN, tag, f"blocker: {b}"))
    ch = str(manifest.get("content_hash", ""))
    approval = approval_for(ch)
    if approval is None:
        findings.append((WARN, tag, "not approved — `tools/genforge.py approve` once a "
                                    "human has reviewed the art and captured frame time"))
    elif approval.get("decision") == "rejected":
        findings.append((BAD, tag, f"REJECTED by {approval.get('who')}: {approval.get('reason')}"))
    else:
        findings.append((OK, tag, f"approved by {approval.get('who')} on "
                                  f"{approval.get('when')}: {approval.get('note', '')}"))
    return manifest


def check_release(path: Path, findings: list[tuple[str, str, str]]) -> dict:
    from genforge.living.validation import validate
    data = json.loads(path.read_text())
    pack = data.get("pack", path.stem)
    problems = validate(data, ROOT)
    if problems:
        for p in problems:
            findings.append((BAD, pack, f"schema/lore: {p}"))
    else:
        findings.append((OK, pack, "release validates against the schemas and its lore refs"))
    status = str((data.get("review") or {}).get("status", "?"))
    findings.append((OK if status != "candidate" else WARN, pack, f"review.status: {status}"))
    return data


def audit_data(pack: str | None) -> dict:
    """The audit as DATA. The console reads this; `audit` prints it. One place
    decides what a finding is — the GUI must never re-implement the rules."""
    rels, buns = releases(), bundles()
    targets = [p for p in rels if pack in (None, p)] or ([pack] if pack in buns else [])
    out = {"schema": "genforge.audit.v1", "packs": [],
           "known": sorted(set(rels) | set(buns))}
    for name in targets:
        findings: list[tuple[str, str, str]] = []
        bundle = buns.get(name, [None])[0]
        data = check_release(rels[name], findings) if name in rels else {}
        arts = []
        for art in data.get("art", []):
            before = len(findings)
            check_art(art, findings)
            check_clips(art, bundle, findings)
            mine = findings[before:]
            arts.append({"id": art["id"], "source": art.get("source", ""),
                         "required_clips": list(art.get("required_clips", [])),
                         "worst": (BAD if any(f[0] == BAD for f in mine)
                                   else WARN if any(f[0] == WARN for f in mine) else OK),
                         "findings": [{"level": l, "who": w, "message": m}
                                      for l, w, m in mine]})
        manifest = check_bundle(bundle, findings) if bundle is not None else {}
        if bundle is None:
            findings.append((WARN, name, "never built — `tools/genforge.py build "
                                         f"{name}` produces the reviewable bundle"))
        bad = sum(1 for f in findings if f[0] == BAD)
        warn = sum(1 for f in findings if f[0] == WARN)
        out["packs"].append({
            "pack": name,
            "release": str(rels[name].relative_to(ROOT)) if name in rels else "",
            "bundle": str(bundle.relative_to(ROOT)) if bundle else "",
            "review_page": str(bundle / "index.html") if bundle else "",
            "content_hash": str(manifest.get("content_hash", "")),
            "blockers": list(manifest.get("blockers", [])),
            "approval": approval_for(str(manifest.get("content_hash", ""))),
            "art": arts, "failures": bad, "open_items": warn,
            "ready": bad == 0 and warn == 0,
            "findings": [{"level": l, "who": w, "message": m} for l, w, m in findings]})
    return out


def audit(pack: str | None) -> int:
    rels, buns = releases(), bundles()
    targets = [p for p in rels if pack in (None, p)] or ([pack] if pack in buns else [])
    if not targets:
        print(f"genforge: no release or bundle named '{pack}'. Known: "
              f"{', '.join(sorted(set(rels) | set(buns))) or '(none)'}")
        return 2
    worst = OK
    for name in targets:
        findings: list[tuple[str, str, str]] = []
        bundle = buns.get(name, [None])[0]
        data = check_release(rels[name], findings) if name in rels else {}
        for art in data.get("art", []):
            check_art(art, findings)
            check_clips(art, bundle, findings)
        if bundle is not None:
            check_bundle(bundle, findings)
        else:
            findings.append((WARN, name, "never built — `tools/genforge.py build "
                                         f"{name}` produces the reviewable bundle"))
        print(f"\n=== {name} ===" + (f"   bundle: {bundle.name}" if bundle else ""))
        for level, who, msg in findings:
            print(f" [{MARK[level]}] {who}: {msg}")
            if level == BAD or (level == WARN and worst == OK):
                worst = BAD if level == BAD else WARN
        bad = sum(1 for f in findings if f[0] == BAD)
        warn = sum(1 for f in findings if f[0] == WARN)
        verdict = ("READY — machine checks clean and a human approved it" if not bad and not warn
                   else f"NOT READY — {bad} failure(s), {warn} open item(s)")
        print(f" -> {verdict}")
    return 1 if worst == BAD else 0


# ---- create / build / approve --------------------------------------------------------


def list_data() -> dict:
    rels, buns = releases(), bundles()
    rows = []
    for name in sorted(set(rels) | set(buns)):
        mine = buns.get(name, [])
        ch, ap = "", None
        if mine:
            ch = json.loads((mine[0] / "manifest.json").read_text()).get("content_hash", "")
            ap = approval_for(ch)
        rows.append({"pack": name,
                     "release": str(rels[name].relative_to(ROOT)) if name in rels else "",
                     "bundles": len(mine),
                     "bundle": str(mine[0].relative_to(ROOT)) if mine else "",
                     "content_hash": ch,
                     "state": ("no bundle" if not mine else
                               "approved" if ap and ap.get("decision") == "approved" else
                               "REJECTED" if ap else "candidate (unapproved)")})
    return {"schema": "genforge.list.v1", "packs": rows,
            "templates": sorted(rels)}


def cmd_list() -> int:
    rels, buns = releases(), bundles()
    print(f"{'pack':<18} {'release':<34} {'bundles':<8} status")
    for name in sorted(set(rels) | set(buns)):
        rel = rels.get(name)
        mine = buns.get(name, [])
        state = "no bundle"
        if mine:
            ch = json.loads((mine[0] / "manifest.json").read_text()).get("content_hash", "")
            ap = approval_for(ch)
            state = ("approved" if ap and ap.get("decision") == "approved"
                     else "REJECTED" if ap else "candidate (unapproved)")
        print(f"{name:<18} {str(rel.relative_to(ROOT)) if rel else '(no release)':<34} "
              f"{len(mine):<8} {state}")
    if not rels and not buns:
        print("(nothing yet — start with `create --from <release> --pack <new>`)")
    return 0


def cmd_create(args) -> int:
    from genforge.living.draft import draft
    src = args.template if Path(args.template).is_file() else RELEASES / f"{args.template}.json"
    if not Path(src).is_file():
        print(f"genforge: no such release: {args.template}", file=sys.stderr)
        return 2
    template = json.loads(Path(src).read_text())
    result = draft(template, args.pack, args.title, template_path=Path(src))
    out = RELEASES / f"{args.pack}.json"
    if out.exists() and not args.force:
        print(f"genforge: {out.relative_to(ROOT)} exists (use --force)", file=sys.stderr)
        return 2
    out.write_text(json.dumps(result, indent=1) + "\n", encoding="utf-8")
    print(f"drafted {out.relative_to(ROOT)}")
    print("  IT IS A TEMPLATE REMAP, NOT NEW CONTENT: replace the inherited stories, "
          "kits, art sources and season before this means anything.")
    return cmd_build(args) if args.build else 0


def cmd_build(args) -> int:
    from genforge.living.build import build
    name = getattr(args, "pack", None) or args.release
    src = RELEASES / f"{name}.json"
    if not src.is_file():
        print(f"genforge: no release at {src.relative_to(ROOT)}", file=sys.stderr)
        return 2
    target = build(src, BUNDLES)
    print(f"built {target.relative_to(ROOT)}")
    print(f"  review it in a browser: {target / 'index.html'}")
    return audit(name)


def cmd_show(args) -> int:
    mine = bundles().get(args.pack, [])
    if not mine:
        print(f"genforge: {args.pack} has no built bundle", file=sys.stderr)
        return 2
    bundle = mine[0]
    manifest = json.loads((bundle / "manifest.json").read_text())
    print(f"{bundle.relative_to(ROOT)}")
    print(f"  format {manifest.get('format')}  status {manifest.get('status')}  "
          f"publishable {manifest.get('publishable')}")
    print(f"  content_hash {manifest.get('content_hash')}")
    print(f"  files {len(manifest.get('files', {}))}   review page: {bundle / 'index.html'}")
    for b in manifest.get("blockers", []):
        print(f"  blocker: {b}")
    ap = approval_for(str(manifest.get("content_hash", "")))
    print(f"  approval: {json.dumps(ap) if ap else 'none'}")
    if len(mine) > 1:
        print(f"  ({len(mine) - 1} older bundle(s) for this pack)")
    return 0


def _decide(args, decision: str) -> int:
    mine = bundles().get(args.pack, [])
    if not mine:
        print(f"genforge: {args.pack} has no built bundle to {decision[:-1]}", file=sys.stderr)
        return 2
    bundle = mine[0]
    manifest = json.loads((bundle / "manifest.json").read_text())
    ch = str(manifest["content_hash"])
    # The approval is pinned to the bundle's hash AND to the manifest's own
    # digest: an approval that cannot name what it approved is worth nothing.
    record = {"schema": "genforge.approval.v1", "decision": decision,
              "pack": args.pack, "bundle": bundle.name, "content_hash": ch,
              "manifest_sha256": sha256(bundle / "manifest.json"),
              "who": args.who, "when": time.strftime("%Y-%m-%dT%H:%M:%S"),
              "blockers_at_decision": manifest.get("blockers", [])}
    if decision == "approved":
        record["note"] = args.note
    else:
        record["reason"] = args.reason
    APPROVALS.mkdir(parents=True, exist_ok=True)
    path = APPROVALS / f"{ch}.json"
    path.write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8")
    print(f"{decision}: {bundle.name}\n  recorded in {path.relative_to(ROOT)}")
    if decision == "approved" and record["blockers_at_decision"]:
        print(f"  NOTE: {len(record['blockers_at_decision'])} blocker(s) were open and are "
              f"recorded in the approval — publishing still needs them cleared.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="tools/genforge.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_list = sub.add_parser("list", help="every pack, its bundles and its approval state")
    p_check = sub.add_parser("check", help="audit a pack (or everything) and exit 1 on a failure")
    p_check.add_argument("pack", nargs="?", default=None)
    for p in (p_list, p_check):
        p.add_argument("--json", action="store_true",
                       help="machine-readable; what game/genforge/console.gd reads")
    p_create = sub.add_parser("create", help="draft a new release from an existing one")
    p_create.add_argument("--from", dest="template", required=True,
                          help="an existing pack name, or a path under genforge/releases")
    p_create.add_argument("--pack", required=True, help="the new lowercase snake_case namespace")
    p_create.add_argument("--title", required=True)
    p_create.add_argument("--build", action="store_true", help="build the bundle straight away")
    p_create.add_argument("--force", action="store_true", help="overwrite an existing release")
    p_build = sub.add_parser("build", help="bake the reviewable bundle for a release")
    p_build.add_argument("release", help="pack name")
    p_show = sub.add_parser("show", help="a bundle's manifest, blockers and review page")
    p_show.add_argument("pack")
    p_ok = sub.add_parser("approve", help="record a human approval of the newest bundle")
    p_ok.add_argument("pack")
    p_ok.add_argument("--note", default="", help="what was reviewed")
    p_ok.add_argument("--who", default="Ricardo")
    p_no = sub.add_parser("reject", help="record a rejection of the newest bundle")
    p_no.add_argument("pack")
    p_no.add_argument("--reason", required=True)
    p_no.add_argument("--who", default="Ricardo")
    args = ap.parse_args()

    if args.cmd == "list":
        if args.json:
            print(json.dumps(list_data(), indent=1))
            return 0
        return cmd_list()
    if args.cmd == "check":
        if args.json:
            data = audit_data(args.pack)
            print(json.dumps(data, indent=1))
            return 1 if any(p["failures"] for p in data["packs"]) else 0
        return audit(args.pack)
    if args.cmd == "create":
        return cmd_create(args)
    if args.cmd == "build":
        return cmd_build(args)
    if args.cmd == "show":
        return cmd_show(args)
    if args.cmd == "approve":
        return _decide(args, "approved")
    if args.cmd == "reject":
        return _decide(args, "rejected")
    return 2


if __name__ == "__main__":
    sys.exit(main())
