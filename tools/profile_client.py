#!/usr/bin/env python3
"""Measure actual GL frame intervals in an isolated assisted Hunt (source or export)."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package', nargs='?', type=Path, help='Linux package directory; omit for source')
    parser.add_argument('--label', default='hunt')
    parser.add_argument('--seconds', type=int, default=12, choices=range(5,61), metavar='5..60')
    args = parser.parse_args()
    if not args.label.replace('-','').replace('_','').isalnum(): parser.error('label must use letters, digits, - or _')
    output = ROOT/'genforge/candidates/performance-recovery'/args.label
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    for name in ('XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):
        folder=output/name.lower(); folder.mkdir(exist_ok=True); env[name]=str(folder)
    command = [str(args.package.resolve()/'dragon-heroes.x86_64')] if args.package else ['godot','--path',str(ROOT/'game')]
    command += ['--rendering-method','gl_compatibility','--','--client-profile',f'--profile-seconds={args.seconds}']
    result_path = Path(env['XDG_DATA_HOME'])/'Dragon Heroes/client-profile.json'
    result_path.unlink(missing_ok=True)
    with (output/'run.log').open('w') as log:
        result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=args.seconds+100)
    log=(output/'run.log').read_text()
    if result.returncode or not result_path.exists() or 'ERROR:' in log:
        raise RuntimeError(f'Profile failed; see {output / "run.log"}\n{log[-3000:]}')
    data=json.loads(result_path.read_text())
    data['source']='export' if args.package else 'editor source'
    data['label']=args.label
    (output/'result.json').write_text(json.dumps(data,indent=2)+'\n')
    shutil.copyfile(result_path.with_suffix('.png'),output/'hunt.png')
    print(json.dumps(data,indent=2))
    print('Receipt:', output)

if __name__=='__main__': main()
