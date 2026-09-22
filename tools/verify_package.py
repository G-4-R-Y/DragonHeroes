#!/usr/bin/env python3
"""Verify a built package, including actual embedded Windows icon resources."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def pe_resources(path):
    data = path.read_bytes()
    def read(fmt, offset):
        try:
            return struct.unpack_from(fmt, data, offset)
        except struct.error as error:
            raise ValueError(f"Truncated PE file: {path}") from error
    if data[:2] != b"MZ":
        raise ValueError(f"Not a Windows PE executable: {path}")
    pe, = read("<I", 0x3c)
    if data[pe:pe+4] != b"PE\0\0":
        raise ValueError("Invalid PE signature")
    count, = read("<H", pe+6)
    optional_size, = read("<H", pe+20)
    optional = pe+24
    magic, = read("<H", optional)
    if magic not in (0x10b, 0x20b) or not 1 <= count <= 96:
        raise ValueError("Unsupported PE header")
    directories = optional + (112 if magic == 0x20b else 96)
    resource_rva, resource_size = read("<II", directories+16)
    sections = [read("<IIII", optional+optional_size+i*40+8) for i in range(count)]
    def offset(rva):
        for virtual_size, address, raw_size, raw_offset in sections:
            if address <= rva < address+max(virtual_size, raw_size):
                if rva-address >= raw_size:
                    break
                return raw_offset+rva-address
        raise ValueError("PE resource RVA outside initialized sections")
    if not resource_rva or not resource_size:
        raise ValueError("Executable has no embedded resources")
    base = offset(resource_rva)
    resources = {}
    def visit(relative, trail):
        if relative >= resource_size or len(trail) > 3:
            raise ValueError("Invalid PE resource tree")
        named, ids = read("<HH", base+relative+12)
        if named+ids > 4096:
            raise ValueError("Excessive PE resource entries")
        for index in range(named+ids):
            name, child = read("<II", base+relative+16+index*8)
            if name & 0x80000000:
                # Godot uses a named MAINICON group; windres uses numeric IDs.
                string_offset = name & 0x7fffffff
                length, = read("<H", base+string_offset)
                if string_offset+2+length*2 > resource_size:
                    raise ValueError("PE resource name exceeds resource section")
                start = base+string_offset+2
                name = data[start:start+length*2].decode("utf-16-le")
            if child & 0x80000000:
                visit(child & 0x7fffffff, trail+(name,))
            else:
                rva, length = read("<II", base+child)
                start = offset(rva)
                if start+length > len(data):
                    raise ValueError("Resource exceeds file")
                resources[trail+(name,)] = data[start:start+length]
    visit(0, ())
    return resources


def verify_icon(executable, ico):
    data = ico.read_bytes()
    reserved, kind, count = struct.unpack_from("<HHH", data)
    if reserved != 0 or kind != 1:
        raise ValueError("Not an ICO file")
    expected = {}
    for i in range(count):
        w,h,_,_,_,_,length,start = struct.unpack_from("<BBBBHHII", data, 6+i*16)
        expected[(w or 256,h or 256)] = data[start:start+length]
    resources = pe_resources(executable)
    groups = [(key,payload) for key,payload in resources.items() if key[0] == 14]
    for key, group in groups:
        if len(group) < 6:
            continue
        total, = struct.unpack_from("<H", group, 4)
        found = {}
        for i in range(total):
            w,h,_,_,_,_,length,icon_id = struct.unpack_from("<BBBBHHIH", group, 6+i*14)
            payload = resources.get((3,icon_id,key[-1]))
            if payload is not None and len(payload) == length:
                found[(w or 256,h or 256)] = payload
        if all(found.get(size) == payload for size,payload in expected.items()):
            return sorted(expected)
    raise ValueError(f"Expected dragon icon missing or incomplete in {executable.name}")


def verify(package, ico):
    package = package.resolve()
    manifest = json.loads((package / "BUILD-INFO.json").read_text())
    required = {manifest["executable"], manifest["world_helper"], "dragon-heroes.png",
                "dragon-heroes.ico", "LEIA-ME.txt", "content-review/index.html"}
    if not required <= set(manifest["files"]):
        raise ValueError("Package manifest is missing required files")
    for relative, expected in manifest["files"].items():
        path = (package / relative).resolve()
        if not path.is_relative_to(package) or not path.is_file():
            raise ValueError(f"Invalid package entry: {relative}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Package hash mismatch: {relative}")
    if manifest["platform"] == "windows":
        for name in (manifest["executable"], manifest["world_helper"]):
            sizes = verify_icon(package / name, ico)
            print(f"EMBEDDED ICON OK: {name} — {sizes}")
    else:
        for name in (manifest["executable"], manifest["world_helper"]):
            path = package / name
            with path.open("rb") as handle:
                if handle.read(4) != b"\x7fELF":
                    raise ValueError(f"Not an ELF executable: {name}")
            if path.stat().st_mode & 0o111 == 0:
                raise ValueError(f"Executable permission missing: {name}")
    print(f"PACKAGE CONTENTS OK: {manifest['platform']} / {len(manifest['files'])} files")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    verify(args.package, args.package / "dragon-heroes.ico")
