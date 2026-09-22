"""R81 offline diagnostics; candidate outputs only, never stages game assets."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
import numpy as np
from PIL import Image
from genforge.hifi import creatures, fixture, grid, pipeline

out = ROOT / 'genforge/candidates/r81'
out.mkdir(parents=True, exist_ok=True)
spec = creatures.get('orun')
source = Image.open(ROOT / 'genforge/art_sources/bellwether/source-v2.png')
indices = [0, 4, 8, 12, 16, 23]
names = ['idle', 'move', 'anticipation', 'attack', 'hit', 'death']
results = []
raws = []
for i in indices:
    x, y = i % 4 * 256, i // 4 * 256
    cell = source.crop((x, y, x + 256, y + 256))
    path = out / f'cell-{i}.png'
    cell.save(path)
    raws.append(path)
    results.append(pipeline.process(cell, spec))
bundle = pipeline.write_bundle(out / 'six-pose-diagnostic', spec, results,
                              frame_names=names, raw_paths=raws)
threshold = []
for width in (240, 241):
    arr = np.zeros((256, 256, 4), dtype=np.uint8)
    arr[20:120, 7:7 + width] = (80, 100, 120, 255)
    _, fit = grid.fit_canvas(arr, 256)
    threshold.append({'input_width': width, **fit})
clean = pipeline.process(fixture.clean_sprite(), spec)
duplicate = pipeline.write_bundle(out / 'duplicate-diagnostic', spec, [clean, clean],
                                  frame_names=['same-a', 'same-b'])
report = {
    'purpose': 'Diagnostic only. No art approval, staging or provider calls.',
    'source': 'genforge/art_sources/bellwether/source-v2.png',
    'sampled_cells': [dict(frame=i, pose=n, before=r.before.as_dict(),
                           after=r.after.as_dict(), steps=r.steps)
                      for i, n, r in zip(indices, names, results)],
    'sample_bundle': bundle,
    'sample_palette_count': len({tuple(r.palette.colors) for r in results}),
    'canvas_threshold': threshold,
    'duplicate_bundle': duplicate,
}
(out / 'diagnosis.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({
    'sample_verdicts': [(n, r.after.verdict, r.after.failures) for n, r in zip(names, results)],
    'palette_count': report['sample_palette_count'],
    'canvas_threshold': threshold,
    'identical_frames_bundle_verdict': duplicate['verdict'],
}, indent=2))
