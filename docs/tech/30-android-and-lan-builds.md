# 30 — Android & LAN Builds (prototype)

**Status:** practical guide — 2026-07-17. Owner: prototype. Scope: getting the
**current single-player prototype** onto an Android phone. This is a build/packaging
guide, not a mobile-readiness claim — read §5 (Honest caveats) before you assume a phone
build is playable or shippable. LAN multiplayer does not exist in the prototype; see
[../design/21-multiplayer-roadmap.md](../design/21-multiplayer-roadmap.md).

## 1. What the project already provides

Verified in `game/project.godot`:

- **Renderer:** `renderer/rendering_method="gl_compatibility"` **and**
  `renderer/rendering_method.mobile="gl_compatibility"` — the Compatibility renderer
  (OpenGL ES 3.0 class) is already the mobile method, so no renderer change is needed to
  export. (Vulkan is an opt-in desktop path only; canon §12.23, design/17.)
- **Resolution:** 640×360 viewport, `stretch/mode="canvas_items"`,
  `stretch/scale_mode="integer"` — integer-scaled pixel art, which maps cleanly onto phone
  panels (letterboxed to preserve the pixel grid).
- **Engine:** Godot **4.6** (`config/features=PackedStringArray("4.6")`).

There is **no `export_presets.cfg` in the repo yet** — §3 supplies a minimal one.

## 2. Prerequisites (one-time)

1. **Godot 4.6 editor**, matching the project's `config/features`. The Android export
   requires the Godot version and the export templates to match exactly.
2. **Android export templates for 4.6.** Install from the editor
   (*Editor → Manage Export Templates → Download and Install*) or drop the official
   `4.6.stable` template bundle into the templates directory
   (`~/.local/share/godot/export_templates/4.6.stable/` on Linux).
3. **JDK 17** — needed by `keytool` (below) and by the Android gradle build if you enable
   it. OpenJDK 17 is the supported line for the Godot 4.6 Android toolchain.
4. **Android platform-tools** for `adb` (device install). A full Android SDK +
   `min_sdk`/`target_sdk` is only required if you enable the custom **gradle build**;
   the default **prebuilt APK template** used below does not need the full SDK.
5. **A debug keystore** (§4). Godot will not export an Android package without one.

## 3. The export preset

Export presets normally get created through the editor's *Project → Export* dialog; for a
headless/CI flow the file must be committed. Below is a **minimal, working preset** for a
single `arm64-v8a` APK. Save as `game/export_presets.cfg`:

```ini
[preset.0]

name="Android arm64"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/dragonheroes-arm64.apk"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.2.0"
package/unique_name="com.intelligames.dragonheroes"
package/name="Dragon Heroes"
package/signed=true
package/app_category=2
graphics/opengl_debug=false
xr_features/xr_mode=0
screen/immersive_mode=true
screen/support_small=false
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
permissions/internet=false
```

Notes:

- **`gl_compatibility` on Android needs OpenGL ES 3.0.** `arm64-v8a` covers effectively
  all current phones; `armeabi-v7a` is left off deliberately (older 32-bit devices, not a
  target). Add it only if you must.
- **Renderer is not set here** — it comes from `project.godot`
  (`rendering_method.mobile="gl_compatibility"`), which is already correct.
- **`permissions/internet=false`** — the prototype is offline single-player and needs no
  network permission. (When co-op lands, M-A in design/21 flips this on.)
- Preset option keys can drift slightly across Godot point releases; the reliable way to
  regenerate a canonical file is to open *Project → Export* once in the 4.6 editor, add an
  Android preset, then commit the resulting `export_presets.cfg` and trim to the above.

## 4. Keystores: debug vs. release

Android packages must be signed. **Never commit a keystore or its passwords** (consistent
with the project's secrets doctrine, canon §12.24).

**Debug keystore** (for local device testing — not for distribution):

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
  -keypass android -keystore debug.keystore -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

**Release keystore** (for a signed release build — keep this file and its passwords
secret and backed up; losing it means you can never update the app):

```bash
keytool -v -genkeypair -keystore release.keystore -alias dragonheroes \
  -keyalg RSA -keysize 2048 -validity 10000
```

Godot 4 reads keystore paths and credentials from **environment variables**, so nothing
secret goes in the committed preset:

```bash
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$PWD/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
# release build:
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/release.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="dragonheroes"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<secret>"
```

## 5. Build and install (CLI)

Run from the Godot project directory (`game/`). The argument after the flag is the
**preset name** from §3 (`"Android arm64"`), then the output path.

```bash
# debug APK (uses the debug keystore env vars):
godot --headless --path game --export-debug "Android arm64" build/dragonheroes-arm64.apk

# release APK (uses the release keystore env vars):
godot --headless --path game --export-release "Android arm64" build/dragonheroes-arm64.apk
```

Install to a USB-connected phone with USB debugging enabled (or `godot --export-release`
to a device already listed by `adb devices`):

```bash
adb install -r build/dragonheroes-arm64.apk
```

`-r` reinstalls over an existing copy. The app id is `com.intelligames.dragonheroes`.

## 6. Honest caveats — read before assuming this is "the mobile build"

This produces an APK that **boots**. It does not produce a playable or shippable mobile
game. Three hard limitations, none hidden:

- **No touch controls exist.** Input is mouse + keyboard only, registered at runtime in
  `game/prototype/ui/session.gd`: WASD/arrows to move, SPACE / left-click attack, SHIFT /
  right-click dodge, and Q/E/F/Z/C/K/1–4 for skills, capture, mount, and menus. There are
  **no `InputEventScreenTouch` handlers and no virtual stick** anywhere in the prototype.
  A phone build launches into the menu and the Hunt, but is **unplayable without a
  Bluetooth controller or keyboard paired to the phone**. Touch input / virtual-stick UI
  is future work, not a config flag.
- **No mobile performance validation yet.** The 60 FPS lock is a standing directive on all
  platforms including mid-range mobile (canon directive 2), but it has only been measured
  on desktop `gl_compatibility` (the `fx_stress` / capture gates). The visual program
  (SDF shadows, sprite N·L lighting, media shaders, atmosphere layers) has **not** been
  profiled on a phone GPU. A mobile profiling pass is required before any 60 FPS claim on
  Android — treat frame time on-device as unknown until measured.
- **No LAN or multiplayer in the prototype.** It is single-player only: `dh-server` runs
  locally as a seeded world-data CLI, with no networking between machines. The path to
  co-op (including the interim self-hosted-`dh-server`-over-LAN step) is the multiplayer
  roadmap, [../design/21-multiplayer-roadmap.md](../design/21-multiplayer-roadmap.md) — it
  is directed but not yet scheduled. An Android APK today talks to nothing over the
  network.

In short: this guide is for getting the prototype **onto a device to look at and test with
a controller**, not for shipping. The mobile-shipping decision (touch UX, on-device 60 FPS
budget, store/marketplace policy) lives across canon directive 2, design/17, and the
business docs.
