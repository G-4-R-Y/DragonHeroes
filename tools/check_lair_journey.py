#!/usr/bin/env python3
"""Test the real generated-world → lair → saved loot → boss rush loop."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]


def check(package=None, capture=False):
    output=ROOT/'genforge/candidates/lairs'
    output.mkdir(parents=True, exist_ok=True)
    name='capture' if capture else 'exported' if package else 'dev'
    with tempfile.TemporaryDirectory(prefix='session-',dir=output) as temporary:
        env=dict(os.environ)
        for key in ('XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):
            path=Path(temporary)/key.lower(); path.mkdir(); env[key]=str(path)
        command=[str(package.resolve()/'dragon-heroes-codex.x86_64')] if package else ['godot','--path',str(ROOT/'game')]
        command += ['--rendering-method','gl_compatibility','--max-fps','60']
        if not capture: command += ['--headless']
        command += ['--','--lairs-selftest']
        if capture: command += ['--lairs-capture']
        log_path=output/f'{name}.log'
        with log_path.open('w') as log:
            process=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=150)
        log=log_path.read_text()
        if process.returncode or 'ERROR:' in log:
            raise RuntimeError(f'Lair journey failed; {log_path}\n{log[-4000:]}')
        data=Path(env['XDG_DATA_HOME'])/'Dragon Heroes Codex'
        report=json.loads((data/'lair-smoke.json').read_text())
        if not report.get('passed') or report['earned_artifacts']!=2: raise RuntimeError(str(report))
        (output/f'{name}.json').write_text(json.dumps(report,indent=2)+'\n')
        for picture in data.glob('lair-*.png'): shutil.copyfile(picture, output/picture.name)
        print(f'LAIR JOURNEY OK: {name}: {report}')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package',type=Path)
    parser.add_argument('--capture',action='store_true')
    args=parser.parse_args()
    check(args.package,args.capture)
