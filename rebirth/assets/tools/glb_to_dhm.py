#!/usr/bin/env python3
"""GLB -> .dhm (Dragon Heroes mesh), the native/ renderer's ingest format.

The custom C++ client has no JSON/glTF dependency on purpose (smallest 3D
runtime); this stays in the shared asset pipeline. Reads glTF 2.0 binary with
triangle primitives using POSITION (+ optional NORMAL, COLOR_0 vec3/vec4 float
or normalized u8/u16) and uint8/16/32 indices — enough for TripoSR/Pixal3D
output and the placeholders. Node transforms are baked (TRS, no skins).

  python3 glb_to_dhm.py ../glb/dragon.glb ../glb/dragon.dhm

.dhm layout (little-endian): magic 'DHM1', u32 vertex_count, u32 index_count,
then vertex_count × (pos xyz f32, nrm xyz f32, rgb f32), then index_count × u32.
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

CT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path: Path):
    data = path.read_bytes()
    magic, _ver, _len = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        sys.exit("not a GLB")
    off, gltf, blob = 12, None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off:off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            blob = chunk
    return gltf, blob


def accessor(gltf, blob, idx):
    acc = gltf["accessors"][idx]
    view = gltf["bufferViews"][acc["bufferView"]]
    fmt, size = CT[acc["componentType"]]
    n = NC[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", size * n)
    out = []
    for i in range(acc["count"]):
        vals = struct.unpack_from(f"<{n}{fmt}", blob, start + i * stride)
        if acc.get("normalized") and fmt in "BHbh":
            mx = {"B": 255.0, "H": 65535.0, "b": 127.0, "h": 32767.0}[fmt]
            vals = tuple(v / mx for v in vals)
        out.append(vals)
    return out


def node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = node.get("translation", [0, 0, 0])
    q = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def xform(m, p, w=1.0):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] * w for i in range(3))


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("usage: glb_to_dhm.py in.glb out.dhm")
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    gltf, blob = read_glb(src)
    verts, idxs = [], []
    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

    def visit(ni, parent):
        node = gltf["nodes"][ni]
        m = mul(parent, node_matrix(node))
        if "mesh" in node:
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                attrs = prim["attributes"]
                pos = accessor(gltf, blob, attrs["POSITION"])
                nrm = accessor(gltf, blob, attrs["NORMAL"]) if "NORMAL" in attrs else None
                col = accessor(gltf, blob, attrs["COLOR_0"]) if "COLOR_0" in attrs else None
                base = len(verts)
                for i, p in enumerate(pos):
                    wp = xform(m, p)
                    if nrm:
                        n = xform(m, nrm[i], 0.0)
                        ln = math.sqrt(sum(c * c for c in n)) or 1.0
                        n = tuple(c / ln for c in n)
                    else:
                        n = (0.0, 1.0, 0.0)
                    c = tuple(col[i][:3]) if col else (0.7, 0.7, 0.7)
                    verts.append((wp, n, c))
                if "indices" in prim:
                    for (k,) in accessor(gltf, blob, prim["indices"]):
                        idxs.append(base + k)
                else:
                    idxs.extend(range(base, base + len(pos)))
        for ch in node.get("children", []):
            visit(ch, m)

    scene = gltf["scenes"][gltf.get("scene", 0)]
    for ni in scene["nodes"]:
        visit(ni, ident)
    dst.parent.mkdir(parents=True, exist_ok=True)
    with open(dst, "wb") as f:
        f.write(b"DHM1")
        f.write(struct.pack("<II", len(verts), len(idxs)))
        for p, n, c in verts:
            f.write(struct.pack("<9f", *p, *n, *c))
        f.write(struct.pack(f"<{len(idxs)}I", *idxs))
    print(f"[glb_to_dhm] {src.name} -> {dst} · {len(verts)} verts · {len(idxs) // 3} tris")


if __name__ == "__main__":
    main()
