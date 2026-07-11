#!/usr/bin/env bash
# Dragon Heroes — OPT-IN Vulkan run (the canon §4 HDR glow path).
#
# Launches the prototype under the "mobile" (Vulkan) renderer. main.gd detects
# a non-gl_compatibility rendering method at _ready and adds a WorldEnvironment
# with real HDR bloom; project.godot itself stays on gl_compatibility, so this
# script is the ONLY way into that path — normal runs are untouched.
#
# !!! WARNING: a Vulkan windowed run once took down the ENTIRE X session on
# !!! this workstation (2026-07). Save your work before launching, and never
# !!! wire this script into CI or any automated flow.
exec ~/.local/bin/godot --path game --rendering-method mobile "$@"
