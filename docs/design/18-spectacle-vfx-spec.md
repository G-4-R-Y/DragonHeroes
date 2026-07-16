# Dragon Heroes — Spectacle-VFX Implementation Spec (authoritative)

<!-- Design workflow output, 2026-07-15. Reference: Ricardo's three commercial-ARPG
spectacle screenshots (orbital ribbon trails, screen-filling novas, damage-number
storm, post-processing). Renderer decision: "Layered now + Vulkan-ready" — full look
on the gl_compatibility default; the Vulkan opt-in adds real HDR glow on top via the
ProtoPost.set_hdr_mode() seam. -->


Single source of truth for the IMPLEMENT workflow. All paths absolute under `/home/ricz/Ricz/Projetos/IntelliGames/Dragon Heroes/`. Target renderer is **gl_compatibility** (default + `.mobile`, verified `project.godot:34-35`); every effect below reads correctly with **no engine bloom** and opens **no window and no Vulkan context**. Locked 60 FPS on mid-range mobile is a hard gate.

---

## 1. CONFIRMED CONSTRAINTS

Settled technique verdicts for Godot 4.6 `gl_compatibility` (cross-verified across recon B/D and re-checked against source this session):

| Technique | Verdict | Binding rule |
|---|---|---|
| Screen-reading canvas shader (`hint_screen_texture`) for chromatic aberration + vignette + over-bright | **SAFE** | CanvasItem feature, cross-renderer. Use exactly **one** full-frame post node. `SCREEN_PIXEL_SIZE = (1/640, 1/360)`; the integer 2× upscale is a post-render blit the shader never sees — express all offsets in texel units. |
| `BackBufferCopy` **Rect** mode | **FORBIDDEN** | Bug #111096 (4.5/4.6) — fails to update `hint_screen_texture`. Use `COPY_MODE_VIEWPORT` (whole-screen) only, or the implicit full-screen copy. |
| `MultiMeshInstance2D` (2D, `TRANSFORM_2D`, `use_colors`) | **SAFE** | Basic instanced 2D, no compute. One draw call for N instances. Buffer allocated once; per-frame writes only. **The ribbon primitive.** |
| `CPUParticles2D` pools | **SAFE** | Already the project workhorse (`fx.gd`). Keep for sparks/dust/debris. |
| `Line2D` additive | **SAFE (modest counts)** | Keep for bolts/rings/chain (`fx.gd`). Documented ribbon fallback only, capped at 24 (per-frame `PackedVector2Array` churn + N draw calls). |
| `GPUParticles2D` | **FORBIDDEN (this renderer)** | Transform-feedback emission is driver-flaky on Compatibility; `emit_particle()` unsupported; draw-order quirks. Never gameplay-critical. |
| Native `Environment.glow` on gl_compatibility | **CONDITIONAL — do NOT use in base path** | Works since 4.3 (the `main.gd:155` gate is outdated, not protective) but LDR-only with documented "screen goes dark" quirks. The X-crash risk is the Vulkan **window**, never glow. Leave the `main.gd:155-166` block exactly as-is. |

**Vulkan opt-in seam (bonus bloom).** The base reference look ships entirely on gl_compatibility via additive ribbons/glow + the post shader's over-bright term. When the project is launched via `tools/run_vulkan.sh` (`--rendering-method mobile`), the existing `main.gd:155-166` `WorldEnvironment` HDR glow lights up **on top** — fed by the same additive/emissive pixels, requiring zero per-skill rework. The single coordination point is `ProtoPost.set_hdr_mode(bool)`, called inside that same renderer branch: `false` on gl_compatibility (full fake-bloom over-bright term) / `true` on Vulkan (dial the over-bright term toward 0, keep aberration+vignette) so faked and real bloom never stack into a blown frame. **One seam, one branch, both paths correct. Do not touch the `main.gd:155` gate condition.**

---

## 2. ENGINE

Shared reuse, non-negotiable: **`ProtoGlow.add_material()`** (glow.gd:18 — the one cached ADD-blend `CanvasItemMaterial`) for every additive primitive; **`ProtoSprites.glow_tex()`** (64² soft radial) for sparks/glow; the ring-buffer + **`_reuse(tweens, idx)`** tween-kill discipline (fx.gd:67) copied verbatim into every new pool. Global filter is NEAREST (`project.godot:36`) — every new soft-texture node must set `texture_filter = TEXTURE_FILTER_LINEAR` locally or it renders blocky.

### 2.0 CanvasLayer renumber (the ONE structural edit — do first)

The post pass's full-viewport backbuffer copy captures every canvas layer with a **lower `layer`** than the post node. The integer layer stack must be renumbered once so post grades world+fx+ribbons+telegraphs but leaves the UI crisp, and so post escapes the `_cycle` CanvasModulate double-tint. Final map:

| Element | Canvas / node | `layer` | Graded by post? | Tinted by `_cycle`? |
|---|---|---|---|---|
| World, actors, fx pools, **ribbons (z=20)**, **telegraphs (z=−2)**, fields (z=−5), spores, `_cycle` | default canvas | **0** | yes (in-world) | yes (in-world) |
| **POST** (`ProtoPost`) | new CanvasLayer | **5** | — | no (own layer) |
| **Damage numbers** (`ProtoDamage`) | new CanvasLayer | **6** | no (crisp) | no |
| HUD (`main.gd:996`) | existing → bump | **10** | no | no |
| Minimap (`minimap.gd:16`) | existing → bump | **12** | no | no |
| kb_overlay (`main.gd:1302`) / character panel (`character_panel.gd:47`) | existing → bump | **14** | no | no |
| Confirm dialog (`main.gd:693`) | existing → bump | **15** | no | no |

Ribbons/telegraphs deliberately stay on the default canvas so they receive the day/night tint and the post grade (that integration is what sells them as in-world). Rejected alternative "post on layer 0 at z=900": there is no integer layer between world (0) and UI (1), and a layer-0 post rect gets its output re-multiplied by `_cycle.color` (confirmed live, main.gd:375-376) → double-darkened night frames. Take the renumber.

### 2.1 `ribbons.gd` — orbital / sweeping-trail system

- **Class:** `class_name ProtoRibbons extends MultiMeshInstance2D`. Created in `ProtoFx._ready()` as a child of `ProtoFx`; `z_as_relative = false`, `z_index = 20` (deliberate band: above fx particles at 18, below the existing thin bolt/ring accents at eff 42/48 and damage numbers; documented + tunable), `texture_filter = TEXTURE_FILTER_LINEAR`. Callers keep the `main.fx.<preset>()` contract.
- **Primitive:** ONE `MultiMesh`, `transform_format = TRANSFORM_2D`, `use_colors = true`, `mesh` = unit `QuadMesh` (1×1 centered), `material = ProtoGlow.add_material()`, `texture = ProtoSprites.ribbon_tex()` (new — §2.6).
- **Caps:** `MAX_RIBBONS = 40`, `SEG = 16` → `instance_count = 640`, allocated once. Ribbon slot `s` owns contiguous instance range `[s*SEG, s*SEG+SEG)`. Active ribbons kept compacted in `[0, active_count)` (swap-remove on death) so `visible_instance_count = active_count * SEG` is always a contiguous prefix.
- **State (pre-allocated inner-class array + free-list, never allocates mid-fight):** `{active, mode, age, life, color, width, owner:Node2D|null, spine:PackedVector2Array(SEG+1), head_idx (ring buffer)}` + mode params `{center, r0, r1, angle, ang_vel, dir, from, to, span}`. One persistent `_buf: PackedFloat32Array` sized `640*12` reserved for the optional bulk path.
- **Modes (enum):** `ORBIT` (angle += ang_vel·dt; head = center + polar(angle)·radius; center follows owner) · `CRESCENT` (sweep angle across `span` ≈120° over short life) · `STREAK` (head = from.lerp(to, age/life)) · `STREAK_FOLLOW` (re-reads `owner.global_position` each frame; releases on owner death or life) · `RADIAL` (head = center + dir·radius·ease_out(age/life)).
- **Per-frame `_process(dt)`:** for each active — age; release+zero its range if expired; push new head into spine ring buffer; `alpha = fade_in_fast_out(age/life)`; walk consecutive spine pairs → segment `j`: `mid=(p0+p1)/2`, `len`, `ang`, taper `k=lerp(1.0,0.2, j/SEG)` (fat head, thin tail); write `set_instance_transform_2d(base+j, Transform2D(ang, mid).scaled(Vector2(len, width*k)))` + `set_instance_color(base+j, Color(color.rgb, alpha*k))`.
- **Write path:** **default = `set_instance_transform_2d`/`set_instance_color`** (readable, ~96–320 calls/frame at realistic 6–20 active ribbons — trivial). Flagged optimization only if profiled hot: one `RenderingServer.multimesh_set_buffer(rid, _buf)` upload, stride **12 floats/instance (8 transform_2d + 4 color)** — packing must match Godot's exact layout (crash/garbage risk) so readback-test one instance in `fx_stress.gd` before switching.
- **API (presets on `ProtoFx`, forwarding to `_ribbons`):**
  ```
  fx.orbital(center: Vector2, cfg := {}) -> void        # burst of cfg.count ORBIT ribbons
  fx.ribbon_arc(at: Vector2, dir: Vector2, cfg := {}) -> void   # one CRESCENT slash
  fx.ribbon_streak(from: Vector2, to: Vector2, cfg := {}) -> void  # STREAK dash/dive
  fx.ribbon_radial(center: Vector2, cfg := {}) -> void  # RADIAL petals
  fx.trail_attach(node: Node2D, cfg := {}) -> int       # STREAK_FOLLOW, returns id
  fx.trail_detach(id: int) -> void
  ```
  `cfg` keys (all optional, sane defaults): `count, radius(r0), r1, radius_jitter, turns, ang_vel, span, dir, life, width, color, owner, cw`. `trail_attach` cfg: `life` (fallback so an orphaned bolt that frees without `trail_detach` still self-releases — no leak), `width, color, taper`.
- **Intensity gate:** `active_cap = int(lerp(6, 40, intensity))`, `seg_used = int(lerp(8, 16, intensity))`. Floor of 6 ribbons — the feature thins, never vanishes. Spawns beyond `active_cap` steal the oldest one-shot slot (never a pinned `STREAK_FOLLOW`/aura trail). Pool stays HIGH-sized at load; intensity gates usage only.
- **Fallback:** 24-slot additive `Line2D` pool if the MultiMesh strip math slips schedule (cap 24, document the 24 draw calls + points churn). MultiMesh is the target.

### 2.2 `fx.gd` additions (existing pools unchanged)

- Instantiate `_ribbons: ProtoRibbons` child in `_ready()`; add the six ribbon forwarders above.
- `fx.shockwave(at: Vector2, color: Color, radius: float, cfg := {}) -> void` — fat multi-ring impact/nova/death nova. `cfg`: `rings` (default 3, staggered radii + phase), `width` (thicker than `ring`'s 2.5), `life`. **Bump `RING_POOL` 8 → 12** (fx.gd:15) so a 3-ring shockwave can't starve nova rings.
- `fx.aura(owner: Node2D, color: Color, cfg := {}) -> int` / `fx.aura_detach(handle)` — public entry (matches recon P5). Delegates: registers an `AURA` descriptor on `ProtoTelegraphs` (persistent bright ring following owner) **and** pins `cfg.orbit_ribbons` (default 3) `ORBIT` ribbons tinted to owner for the duration. cfg: `radius, dur, pulse, orbit_ribbons`.
- Static `static var intensity: float = 0.5` (the master knob — §4). Existing particle presets multiply emitted `amount` by `lerp(0.4, 1.0, intensity)`; pool node counts stay fixed.

### 2.3 `post.gd` + `post.gdshader` — screen post-process

- **Class:** `class_name ProtoPost extends CanvasLayer`, `layer = 5`. Instantiated in `main._ready()`, held as `main.post`. Children in order: (1) `BackBufferCopy`, `copy_mode = COPY_MODE_VIEWPORT`; (2) full-rect `ColorRect` (`PRESET_FULL_RECT`, `mouse_filter = IGNORE`) with the `ShaderMaterial`.
- **`post.gdshader`** (first `.gdshader` in the repo; `shader_type canvas_item; render_mode blend_mix, unshaded;`), one fragment pass, ~5 taps over 230k px:
  - `uniform sampler2D screen_tex : hint_screen_texture, filter_linear;`
  - **Chromatic aberration** — radial: `off = normalize(uv-center) * SCREEN_PIXEL_SIZE * aberration * length(uv-center) * 2.0`; sample R at `uv+off`, G at `uv`, B at `uv-off`. Base `aberration ≤ 1.5` texels (= 2–3 window px after 2× blit).
  - **Vignette** — `1 - smoothstep(vig_inner, vig_outer, dist)`. **Folds in and replaces** `ambient.gd`'s static vignette (delete that block, §2.7).
  - **Over-bright grade** — `col += col * bright_boost` (mild gain; the "over-bright additive over a dark scene" pop). **No gaussian bloom** — bloom is faked by the additive ribbon/glow layer (no multi-pass blur on GL budget).
  - Uniforms: `aberration, vig_inner, vig_outer, bright_boost, kick_center, intensity`.
- **API:**
  ```
  post.set_intensity(i: float) -> void       # i<0.15 → ColorRect.visible=false, copy+pass SKIPPED (0 cost), re-enable static vignette fallback
  post.pulse(strength: float) -> void        # transient aberration+bright_boost kick, decays ~0.25s in _process; freezes correctly during hitstop (scaled delta)
  post.flash(color: Color, strength := 1.0) -> void   # finisher white-out: a SEPARATE transient additive ColorRect on a top layer (>15), NOT the graded rect
  post.set_hdr_mode(on: bool) -> void        # Vulkan seam (§1): true → bright_boost→0
  ```
- **Grep `SHADER ERROR` on first boot** — this is the repo's first shader; a compile failure is silent otherwise.

### 2.4 `telegraphs.gd` — pooled danger telegraphs + aura

- **Class:** `class_name ProtoTelegraphs extends Node2D`, on the default canvas at `z_index = -2` (ground decals: above terrain, under actors, still lightly graded by post). Held as `main.telegraphs`. **Retires `telegraph.gd`** (per-cast `ProtoTelegraph.new()`, 7 call sites migrate).
- **Two sibling draw nodes sharing ONE descriptor pool** (2 draw calls total): `_base` (normal blend — dark readable danger fills) and `_glow` (`ProtoGlow.add_material()` — bright edges, converging beams, aura rings). Both iterate the same array in `_draw`.
- **Descriptor pool:** `CAP = 24` pre-sized slots, `{active, kind, pos, owner, radius, length, width, dir, t, duration, color}`. Slot 0 reserved for player aura. Claim = grab free slot; expire = release. `_process` advances all `t`, releases expired (and any `AURA` whose `owner` fails `is_instance_valid`), `queue_redraw()` both nodes once/frame. Zero per-cast allocation.
- **Kinds:** `RING` (ground danger: filling `draw_circle` + bright edge `draw_arc`, amber `Color(1,0.55,0.15,·)`; on ALL dangerous windups) · `LINE` (tapered corridor fill + bright edges) · `BEAMS` (**red converging warning**: `count` tapered `draw_colored_polygon` wedges from a large radius pointing inward, near ends advancing inward as `t→1` so they visibly converge before impact) · `AURA` (persistent bright ring reading `owner.global_position` each redraw; green = protective, red/orange = enrage).
- **API:**
  ```
  telegraphs.ring(pos, radius, dur, color := AMBER) -> int
  telegraphs.line(p0, dir, length, width, dur, color := AMBER) -> int
  telegraphs.beams(pos, dir, cfg := {}) -> int          # cfg: count, spread, converge_dist, dur, color(=RED)
  telegraphs.aura(owner, color, cfg := {}) -> int
  telegraphs.clear(id) -> void
  ```
- **Intensity:** telegraphs are **gameplay information — never intensity-scaled** (a danger ring always renders at full clarity). Only their additive `_glow` embellishment scales.

### 2.5 `damage_numbers.gd` — pooled punchy numbers

- **Class:** `class_name ProtoDamage extends CanvasLayer`, `layer = 6` (above post → crisp, no fringing on pixel text). Held as `main._dmg`.
- **Pool:** 48 `Label`s pre-created + hidden, ONE shared `LabelSettings` (bold pixel font + outline + shadow — no per-label theme), round-robin (49th recycles oldest). Parallel state arrays `{active, world_pos, vel, age, life, base_scale, color, crit}`. **NO per-number Tween.**
- **Shared `_process(dt)`** steps all active slots: screen pos = `get_viewport().get_canvas_transform() * world_pos` + eased rising offset (anchors to the world hit-point as the camera moves); scale pop `0→1.6×(2.2× crit)→1.0`; alpha hold then fade last ~30%; small `vel.x` scatter + vertical stacking offset by a recent-spawn counter (prevents overprint in a Fan-of-Knives-into-7-pack burst).
- **Grammar:** white normal · gold/bigger + extra pop for crit · element hues (fire orange / frost cyan / arcane violet / venom green / umbral violet) · green heal. Crit optionally calls `post.pulse(small)`.
- **API — same signature, zero caller churn across the ~34 sites:**
  ```
  main.damage_number(at: Vector2, amount: float, color: Color, text := "", crit := false) -> void
  ```
- **Intensity:** `cap = int(lerp(16, 48, intensity))`; below cap, aggregate rapid ticks into a running total rather than dropping.

### 2.6 `sprites.gd` — `ribbon_tex()`

Add a cached `ribbon_tex() -> ImageTexture`, ~32×16: alpha = smoothstep transverse (Y) gaussian falloff, ~uniform along length (X), so abutting segment quads read as one continuous soft glowing strip (radial `glow_tex()` would go dotty at joins). Cached once like the other textures.

### 2.7 `ambient.gd` — vignette removal

Delete the vignette `CanvasLayer`+`TextureRect` block (ambient.gd:39-49) — the post shader owns the vignette now. Keep the spores. Retain `ProtoSprites.vignette_tex()` as the intensity<0.15 static fallback (re-enabled by `post.set_intensity`).

### 2.8 Migration of the three per-event allocators

- `main.hit_spark`/`_spark_burst` (main.gd:506-529) → route through pooled `fx.burst()` (additive pool); delete the per-hit `CPUParticles2D.new()` ×2 + `SceneTreeTimer`.
- `main.damage_number` (main.gd:531) → delegate to `main._dmg`.
- `projectile.gd` per-bolt trail (`_ready`) → `fx.trail_attach(self, {...})`; `fx.trail_detach(id)` in `_impact` (guarded by the `life` fallback).

### Global intensity / quality knob

Single float `ProtoFx.intensity ∈ [0,1]`, read by ribbons, post, damage numbers, and fx particle `amount`. **LOW/MED/HIGH = 0.15 / 0.5 / 1.0; mobile default MED (0.5).** Governing invariant: **pools are sized for the HIGH ceiling at load; intensity only gates per-frame usage, never allocation** — lowering never frees, raising never allocates, so no mid-session hitch either direction. Telegraphs exempt (gameplay clarity).

---

## 3. PER-SKILL & PER-BOSS VFX TABLE

Every hook from RECON C. "New" lists the engine call(s) to add/swap; existing hitstop/shake/pose juice is retained unless noted. `→` = additive to the current call.

### Player (`player.gd`)

| Hook (site) | Current | New engine call(s) |
|---|---|---|
| Melee cleave `_attack` hit (431-444) | `arc_slash` | `fx.ribbon_arc(at, dir, {span:2.1, color, width:6})` crescent + `fx.shockwave(at, color, 24)` on connect |
| Rogue swift stab `_attack` (60°, reach 1.8) | `arc_slash` | `fx.ribbon_arc(at, dir, {life:0.12, width:4})` ×2 fast twin steel flick |
| Mage `_cast_bolt` (508, muzzle 531) | `_cast_pulse` + `burst` | `fx.orbital(muzzle, {count:4, radius:4, life:0.2})` + `fx.trail_attach(bolt)` (projectile side) |
| E — Whirlwind `_whirlwind` (472, 500-501) | `tornado` + `ring` | `fx.orbital(player, {count:int(lerp(6,20,i)), turns:2.5, radius:26, radius_jitter:8, life:0.5, owner:player})` vortex + `fx.shockwave(player, color, 60)` |
| E — Frost Nova `_frost_nova` (538, 557-561) | `ring` + `burst` ×26 | `fx.shockwave(at, frost, radius, {rings:3})` + `fx.ribbon_radial(at, {count:12, radius, color:frost})` |
| E — Fan of Knives `_fan_of_knives` (566, 588) | `arc_slash` + 5 proj | `fx.ribbon_arc` muzzle fan + `fx.trail_attach` per knife (5) |
| Q — Shadow Rend `_shadow_rend` (447-459) | `explosion` + `ring` | screen-filling `fx.orbital(player,{count:12,turns:1.5,radius:70,color:umbral})` + `fx.ribbon_arc` big violet cleave + `fx.shockwave(at, umbral, 80)` + **`post.pulse(0.8)`** (signature) |
| Dodge `_physics_process` (213-229) | `_dodge_fx` (3 ghosts) + `burst` | `fx.ribbon_streak(from, to, {color:cyan, width:7, life:0.25})`; keep 3 ghosts as accent |
| Mount `toggle_mount` (947) | `_mount_squash` | `fx.orbital(player, {count:5, radius:14, life:0.3})` small swirl |
| Dismount `_dismount` (981) | `play_ui` | `fx.shockwave(at, dust, 30)` + `fx.dust` ring |

### Player generic executor `use_skill` (617, 8 kinds) + Cinderburst

| Kind (exec fn) | Current | New engine call(s) |
|---|---|---|
| projectile `_exec_projectile` (802) | `play_sfx` + trail | `fx.trail_attach(bolt)` + `fx.orbital` muzzle |
| nova `_exec_nova` (777, 793-794) | `ring` + `burst` | `fx.shockwave(at, color, radius, {rings:3})` + `fx.ribbon_radial` |
| cone `_exec_arc(false)` (745, 758-765) | `flame_cone`/`burst` | `fx.ribbon_arc(at, dir, {span:1.6, width:14})` wide sheet, element-tinted |
| melee_arc `_exec_arc(true)` (745, 755) | `arc_slash` | `fx.ribbon_arc` crescent |
| dash_strike `_exec_dash` (874, 896-899) | ghosts + `burst` + `arc_slash` | `fx.ribbon_streak(from, to, {})` along segment + `fx.shockwave` at end |
| buff `_exec_buff` (909, 914) | `ring` + name number | **`fx.aura(player, color, {radius:22, dur:buff_dur, orbit_ribbons:3})`** — the green protective aura (P5) |
| field `_exec_field` (920 → `spawn_field`) | field glow | `main.telegraphs.ring` (in `spawn_field`) + `fx.orbital` ignition burst |
| chain `_exec_chain` (844, 861) | `arc_link` per hop | keep `arc_link` (thick glow) + `fx.impact_pop`/small `fx.shockwave` at each node |
| Cinderburst detonate `_detonate_pop` (721) | `explosion` + `ring` | `fx.shockwave(at, fire, radius)` + `fx.orbital` burst |

### Creatures (`creature.gd`, `wisp.gd`)

| Hook (site) | Current | New engine call(s) |
|---|---|---|
| Hit reaction `take_damage` (618) | `damage_number` + `hit_spark` | pooled `main.damage_number(..., crit)` (P7) + pooled `hit_spark` (→ `fx.burst`). **No `post.pulse` per creature.** |
| DoT tick `dot_damage` (533) | `damage_number` | pooled small `main.damage_number` (tick styling, dense stacking) |
| Windup `_begin_windup` (435) | brute-only `ProtoTelegraph` | `main.telegraphs.ring(pos, radius, dur, AMBER)` on **all** dangerous windups |
| Lunger pounce `_strike` (474-488) | `dust` + `burst` | `fx.ribbon_streak(from, to, {})` leap streak + `fx.shockwave(land, color, 30)` |
| Brute slam `_strike` (457-473) | `debris` + `dust` + shake(5) | `main.telegraphs.ring` during windup + `fx.shockwave(at, color, 48)` on impact |
| Death `_die` (642) / `main.on_creature_died` (726) | collapse + flourish | flourish upgraded in main (below) |
| Wisp bolt `wisp.gd _strike` (72) | bolt + recoil | `fx.trail_attach(bolt)` + `fx.orbital` muzzle + short `main.telegraphs.ring` windup |

### Bosses

**boss.gd — Emberwing Matriarch**

| Hook | Current | New |
|---|---|---|
| `_telegraph_circle` (181) / `_telegraph_line` (189) | `ProtoTelegraph.new()` | `main.telegraphs.ring` / `.line`; **dive line → `main.telegraphs.beams`** |
| bolt (133-141) | bolt | `fx.trail_attach` + `fx.orbital` muzzle |
| dive (142-157) | `hit_spark`+`dust`+shake | `fx.ribbon_streak` dive + `fx.shockwave(land, fire, 70)` + **`post.pulse(0.6)`** |
| gust (158-166) | `tornado`+shake | `fx.orbital` wind vortex + `fx.shockwave` |
| screech (167-175, "ENRAGED!") | `_pose_pulse`+shake | **`main.telegraphs.beams`** red radial converging + `fx.aura(self, red_enrage, {})` + **`post.pulse(0.7)`** |
| breath (176-179) | `spawn_fire_field` | `fx.ribbon_arc(at, dir, {span:1.6, width:16, color:fire})` flame sheet |

**hag.gd — Fenwitch Hag**

| Hook | Current | New |
|---|---|---|
| mire telegraph (125-131) | `ProtoTelegraph` | `main.telegraphs.ring` |
| hex 3 bolts (146-158) | 3 violet bolts | `fx.trail_attach` per bolt |
| blink `_blink` (182) | `burst` both ends | `fx.ribbon_streak` twin void-warp implode/explode + **`post.pulse(0.4)`** |
| summon `_summon` (200) | green `burst` | `fx.orbital(at, {count:5, color:green})` swirl per wispling |
| mire (164-167) | `spawn_field("mire")` | field ignition + `main.telegraphs.ring` |
| curse (168-178, "CURSED SHRIEK!") | `_pose_pulse`+shake | `main.telegraphs.beams` + `fx.aura` + **`post.pulse(0.6)`** |

**duo_boss.gd — base for Pyre + Colossus**

| Hook | Current | New |
|---|---|---|
| `avenge()` (54, "VENGEANCE!") | `_pose_pulse`+shake | `main.telegraphs.beams` red enrage burst + `fx.aura(self, red, {})` + **`post.pulse(0.7)`** |
| `_telegraph_circle` (83) / `_telegraph_line` (93) | `ProtoTelegraph` | `main.telegraphs.ring` / `.beams` |

**pyre_sovereign.gd**

| Hook | Current | New |
|---|---|---|
| gust circle (66) / breath line (70) tells | telegraph | `main.telegraphs.ring` / `.beams` |
| meteor `_call_meteors` (125) + `_meteor_impact` (139) | telegraph circles + `explosion` + fire field | **`main.telegraphs.beams` sky-converging per meteor point** + `fx.shockwave(at, fire, big)` + `fx.orbital` fire burst |
| breath `_breath` (153) | `flame_cone` ×2 | `fx.ribbon_arc` ×2 flame corridor |
| gust (102-112) | `tornado`+shake | `fx.orbital` wind vortex + `fx.shockwave` |
| bolt (113-121) | bolt | `fx.trail_attach` |

**terravore_colossus.gd**

| Hook | Current | New |
|---|---|---|
| quake/upheaval circle (52/56), spikes line (60) tells | telegraph | `main.telegraphs.ring` (ground); **spikes line → `main.telegraphs.beams`** |
| quake `_quake` (110) | shake(9)+`debris`+`dust`+earth field | `fx.shockwave(at, earth, 90)` massive + **`post.pulse(0.7)`** + dust curtain |
| spikes `_spikes` (125) | `debris` along corridor | `main.telegraphs.beams` converging line + `fx.ribbon_radial` eruption along line + `fx.shockwave` pops |
| upheaval (87-90) | earth field | `main.telegraphs.ring` + field |
| boulder (91-106) | boulder | `fx.trail_attach` + heavy muzzle |

### main.gd feedback / deaths / pickups / level-up / hunt legendaries

| Hook (site) | Current | New |
|---|---|---|
| `hit_spark`/`_spark_burst` (506-529) | 2 `CPUParticles2D`+timer per hit | route to pooled `fx.burst` (§2.8) |
| `damage_number` (531) | `Label`+`Tween` per call | pooled `main._dmg` (§2.5) |
| `spawn_field` / `spawn_fire_field` (416-467) | `ProtoTelegraph` + per-kind burst | `main.telegraphs.ring` pooled + `fx.orbital` ignition |
| `on_creature_died` (726) | `hit_spark`+`explosion`+`debris`+shake | + `fx.shockwave(at, tier_color, 30)` + `fx.orbital` small ribbon burst (tier-scaled) |
| `on_boss_died` (751) | `explosion` big + `lightning` ×2 + shake(8) | **Finisher:** `fx.orbital(at,{count:16,turns:2,radius:90})` finale + `fx.shockwave(at,color,110)` big + `post.pulse(1.0)` + `post.flash(white, 0.6)` + beefed hitstop |
| `on_hag_died` (775) / `on_duo_boss_died` (785) / `on_legendary_died` (813) | flourish | same finisher, scaled by tier (legendary = largest) |
| `_grant_level_ups` (884) | `lightning`+`hit_spark`+number+shake | `fx.aura(player, gold, {})` rising + `fx.orbital` gold column + `post.flash(gold, 0.3)` |
| Player protective aura (buff, `_exec_buff`) | — | `fx.aura(player, green, {radius:22, dur, orbit_ribbons:3})` — green ring + orbiting ribbons |

Hunt legendaries have no new hook of their own: `_die` in each chassis already routes to the correct `main.on_*_died` by `legendary_entry`; the finisher scale is chosen there.

---

## 4. FRAME BUDGET

At 640×360, gl_compatibility, worst case. **The entire screen-filling spectacle adds ~5 fixed draw calls + ≤48 number labels on top of bounded pools.**

| System | Primitive | Hard cap | Draw calls | Per-frame heap alloc | Fill / overdraw |
|---|---|---|---|---|---|
| Orbital ribbons | 1 MultiMesh | 40 ribbons × 16 seg = 640 inst | **1** | 0 (buffer/spine reused) | ~1× (small additive quads) |
| Post-process | BackBufferCopy + rect shader | 1 pass, ~5 taps | **~2** | 0 | 1 copy (230k) + 1× fill, < 0.5 ms |
| Telegraphs | 2 draw nodes, 1 descriptor pool | 24 descriptors | **2** | 0 (slot claim) | negligible |
| Damage numbers | 48-Label pool + shared `_process` | 48 (realistic 8–16) | ≤48 | 0 | negligible |
| Migrated hit_spark | pooled `fx.burst` | (existing ADD pool 20) | 0 new | **0** (was 2 nodes+timer/hit) | — |
| Shockwave | `RING_POOL` 8→**12** | 3 rings + core | (in pool) | 0 | — |

**Global rules a reviewer checks:** total **< 120 draw calls/frame**; additive overdraw **< ~4× screen (~920k fragments)** — design lands near ~2–2.5× (post ~2× + ribbons ~1×); `Performance.OBJECT_NODE_COUNT` **must not rise** after warmup (a rising count is the exact signature of the four leaks being removed); CPU `TIME_PROCESS + TIME_PHYSICS_PROCESS` max **< 16.6 ms**. Net node/tween change is **negative** — removing per-hit `Label`/`Tween`/`CPUParticles2D`+timer/telegraph-node/trail-node drops the "~50–60 concurrent tweens" figure while spectacle rises.

**Degradation ladder (intensity `i`, mobile default MED=0.5):**
- Ribbons: `active_cap = int(lerp(6,40,i))`, `seg = int(lerp(8,16,i))`. Floor 6 — thins, never vanishes.
- fx particles: emitted `amount = base * lerp(0.4,1.0,i)`; node counts fixed (idle nodes free).
- Post: `i < 0.15` → `ColorRect.visible=false` → backbuffer copy + pass **skipped (0 cost)**, static vignette fallback re-enabled; else `aberration`/`bright_boost` scale with `i`.
- Telegraphs: **NOT scaled** (gameplay clarity); only `_glow` embellishment scales.
- Damage numbers: `cap = int(lerp(16,48,i))`; below cap, aggregate totals.

**Headless assertion method (pool-bound invariants):**
- Each new system exposes `func _pool_debug() -> Dictionary` returning `{size, peak_in_use}`; under `OS.is_debug_build()` `assert(in_use <= size)` on every claim (round-robin `idx=(idx+1)%POOL` already can't overflow).
- New `game/prototype/tests/fx_stress.gd` (+ `.tscn`, mirroring `click_test.gd`): deterministically fire Whirlwind + Fan-of-Knives ×5 into a fake 7-creature pack + a boss telegraph + 60 damage numbers on fixed frames for ~150 frames, then print ONE gate line and exit nonzero on any breach:
  `FXSTRESS OK ribbons_peak<=40 particles_peak<=CAP labels_peak<=48 telegraphs_peak<=24 nodes_created_after_warmup=0 draws<120 frame_ms<16.6`
- Snapshot `Performance.OBJECT_NODE_COUNT` after warmup → assert never above `baseline + fixed_pool_totals`. Assert `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME < 120`. Assert `max(TIME_PROCESS + TIME_PHYSICS_PROCESS) < 16.6 ms`.
- **Caveat (state it):** headless has **no GPU-fill measurement** — pair with one manual gl_compatibility `--print-fps` run before/after each perf-relevant change (canon "profile before and after"). Additive overdraw on mid-mobile fill rate is the one thing only an on-device run catches.

---

## 5. IMPLEMENT DECOMPOSITION

Strictly disjoint file ownership → parallel agents, no git conflict. GDScript resolves calls at runtime, so consumer files call the §2 API with no compile-time coupling to the engine files.

| Agent | Owns (exclusive) | Scope |
|---|---|---|
| **E — Engine core** | `ribbons.gd`✚, `post.gd`✚, `post.gdshader`✚, `telegraphs.gd`✚, `damage_numbers.gd`✚, `fx.gd`, `glow.gd`, `sprites.gd`, `telegraph.gd` | Build all new primitives + `ribbon_tex()`; add fx forwarders/`shockwave`/`aura`/`intensity`; `RING_POOL`→12; mark `telegraph.gd` deprecated. **Freezes and lands the §2 API first.** |
| **M — Orchestration + layering** | `main.gd`, `ambient.gd`, `minimap.gd`, `ui/character_panel.gd` | §2.0 CanvasLayer renumber (HUD→10, minimap→12, kb/panel→14, confirm→15); instantiate `post`/`telegraphs`/`_dmg`; reroute `hit_spark`/`damage_number`/`spawn_field`; death finishers + `post.pulse`/`post.flash` + level-up aura; HDR seam call inside the `main.gd:155` branch; delete ambient vignette. |
| **P — Player** | `player.gd` | All player-kit hook swaps (§3 player + executor tables). |
| **C — Creatures** | `creature.gd`, `wisp.gd` | Creature hit/DoT/windup/pounce/slam/death + wisp bolt hooks. |
| **B — Bosses** | `boss.gd`, `duo_boss.gd`, `hag.gd`, `pyre_sovereign.gd`, `terravore_colossus.gd` | All boss telegraph→beams/rings, ribbon/shockwave/aura swaps. |
| **X — Projectile + tests** | `projectile.gd`, `tests/fx_stress.gd`✚, `tests/fx_stress.tscn`✚ | Replace per-bolt trail with `trail_attach`/`trail_detach`; author the budget harness. |

(✚ = new file.) **Ownership is disjoint — verified: no file appears in two rows.** The CanvasLayer renumber spans `main.gd` + `minimap.gd` + `character_panel.gd`, all assigned solely to M, so no consumer agent touches a layer number.

**API-first ordering:** (1) §2 signatures are frozen by this spec. (2) **E and M land first** — E provides the classes, M provides the structural layering + host mounts + the pooled reroutes M depends on. (3) **P, C, B, X fan out in parallel** against the frozen API. (4) Integration gate (§6) runs after all merge. If schedule forces full parallelism, all six may develop simultaneously against §2 and merge E+M first at integration.

---

## 6. GATES

Headless only. **`grep -c` exits 1 on zero matches — never chain gates with `&&` (a clean boot would abort the chain); separate with `;` and assert the printed count is 0.** Godot binary: `~/.local/bin/godot`. Never launch a window, never Vulkan, never `pkill -f`.

```
# 0. import once (first .gdshader + new class_name scripts must register)
~/.local/bin/godot --headless --path game --import ;

# 1. menu boot — assert 0 errors (SHADER ERROR matters: first shader in repo)
~/.local/bin/godot --headless --path game --quit-after 150 2>&1 | grep -c -E "SCRIPT ERROR|SHADER ERROR" ;

# 2. hunt boot x3 — each must print 0
for i in 1 2 3 ; do ~/.local/bin/godot --headless --path game res://prototype/main.tscn --quit-after 150 2>&1 | grep -c -E "SCRIPT ERROR|SHADER ERROR" ; done ;

# 3. click_test — must end "CLICKTEST DONE — ALL PASS"
~/.local/bin/godot --headless --path game res://prototype/tests/click_test.tscn --quit-after 300 2>&1 | tail -5 ;

# 4. fx_stress budget gate — must print the FXSTRESS OK line, exit 0
~/.local/bin/godot --headless --path game res://prototype/tests/fx_stress.tscn --quit-after 200 2>&1 | grep -E "FXSTRESS|SCRIPT ERROR|SHADER ERROR"
```

Pass criteria: gates 1 & 2 each print `0`; gate 3 ends `CLICKTEST DONE — ALL PASS`; gate 4 prints `FXSTRESS OK ...` and the process exits 0 (any `_pool_debug` assert or budget breach exits nonzero). **Manual (not a headless gate, but required by canon):** one `tools`-launched gl_compatibility run with `--print-fps` before and after, confirming a locked ~60 FPS during Whirlwind-into-a-pack + boss telegraph — the only check that catches additive fill-rate on mid-mobile.

---

## 7. REGISTRY / DOCS (proposed — orchestrator merges; do not edit files)

**`content/core/registries/effects.json`** — append a new group (schema matches existing `{name, entries:[{key,name,desc,status}]}`):

```json
{
  "name": "VFX systems (spectacle pass — Ricardo 2026-07-15)",
  "entries": [
    {"key": "orbital_ribbon", "name": "Orbital Ribbon Trails", "desc": "Pooled MultiMesh2D swept-quad ribbons (40x16=640 inst, 1 draw call, shared ADD material). Orbit/crescent/streak/radial modes drive whirlwind vortices, cleaves, dash streaks, projectile trails, death finales.", "status": "live"},
    {"key": "screen_postfx", "name": "Screen Post-FX", "desc": "One full-frame canvas shader (chromatic aberration + vignette + over-bright) on a dedicated CanvasLayer(5). pulse() kicks aberration on signature hits; skipped entirely below intensity 0.15. gl_compatibility fake-bloom; Vulkan adds HDR glow on top via set_hdr_mode.", "status": "live"},
    {"key": "converging_beams", "name": "Converging Beam Telegraph", "desc": "Red tapered wedges converging inward before a boss impact (dive, screech, meteor, spikes, enrage). Pooled telegraph descriptor, never intensity-scaled.", "status": "live"},
    {"key": "danger_ring", "name": "Ground Danger Ring", "desc": "Pooled amber filling ring under every dangerous windup (24-descriptor telegraph layer, 2 draw calls). Replaces per-cast telegraph nodes.", "status": "live"},
    {"key": "protective_aura", "name": "Protective / Enrage Aura", "desc": "Persistent glowing ring + orbiting ribbons following an owner. Green = player buff protection; red/orange = boss enrage.", "status": "live"},
    {"key": "punchy_numbers", "name": "Punchy Damage Numbers", "desc": "Pooled 48-label ring, scale-pop + crit grammar + vertical stacking, one shared _process, zero per-hit allocation.", "status": "live"},
    {"key": "shockwave", "name": "Shockwave", "desc": "Fat multi-ring additive nova for impacts, novas, and deaths (RING_POOL 12).", "status": "live"}
  ]
}
```

**`docs/00-canon.md` decision log** (and cross-ref in `docs/design/17-art-direction.md`):

> **2026-07-15 (Ricardo) — Spectacle VFX vocabulary.** Screen-filling orbital ribbon trails (MultiMesh2D), a full-frame post shader (chromatic aberration + vignette + over-bright), pooled converging-beam/danger-ring telegraphs, a protective/enrage aura, and pooled punchy damage numbers land as the prototype's spectacle layer. Budget: **~5 fixed draw calls** on top of bounded pools, **< 120 draw calls/frame**, additive overdraw **< 4× screen**, locked 60 FPS on gl_compatibility mid-mobile. A single `intensity ∈ [0,1]` knob (mobile default MED) gates per-frame usage only, never allocation; telegraphs are exempt (gameplay information). **Renderer split:** the full look ships on the gl_compatibility default with faked additive bloom; the Vulkan opt-in (`tools/run_vulkan.sh`) adds real HDR `WorldEnvironment` glow on top, coordinated by the single `ProtoPost.set_hdr_mode()` seam inside the existing `main.gd:155` renderer branch — the gate condition itself is unchanged. Four per-event allocators (`damage_number`, `_spark_burst`, `telegraph.gd`, per-bolt projectile trail) are converted to pools in the same pass; net node/tween count drops while on-screen density rises.

---

*Environment note (surfaced this session, not part of the build): the claude.ai Atlassian, Coda, Figma, Fireflies, and Microsoft 365 connectors report as needing authorization and are unavailable until re-authorized via claude.ai connector settings; none are relevant to this task.*