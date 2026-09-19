"""Connected components on boolean masks — scipy when present, numpy otherwise."""
from __future__ import annotations

import numpy as np

try:  # scipy is on the dev machine but is not a genforge requirement
    from scipy import ndimage as _ndi
except Exception:  # pragma: no cover - exercised only where scipy is absent
    _ndi = None

_EIGHT = np.ones((3, 3), dtype=bool)


def label(mask: np.ndarray, connectivity: int = 8):
    """-> (labels int32 [0 = background], count). 8-connectivity by default."""
    mask = np.asarray(mask, dtype=bool)
    if _ndi is not None:
        structure = _EIGHT if connectivity == 8 else None
        lab, n = _ndi.label(mask, structure=structure)
        return lab.astype(np.int32), int(n)
    return _label_numpy(mask, connectivity)


def _label_numpy(mask: np.ndarray, connectivity: int):
    """Iterative min-label propagation; O(diameter) vectorised passes."""
    h, w = mask.shape
    lab = np.where(mask, np.arange(1, h * w + 1, dtype=np.int64).reshape(h, w), 0)
    shifts = [(0, 1), (0, -1), (1, 0), (-1, 0)]
    if connectivity == 8:
        shifts += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    while True:
        new = lab.copy()
        for dy, dx in shifts:
            sh = np.roll(lab, (dy, dx), axis=(0, 1))
            if dy > 0: sh[:dy, :] = 0
            if dy < 0: sh[dy:, :] = 0
            if dx > 0: sh[:, :dx] = 0
            if dx < 0: sh[:, dx:] = 0
            cand = np.where((sh > 0) & mask, sh, new)
            new = np.where(mask, np.minimum(new, np.where(cand > 0, cand, new)), 0)
        if np.array_equal(new, lab):
            break
        lab = new
    ids = np.unique(lab[lab > 0])
    remap = np.zeros(int(lab.max()) + 1, dtype=np.int32)
    remap[ids] = np.arange(1, len(ids) + 1, dtype=np.int32)
    return remap[lab], int(len(ids))


def component_sizes(labels: np.ndarray, count: int) -> np.ndarray:
    """sizes[k] = pixels in component k (index 0 = background)."""
    return np.bincount(labels.ravel(), minlength=count + 1)


def drop_small(mask: np.ndarray, min_px: int, connectivity: int = 8):
    """Remove components smaller than min_px. -> (mask, removed_components, removed_px)."""
    lab, n = label(mask, connectivity)
    if n == 0:
        return mask.copy(), 0, 0
    sizes = component_sizes(lab, n)
    small = np.zeros(n + 1, dtype=bool)
    small[1:] = sizes[1:] < min_px
    kill = small[lab]
    return mask & ~kill, int(small[1:].sum()), int(kill.sum())
