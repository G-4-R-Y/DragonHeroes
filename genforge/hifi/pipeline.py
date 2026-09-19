"""process · generate · bundle · provenance — the hifi pipeline proper.

    process(image, spec)   any RGBA -> enforced sprite + channels + scorecards
    generate(spec, ...)    prompt -> backend -> best-of-n process -> bundle
    write_bundle(...)      Godot-ready folder (bundle_art.gd contract) + review

Stage order is fixed and each stage reports what it changed, so the
scorecard BEFORE (what the model delivered) and AFTER (what ships) are both on
record - the honest measure of a generator is the first, of the pipeline the
second. Nothing here needs a network; only ``generate`` calls a backend.
"""
from __future__ import annotations

import hashlib
import json
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
from PIL import Image

from . import PIPELINE_VERSION
from . import alpha as alpha_mod
from . import emissive as emissive_mod
from . import grid as grid_mod
from . import outline as outline_mod
from . import palette as palette_mod
from .colour import rgb_of
from .creatures import CreatureSpec
from .normal import hifi_normal
from .scorecard import GateConfig, Scorecard, evaluate
from .spec import PromptSpec

PROVENANCE_SCHEMA = "dragon-heroes.art-source.v1"


def _json(obj) -> str:
    def default(o):
        if isinstance(o, (np.integer,)):
            return int(o)
        if isinstance(o, (np.floating,)):
            return float(o)
        if isinstance(o, np.ndarray):
            return o.tolist()
        if isinstance(o, Path):
            return str(o)
        raise TypeError(f"not JSON serialisable: {type(o).__name__}")
    return json.dumps(obj, indent=2, default=default) + "\n"


@dataclass
class ProcessConfig:
    outline_width: int = 1            # 1-2 px per the brief
    speck_px: int = 4                 # opaque islands under this many logical px are dropped
    bg_tolerance: float = 0.09
    hue_shift_deg: float = 8.0
    gate: GateConfig = field(default_factory=GateConfig)

    def as_dict(self) -> Dict[str, object]:
        d = {k: v for k, v in self.__dict__.items() if k != "gate"}
        d["gate"] = dict(self.gate.__dict__)
        return d


@dataclass
class ProcessResult:
    albedo: np.ndarray
    emissive: np.ndarray
    normal: np.ndarray
    palette: palette_mod.Palette
    index: np.ndarray
    before: Scorecard
    after: Scorecard
    steps: Dict[str, object]

    def as_dict(self) -> Dict[str, object]:
        return {"pipeline": PIPELINE_VERSION, "steps": self.steps,
                "before": self.before.as_dict(), "after": self.after.as_dict(),
                "palette": self.palette.as_dict()}


def _rgba(image) -> np.ndarray:
    if isinstance(image, np.ndarray):
        return np.asarray(image, dtype=np.uint8)
    return np.asarray(image.convert("RGBA"), dtype=np.uint8)


def process(image, spec: CreatureSpec, cfg: Optional[ProcessConfig] = None) -> ProcessResult:
    cfg = cfg or ProcessConfig()
    cfg.gate.grid_px = spec.grid_px
    raw = _rgba(image)
    steps: Dict[str, object] = {}
    before = evaluate(raw, spec, cfg.gate)

    # 1. isolated asset: real transparency, binary alpha
    cleaned, arep = alpha_mod.enforce(raw, tol=cfg.bg_tolerance)
    steps["alpha"] = arep.as_dict()

    # 2. native 1:1 grid: lattice estimate -> one pixel per cell -> canvas
    est = grid_mod.estimate(cleaned, spec.grid_px)
    snapped = grid_mod.snap(cleaned, est)
    snapped, _ = alpha_mod.enforce(snapped, tol=cfg.bg_tolerance, speck_px=cfg.speck_px)
    canvas, fit = grid_mod.fit_canvas(snapped, spec.grid_px)
    steps["grid"] = {**est.as_dict(), **fit}

    # 3. indexed palette: material ramps, 8 shades, directional hue-shift
    pcfg = palette_mod.PaletteConfig(ramps=spec.ramps, hue_shift_deg=cfg.hue_shift_deg,
                                     emissive_hue_deg=spec.emissive_hue_deg)
    palette = palette_mod.build(canvas, pcfg)
    quant, idx, qm = palette_mod.quantize(canvas, palette)
    steps["palette"] = {**qm, "ramps": len(palette.ramps), "colors": len(palette.colors)}

    # 4. emissive channel mask (before the outline repair, so the ring never
    #    paints over the core, and the core is what the MODEL drew)
    em, emask, eint, erep = emissive_mod.extract(quant, spec.emissive_hue_deg)
    steps["emissive"] = erep.as_dict()

    # 4b. no noisy dithering / point noise: isolated pixels join their cluster
    dither_before = palette_mod.dither_score(idx)
    idx, dedithered = palette_mod.dedither(idx, protect=emask)
    quant = palette_mod.render(idx, palette)
    steps["dedither"] = {"dither_before": dither_before, "dither_after": palette_mod.dither_score(idx),
                         "pixels_changed": dedithered}

    # 5. ink-hold perimeter: measure, repair, re-measure
    ol_before = outline_mod.measure(quant, cfg.gate.ink_l_max)
    ink_rgb = rgb_of(palette.ink)
    repaired, painted = outline_mod.repair(quant, ink_rgb, width=cfg.outline_width,
                                           l_max=cfg.gate.ink_l_max, protect=emask)
    ol_after = outline_mod.measure(repaired, cfg.gate.ink_l_max)
    steps["outline"] = {"before": ol_before.as_dict(), "painted_px": painted,
                        "after": ol_after.as_dict(), "width": cfg.outline_width}
    # the ring is ink now; the index map must agree with the pixels, and the
    # emissive channel is re-read from the SHIPPED pixels so channel, normal
    # packing and scorecard all describe the same image
    _, idx, _ = palette_mod.quantize(repaired, palette)
    em, emask, eint, erep = emissive_mod.extract(repaired, spec.emissive_hue_deg)
    steps["emissive"] = {**erep.as_dict(), "extracted_before_repair": steps["emissive"]["pixels"]}

    # 6. normal map with ramp relief; emissive packed into B < 128
    normal = hifi_normal(repaired, idx, palette, emask, eint, spec.grid_px)

    after = evaluate(repaired, spec, cfg.gate, palette=palette, idx=idx,
                     extra_metrics={"input_grid_conformity": est.conformity,
                                    "outline_painted_px": painted,
                                    "background_mode": arep.background_mode})
    return ProcessResult(repaired, em, normal, palette, idx, before, after, steps)


# --------------------------------------------------------------------------
# bundle + provenance
# --------------------------------------------------------------------------

def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _save(arr: np.ndarray, path: Path) -> Path:
    Image.fromarray(arr, "RGBA").save(path, "PNG")
    return path


def write_bundle(out: Path, spec: CreatureSpec, results: List[ProcessResult],
                 frame_names: Optional[List[str]] = None, fps: float = 6.0,
                 prompt: Optional[PromptSpec] = None, raw_paths: Optional[List[Path]] = None,
                 provider: Optional[Dict[str, object]] = None,
                 cfg: Optional[ProcessConfig] = None) -> Dict[str, object]:
    """Godot-ready folder: sheet.png (albedo row), sheet_n.png (normals +
    packed emissive), sheet_e.png (emissive for review / other engines),
    atlas.json (bundle_art.gd contract), palette.json, scorecard.json,
    provenance.json, prompt.txt / negative.txt, review.html."""
    out.mkdir(parents=True, exist_ok=True)
    n = len(results)
    g = spec.grid_px
    sheet = np.zeros((g, g * n, 4), dtype=np.uint8)
    sheet_n = np.zeros_like(sheet); sheet_e = np.zeros_like(sheet)
    for i, r in enumerate(results):
        sheet[:, i * g:(i + 1) * g] = r.albedo
        sheet_n[:, i * g:(i + 1) * g] = r.normal
        sheet_e[:, i * g:(i + 1) * g] = r.emissive
    files = {"sheet.png": _save(sheet, out / "sheet.png"),
             "sheet_n.png": _save(sheet_n, out / "sheet_n.png"),
             "sheet_e.png": _save(sheet_e, out / "sheet_e.png")}
    anchor = results[0].steps["grid"]["anchor"]
    atlas = {
        "entity": spec.key, "archetype": spec.key, "skeleton": "hifi",
        "frame_size": [g, g], "anchor": anchor, "combined_sheet": "sheet.png",
        "logical_size": [g // 2, g // 2],
        "animations": {"idle": {"frames": n, "fps": fps, "loop": True, "row": 0}},
        "frame_names": frame_names or [f"frame_{i}" for i in range(n)],
        "channels": {"normal": "sheet_n.png", "emissive": "sheet_e.png",
                     "emissive_packed_in_normal_blue": True},
        "pipeline": PIPELINE_VERSION,
    }
    (out / "atlas.json").write_text(_json(atlas))
    (out / "palette.json").write_text(_json(results[0].palette.as_dict()))
    cards = {"schema": "dragon-heroes.hifi-scorecard.v1", "frames": [
        {"name": atlas["frame_names"][i], "before": r.before.as_dict(), "after": r.after.as_dict(),
         "steps": r.steps} for i, r in enumerate(results)]}
    cards["verdict"] = "PASS" if all(r.after.verdict == "PASS" for r in results) else "FAIL"
    (out / "scorecard.json").write_text(_json(cards))
    if prompt is not None:
        (out / "prompt.txt").write_text(prompt.positive + "\n")
        (out / "negative.txt").write_text(prompt.negative + "\n")
    prov = {
        "schema": PROVENANCE_SCHEMA,
        "record_kind": "generation-witnessed" if provider else "post-processed-import",
        "pipeline": PIPELINE_VERSION,
        "pipeline_config": (cfg or ProcessConfig()).as_dict(),
        "creature": {"key": spec.key, "name": spec.name, "description": spec.description,
                     "emissive_hue_deg": spec.emissive_hue_deg, "grid_px": g},
        "provider": provider or {"name": "external", "model": "unknown"},
        "prompt": prompt.as_record() if prompt else None,
        "raw_inputs": [{"path": p.name, "sha256": _sha(p)} for p in (raw_paths or []) if p.exists()],
        "outputs": {k: _sha(v) for k, v in files.items()},
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "status": cards["verdict"],
        "limitations": [
            "Exact generation cannot be replayed unless the provider exposes a seed.",
            "The scorecard measures the pillars; it cannot grade composition, anatomy or taste — "
            "human art direction remains the last gate (design/17 §5: no raw AI output ever ships).",
        ],
    }
    (out / "provenance.json").write_text(_json(prov))
    (out / "review.html").write_text(review_html(spec, atlas, cards, results))
    return {"out": str(out), "verdict": cards["verdict"], "frames": n,
            "files": sorted(p.name for p in out.iterdir())}


def review_html(spec: CreatureSpec, atlas: Dict[str, object], cards: Dict[str, object],
                results: List[ProcessResult]) -> str:
    rows = []
    for i, r in enumerate(results):
        chk = "".join(f"<tr><td>{c.name}</td><td>{'hard' if c.hard else 'adv.'}</td>"
                      f"<td class={'ok' if c.passed else 'no'}>{'ok' if c.passed else 'NO'}</td>"
                      f"<td>{c.detail}</td></tr>" for c in r.after.checks)
        rows.append(f"<h2>{atlas['frame_names'][i]} — {r.after.verdict} ({r.after.score})"
                    f" · model delivered: {r.before.verdict} ({r.before.score})</h2>"
                    f"<table class=checks><tr><th>check</th><th></th><th></th><th>detail</th></tr>{chk}</table>")
    g = spec.grid_px
    return f"""<!doctype html><meta charset=utf-8><title>hifi review — {spec.name}</title>
<style>body{{background:#111;color:#ddd;font:14px system-ui;margin:24px}}
.sheet img{{image-rendering:pixelated;background:
repeating-conic-gradient(#333 0 25%,#222 0 50%) 0 0/16px 16px;margin:4px}}
table.checks{{border-collapse:collapse}}td,th{{padding:2px 8px;border-bottom:1px solid #333}}
.ok{{color:#7c6}}.no{{color:#e66}}h1 small{{color:#888;font-weight:normal}}</style>
<h1>{spec.name} <small>{spec.key} · {g}px · {cards['verdict']}</small></h1>
<p>{spec.description}</p>
<div class=sheet>
<div>albedo<br><img src=sheet.png width={g*len(results)*2}></div>
<div>normal (+ packed emissive in B&lt;128)<br><img src=sheet_n.png width={g*len(results)*2}></div>
<div>emissive<br><img src=sheet_e.png width={g*len(results)*2}></div>
</div>{''.join(rows)}
<p><small>Scorecards measure the five pillars of <code>sprites prompt.md</code>; they cannot grade
composition or anatomy. A named artist's review is the last gate.</small></p>
"""


# --------------------------------------------------------------------------
# generation
# --------------------------------------------------------------------------

def generate(spec: CreatureSpec, out: Path, backend=None, n: int = 2, size: str = "1024x1024",
             stance: Optional[str] = None, cfg: Optional[ProcessConfig] = None,
             quality: Optional[str] = None) -> Dict[str, object]:
    """Prompt -> backend -> process each candidate -> keep the best PASS -> bundle.
    backend: anything with .name/.model/.generate(prompt, size, n, **opts) and an
    optional .supports_negative flag (genforge.pipeline.image_backend seam)."""
    from genforge.pipeline.image_backend import get_image_backend
    if backend is None:
        # the image model is a knob, never a constant: Ricardo picks the tier
        # (GENFORGE_HIFI_IMAGE_MODEL), the seam picks the provider
        model = os.environ.get("GENFORGE_HIFI_IMAGE_MODEL", "").strip()
        backend = get_image_backend(**({"model": model} if model else {}))
    cfg = cfg or ProcessConfig()
    prompt = spec.prompt(stance)
    native = bool(getattr(backend, "supports_negative", False))
    rendered = prompt.render(native)
    opts: Dict[str, object] = {"background": "transparent"}
    if quality:
        opts["quality"] = quality
    if native:
        opts["negative_prompt"] = rendered["negative_prompt"]
    images = backend.generate(rendered["prompt"], size=size, n=n, **opts)
    out.mkdir(parents=True, exist_ok=True)
    raw_paths, results = [], []
    for i, img in enumerate(images):
        p = out / f"raw_{i}.png"
        img.convert("RGBA").save(p, "PNG")
        raw_paths.append(p)
        results.append(process(img, spec, cfg))
    order = sorted(range(len(results)), key=lambda i: (results[i].after.verdict != "PASS",
                                                       -results[i].after.score,
                                                       -results[i].before.score))
    best = order[0]
    provider = {"name": getattr(backend, "name", "?"), "model": getattr(backend, "model", "?"),
                "size": size, "n": n, "negative_native": native, "opts": {k: v for k, v in opts.items()
                                                                         if k != "negative_prompt"}}
    report = write_bundle(out, spec, [results[best]], frame_names=[f"raw_{best}"], prompt=prompt,
                          raw_paths=raw_paths, provider=provider, cfg=cfg)
    report["candidates"] = [{"raw": raw_paths[i].name, "before": results[i].before.score,
                             "after": results[i].after.score, "verdict": results[i].after.verdict,
                             "failures": results[i].after.failures} for i in range(len(results))]
    report["chosen"] = raw_paths[best].name
    (out / "candidates.json").write_text(_json(report["candidates"]))
    return report
