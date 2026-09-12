"""Create a weekly authoring draft by remapping a reviewed template's namespace.

Usage: python -m genforge.living.draft --from <release.json> --pack <new_pack>
       --title 'New chapter' --out genforge/releases/<new_pack>.json
Stories and pixels remain template material until edited; nothing is approved.
"""
import argparse
import json
import re
from pathlib import Path

from .validation import load_validated


def draft(template, pack, title):
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
        data=draft(load_validated(args.template),args.pack,args.title)
        args.out.parent.mkdir(parents=True,exist_ok=True)
        with args.out.open("x",encoding="utf-8") as handle:
            json.dump(data,handle,indent=2,ensure_ascii=False);handle.write("\n")
        print(f"DRAFT CREATED: {args.out}; template content still needs authoring")
    except (ValueError,OSError) as error:
        p.exit(1,str(error)+"\n")


if __name__=="__main__": main()
