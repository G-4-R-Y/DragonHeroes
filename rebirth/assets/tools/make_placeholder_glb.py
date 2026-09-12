#!/usr/bin/env python3
"""Pure-python GLB writer: stylized low-poly placeholder creatures so the GLB
hook in every engine folder (godot3d/, native/, unreal/) can be exercised
BEFORE a Gen-AI mesh exists (GenForge concept -> TripoSR/Pixal3D -> GLB is the
real feed; see gen_assets.py). No trimesh/pygltflib dependency on purpose —
this must run on the bare system python.

  python3 make_placeholder_glb.py dragon ../glb/dragon.glb
  python3 make_placeholder_glb.py hunter ../glb/hunter.glb
  python3 make_placeholder_glb.py pet    ../glb/pet.glb

Output: glTF 2.0 binary, one mesh, POSITION + NORMAL + COLOR_0 (RGBA float),
uint32 indices, +Y up, metres, facing -Z (Godot/glTF forward).
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path


class MeshBuilder:
    def __init__(self) -> None:
        self.pos: list[tuple[float, float, float]] = []
        self.nrm: list[tuple[float, float, float]] = []
        self.col: list[tuple[float, float, float, float]] = []
        self.idx: list[int] = []

    def _tri(self, a, b, c, color) -> None:
        ax, ay, az = a
        bx, by, bz = b
        cx, cy, cz = c
        ux, uy, uz = bx - ax, by - ay, bz - az
        vx, vy, vz = cx - ax, cy - ay, cz - az
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        n = (nx / ln, ny / ln, nz / ln)
        base = len(self.pos)
        for p in (a, b, c):
            self.pos.append(p)
            self.nrm.append(n)
            self.col.append(color)
        self.idx.extend((base, base + 1, base + 2))

    def quad(self, a, b, c, d, color) -> None:
        self._tri(a, b, c, color)
        self._tri(a, c, d, color)

    def box(self, center, size, color, yaw=0.0) -> None:
        cx, cy, cz = center
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        cs, sn = math.cos(yaw), math.sin(yaw)

        def p(x, y, z):
            rx = x * cs + z * sn
            rz = -x * sn + z * cs
            return (cx + rx, cy + y, cz + rz)

        v = [p(-sx, -sy, -sz), p(sx, -sy, -sz), p(sx, sy, -sz), p(-sx, sy, -sz),
             p(-sx, -sy, sz), p(sx, -sy, sz), p(sx, sy, sz), p(-sx, sy, sz)]
        self.quad(v[0], v[3], v[2], v[1], color)   # -Z
        self.quad(v[4], v[5], v[6], v[7], color)   # +Z
        self.quad(v[0], v[4], v[7], v[3], color)   # -X
        self.quad(v[1], v[2], v[6], v[5], color)   # +X
        self.quad(v[3], v[7], v[6], v[2], color)   # +Y
        self.quad(v[0], v[1], v[5], v[4], color)   # -Y

    def ellipsoid(self, center, radii, color, seg=10, rings=6) -> None:
        cx, cy, cz = center
        rx, ry, rz = radii
        grid = []
        for i in range(rings + 1):
            phi = math.pi * i / rings
            row = []
            for j in range(seg):
                th = 2 * math.pi * j / seg
                row.append((cx + rx * math.sin(phi) * math.cos(th), cy + ry * math.cos(phi), cz + rz * math.sin(phi) * math.sin(th)))
            grid.append(row)
        for i in range(rings):
            for j in range(seg):
                a, b = grid[i][j], grid[i][(j + 1) % seg]
                c, d = grid[i + 1][(j + 1) % seg], grid[i + 1][j]
                self.quad(a, d, c, b, color)

    def fin(self, root, tip_a, tip_b, color) -> None:
        self._tri(root, tip_a, tip_b, color)
        self._tri(root, tip_b, tip_a, color)


def build_dragon(m: MeshBuilder) -> None:
    hide = (0.22, 0.09, 0.08, 1.0)
    belly = (0.45, 0.26, 0.13, 1.0)
    wing = (0.32, 0.11, 0.11, 1.0)
    glow = (1.0, 0.55, 0.1, 1.0)
    horn = (0.1, 0.09, 0.09, 1.0)
    m.ellipsoid((0, 1.9, 0.2), (1.35, 1.2, 3.1), hide, 14, 8)
    m.ellipsoid((0, 1.3, -0.9), (1.05, 0.8, 1.7), belly, 10, 6)
    # neck + head
    for k in range(5):
        t = k / 4
        m.ellipsoid((0, 2.4 + t * 1.9, -2.6 - t * 1.9), (0.6 - t * 0.12, 0.6 - t * 0.12, 0.7), hide, 8, 4)
    m.box((0, 4.35, -5.1), (1.1, 0.9, 2.2), hide)
    m.box((0, 4.05, -6.0), (0.8, 0.35, 1.0), belly)
    for s in (-1, 1):
        m.ellipsoid((s * 0.45, 4.55, -5.75), (0.13, 0.13, 0.13), glow, 6, 3)
        m.box((s * 0.45, 5.15, -4.6), (0.2, 1.1, 0.2), horn, 0.0)
        # wings: 3 finger bones + membrane fan
        rootp = (s * 1.2, 2.7, -0.4)
        tips = [(s * 6.6, 3.9, -2.4), (s * 7.4, 3.4, 0.2), (s * 6.4, 3.0, 2.6), (s * 3.4, 2.4, 3.2)]
        for a, b in zip(tips, tips[1:]):
            m.fin(rootp, a, b, wing)
        for tp in tips[:3]:
            mid = ((rootp[0] + tp[0]) / 2, (rootp[1] + tp[1]) / 2, (rootp[2] + tp[2]) / 2)
            m.box(mid, (abs(tp[0] - rootp[0]), 0.16, 0.16), hide, 0.0)
        # legs
        m.box((s * 1.1, 0.75, 1.6), (0.55, 1.5, 0.7), hide)
        m.box((s * 1.0, 0.7, -1.4), (0.45, 1.4, 0.6), hide)
    # tail
    for k in range(7):
        t = k / 6
        m.ellipsoid((math.sin(t * 2.2) * 0.8, 1.7 - t * 0.9, 3.0 + t * 4.2), (0.55 - t * 0.42, 0.55 - t * 0.42, 0.75), hide, 8, 4)
    m.fin((0.6, 0.9, 7.4), (1.6, 1.6, 8.6), (0.9, 0.5, 8.9), wing)


def build_hunter(m: MeshBuilder) -> None:
    leather = (0.17, 0.13, 0.12, 1.0)
    skin = (0.62, 0.48, 0.38, 1.0)
    steel = (0.78, 0.8, 0.88, 1.0)
    cloth = (0.28, 0.12, 0.10, 1.0)
    m.ellipsoid((0, 1.05, 0), (0.33, 0.55, 0.24), leather, 10, 6)
    m.box((0, 0.35, 0), (0.42, 0.7, 0.3), cloth)
    m.ellipsoid((0, 1.78, 0), (0.19, 0.2, 0.19), skin, 8, 5)
    m.ellipsoid((0, 1.86, 0.02), (0.23, 0.17, 0.24), leather, 8, 4)
    for s in (-1, 1):
        m.box((s * 0.42, 1.15, 0), (0.16, 0.7, 0.16), leather)
        m.box((s * 0.14, 0.0, 0), (0.18, 0.3, 0.32), leather)
    m.box((0.46, 1.6, -0.05), (0.07, 1.15, 0.03), steel)
    m.box((0.46, 1.05, -0.05), (0.3, 0.05, 0.07), steel)


def build_pet(m: MeshBuilder) -> None:
    fur = (0.33, 0.30, 0.37, 1.0)
    dark = (0.2, 0.18, 0.24, 1.0)
    glow = (0.4, 1.0, 0.9, 1.0)
    m.ellipsoid((0, 0.55, 0), (0.3, 0.3, 0.6), fur, 10, 6)
    m.ellipsoid((0, 0.75, -0.66), (0.24, 0.22, 0.26), fur, 8, 5)
    for s in (-1, 1):
        m.box((s * 0.13, 1.0, -0.62), (0.08, 0.24, 0.06), dark)
        m.ellipsoid((s * 0.09, 0.78, -0.86), (0.04, 0.04, 0.04), glow, 6, 3)
        m.box((s * 0.16, 0.2, 0.35), (0.12, 0.4, 0.12), dark)
        m.box((s * 0.16, 0.2, -0.35), (0.12, 0.4, 0.12), dark)
    for k in range(4):
        t = k / 3
        m.ellipsoid((0, 0.6 + t * 0.3, 0.6 + t * 0.35), (0.1 - t * 0.02, 0.1 - t * 0.02, 0.2), fur, 6, 3)


BUILDERS = {"dragon": build_dragon, "hunter": build_hunter, "pet": build_pet}


def write_glb(m: MeshBuilder, out: Path, name: str) -> None:
    pos = struct.pack(f"<{len(m.pos) * 3}f", *[c for p in m.pos for c in p])
    nrm = struct.pack(f"<{len(m.nrm) * 3}f", *[c for n in m.nrm for c in n])
    col = struct.pack(f"<{len(m.col) * 4}f", *[c for k in m.col for c in k])
    idx = struct.pack(f"<{len(m.idx)}I", *m.idx)

    def pad4(b: bytes, fill: bytes = b"\x00") -> bytes:
        return b + fill * ((4 - len(b) % 4) % 4)

    blobs = [pad4(pos), pad4(nrm), pad4(col), pad4(idx)]
    offsets, off = [], 0
    for b in blobs:
        offsets.append(off)
        off += len(b)
    bin_chunk = b"".join(blobs)
    mins = [min(p[i] for p in m.pos) for i in range(3)]
    maxs = [max(p[i] for p in m.pos) for i in range(3)]
    gltf = {
        "asset": {"version": "2.0", "generator": "rebirth/assets/tools/make_placeholder_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"name": f"{name}_vertexcolor", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}}],
        "buffers": [{"byteLength": len(bin_chunk)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": offsets[0], "byteLength": len(pos), "target": 34962},
            {"buffer": 0, "byteOffset": offsets[1], "byteLength": len(nrm), "target": 34962},
            {"buffer": 0, "byteOffset": offsets[2], "byteLength": len(col), "target": 34962},
            {"buffer": 0, "byteOffset": offsets[3], "byteLength": len(idx), "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(m.pos), "type": "VEC3", "min": mins, "max": maxs},
            {"bufferView": 1, "componentType": 5126, "count": len(m.nrm), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(m.col), "type": "VEC4"},
            {"bufferView": 3, "componentType": 5125, "count": len(m.idx), "type": "SCALAR"},
        ],
    }
    json_chunk = pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    total = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(json_chunk), 0x4E4F534A))
        f.write(json_chunk)
        f.write(struct.pack("<II", len(bin_chunk), 0x004E4942))
        f.write(bin_chunk)
    print(f"[placeholder_glb] {out} · {len(m.pos)} verts · {len(m.idx) // 3} tris · bounds {mins} .. {maxs}")


def main() -> None:
    if len(sys.argv) != 3 or sys.argv[1] not in BUILDERS:
        sys.exit(f"usage: make_placeholder_glb.py <{'|'.join(BUILDERS)}> <out.glb>")
    m = MeshBuilder()
    BUILDERS[sys.argv[1]](m)
    write_glb(m, Path(sys.argv[2]), sys.argv[1])


if __name__ == "__main__":
    main()
