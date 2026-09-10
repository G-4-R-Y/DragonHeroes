# 33 — P2P co-op (friends & LAN): lobby, host authority, replication

> **Status:** v1 landed (2026-09-02, Ricardo: "allow both lan play and lobby play
> via peer-to-peer… Nakama server will be the way to go futurely… keep things
> simple, just me and friends playing"). This is the prototype-grade co-op path.
> The SHIPPING architecture is unchanged (canon §6: dh-net over raw ENet, zone
> servers, Nakama matchmaking — [design/21](../design/21-multiplayer-roadmap.md)
> milestone M-A); this layer is the friends-and-LAN bridge that also de-risks
> M-A's design. Honest simplifications are listed in §6.

## How to play (the short version)

1. Everyone launches the game → main menu → **CO-OP (P2P)**.
2. One friend picks name/class and presses **HOST** — the lobby shows their
   LAN IP(s). Up to 3 more friends press **JOIN** with that IP (port 7377 UDP).
3. Everyone **READY**s, the host **START HUNT**s. All peers generate the
   *identical world* locally from the lobby seed; the hunt plays on the host.
4. Internet play: port-forward UDP 7377 on the host, or use an overlay
   (Tailscale/ZeroTier/Hamachi) — there is no NAT traversal or relay (that's
   Nakama/Edgegap territory).

## Architecture

```
game/mp/
  mp_net.gd        autoload MpNet — lobby state + RPC transport (ENet)
  lobby.tscn/gd    name/class, HOST/JOIN, ready, start
  host_driver.gd   inside the host's hunt: remote hunters + 20 Hz snapshots
  client_hunt.tscn/gd  the client view: same world from seed + puppets + inputs
  puppet.gd        replicated entity view (smoothed, zero logic)
  tests/           loopback gate (tools/mp_test.sh → MP TEST OK)
```

- **Transport:** Godot's `ENetMultiplayerPeer` — consistent with canon's ENet
  choice; combat replication is **hand-rolled RPC**, not
  MultiplayerSynchronizer/Spawner (canon §6 respected even here).
- **Host-authoritative everything** (canon spirit): the host runs the one real
  hunt — all combat, loot, fields, deaths. Clients send inputs at 30 Hz
  (unreliable) and render 20 Hz snapshots (unreliable); reliable RPCs carry
  lobby, start, and toast events. There is no client-side prediction in v1 —
  LAN latency (1-3 frames + tick) is playable for co-op PvE.
- **Remote hunters are real ProtoPlayers** on the host, driven through the
  ARENA seams: `bot_drive` + `bot_aim` for movement/aim/skills, `ProtoBuild`
  (Session-compatible) for their class build — auto-rolled from their class
  pick at the party's shared level. Same windups, cooldowns, runes, kits.
- **The world never crosses the wire:** the lobby picks the hunt seed; every
  peer runs the same deterministic dh-procgen dumps (`world.forced_seed`).
  Only entities replicate.
- **Snapshots** carry players (pos/hp/anim/dodge pips), creatures (pos/hp/state
  + a one-time spawn manifest per id: bundle/tint/scale/elite/name), bolts
  (pooled dots), and fields (pos/radius/kind). Client puppets smooth
  exponentially toward snapshot rows; creatures missing from a snapshot fade
  out (death read).

## Prototype patches (additive, marked MP HOOK)

- `creature.gd` / `projectile.gd`: creatures and hostile bolts hunt the
  **nearest** living hunter (was: the first `"player"` group node).
- `player.gd` → `main.on_player_death(self)`; `main.gd` routes *remote* deaths
  to the driver (respawn near the host in 3 s, no party gold penalty) and keeps
  the local death rules untouched.
- `world_gen.gd`: `forced_seed`; `main.gd`: reads `MpNet.pending_seed` and
  attaches the host driver when `MpNet.in_game and MpNet.is_host`.
- `project.godot`: `MpNet` autoload (second one, after `Session`).

## Testing

`tools/mp_test.sh` — two headless processes on loopback: registration, lobby
sync, seed payload, identical world, remote spawn, input-driven movement,
snapshot flow. Prints `MP HOST OK` + `MP CLIENT OK` → `MP TEST OK`.

## Honest v1 simplifications (all deliberate — friends & LAN)

- **Shared party profile:** loot, gold, XP and the bag are the host's Session —
  anyone's pickup feeds the party. Per-player inventories/progression are a
  Nakama-era feature (tech/26).
- Remote hunters get **auto-rolled builds** (class-primary attributes, rare
  weapon+chest at party level, first three actives) — not their own saved
  characters. Pet companions are the host's.
- No prediction/reconciliation, no lag compensation, no interest management —
  the dh-net milestones own those (canon §6: 300 ms hitbox history, AOI).
- No boss bar/pickup replication on the client; toasts cover the beats.
- Party cap 4 (canon §4); the host quitting ends the hunt for everyone.
- Security posture: none — play with friends only. Client-authoritative
  nothing, but the host trusts inputs blindly (fine on LAN, never for ranked).

## What this de-risks for M-A (design/21)

The seed-shared world, the nearest-player targeting, per-player build sources,
bot-driven remote bodies, and the snapshot/manifest split are exactly the
pieces M-A needs; the Nakama/zone-server swap replaces discovery, authority,
and persistence — not these mechanics.
