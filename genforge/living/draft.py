"""Create a weekly authoring draft by remapping a reviewed template's namespace.

Usage: python -m genforge.living.draft --from <release.json> --pack <new_pack>
       --title 'New chapter' --out genforge/releases/<new_pack>.json
Stories and pixels remain template material until edited; nothing is approved.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from .validation import ROOT, load_validated


def draft(template, pack, title, template_path=None):
    if not re.fullmatch(r"[a-z][a-z0-9_]*", pack) or pack == template["pack"]:
        raise ValueError("new pack must be a distinct lowercase snake_case namespace")
    prefix = template["pack"] + "."
    def remap(value):
        if isinstance(value, dict): return {k: remap(v) for k,v in value.items()}
        if isinstance(value, list): return [remap(v) for v in value]
        if isinstance(value, str) and value.startswith(prefix): return pack+value[len(template["pack"]):]
        return value
    result=remap(template)
    result.update(pack=pack,title=title)
    # Keep an explicit, immutable connection to the source chapter. Namespace
    # remapping must never sever the existing universe's history.
    if template_path is None:
        template_path = next((path for path in sorted((ROOT / "genforge/releases").glob("*.json"))
                              if json.loads(path.read_text()) == template), None)
    if template_path is None:
        raise ValueError("save the source chapter under genforge/releases before drafting")
    template_path = Path(template_path).resolve()
    try:
        relative = str(template_path.relative_to(ROOT))
    except ValueError as exc:
        raise ValueError("draft source must be a repository release") from exc
    if template_path.parent != ROOT / "genforge/releases":
        raise ValueError("draft source must be under genforge/releases")
    result["narrative"]["dependencies"] = [{"path": relative,
        "sha256": hashlib.sha256(template_path.read_bytes()).hexdigest()}]
    # Historical external links keep their original targets; local IDs remap.
    result["narrative"]["links"] = [link for link in result["narrative"]["links"]
                                    if link["to"].startswith(pack + ".")]
    result["narrative"]["links"].append({
        "from": result["narrative"]["threads"][0]["id"],
        "to": template["narrative"]["threads"][0]["id"],
        "relationship": "continues",
        "meaning": "AUTHORING PLACEHOLDER: explain how this chapter changes the earlier story; inherited lore and pixels still require original authoring and review."})
    result["review"]={"status":"candidate", "notes":
        "TEMPLATE DRAFT: replace inherited stories, kits, art sources and season. "
        "Namespace remapping does not create original content or approve a release."}
    return result


def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--from",dest="template",type=Path,required=True)
    p.add_argument("--pack",required=True);p.add_argument("--title",required=True)
    p.add_argument("--out",type=Path,required=True)
    args=p.parse_args(argv)
    try:
        data=draft(load_validated(args.template),args.pack,args.title,args.template)
        args.out.parent.mkdir(parents=True,exist_ok=True)
        with args.out.open("x",encoding="utf-8") as handle:
            json.dump(data,handle,indent=2,ensure_ascii=False);handle.write("\n")
        print(f"DRAFT CREATED: {args.out}; template content still needs authoring")
    except (ValueError,OSError) as error:
        p.exit(1,str(error)+"\n")


if __name__=="__main__": main()
