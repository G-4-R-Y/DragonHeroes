# 36 — Official content, character provenance and competitive trust

Status: implementation specification; extends [security/27](27-security-anticheat-and-economy-integrity.md),
[backend/26](26-backend-and-services.md) and [modding/32](../business/32-open-source-and-modding.md).
Canon §12.47; roadmap R21/R23–R25. Existing offline Hunt/P2P saves are untrusted
prototype data. This document does not certify them for a real-money server.

## Content promotion

Submission manifest: stable pack ID/version, content/asset hashes, generator
version, authors and ownership attestations, explicit license grants, dependency
hashes, minimum reader version, change notes and reproducible build command.
Community votes are audited nominations with anti-Sybil/rate controls, never a
deployment credential. No new executable code in downloaded mobile packs.

Promotion state: draft → validated → nominated → reviewed → signed → staged →
official. Review records art/animation, performance, balance, exploit and rights
checks separately. Only the release operator's offline signing key can authorize
an official pack hash. Runtime loads a verified allow-list and retains prior
versions for save compatibility/replay. A `core.*` ID or valid JSON is not proof
of origin. Rollback/quarantine can stop new drops without deleting owned gear.

## Preserve identity, separate authority

Maintain `character_id`, `lineage_id`, `realm` (`local`, `modded`, `official`),
content manifest hash, source checkpoint and the server's event sequence.
Exports from official state create a local fork. Local edits never update the
official branch. Returning to official play resumes the server checkpoint;
the UI previews identity/appearance that can be reused and the local inventory
that stays in its own save. Never destroy the fork to sanitize it.

Editable offline vanilla saves have the same trust level as modded saves.
Signing them with a key embedded in the client provides no authority. If offline
progress must eventually become official, design a bounded server-issued
challenge + replay-verification protocol with anti-replay accounting first;
do not accept timestamps or client drop declarations as substitutes. Online
solo mode on a trusted server can earn official progress with no such import.

## Anti-cheat layers and tests

| Layer | Server rule | Adversarial outcome |
|---|---|---|
| Authentication/transport | Session, monotonic sequence, input-rate/packet bounds, replay protection | duplicated/stale/oversized/foreign commands rejected |
| Combat | C++ movement, cooldown/resource, alive-state, collision/range/LOS, status and lineage validation | no teleport, damage injection, castless kill, duplicate proc or invalid target |
| Information | spatial AOI + visibility policy | hidden opponents/loot absent from snapshots |
| Awards | encounter/cast/death attribution; unique award ID; idempotent economy request | replayed victory cannot mint twice; client item claims ignored |
| Economy | sole writer, transactional inventory/escrow, append-only audit and reconciliation | conserved items/money under retries, failure and concurrency |
| Behavioral abuse | server replay + input anomaly/economic velocity review | investigate botting/win trading; no automatic ban from one unusual metric |
| Operations | signed releases, scoped service credentials, mint alarms, incident quarantine/rollback | compromised client/pack cannot promote itself or grant money |

Item receipts link trusted encounter ID, victim ID, participant ID, content
version and RNG/award sequence. Log security-sensitive evidence server-side;
retain only necessary player data with documented access/retention controls.
Do not expose hidden combat observations or fraud thresholds through public
replays. Appeals and reviewed sanctions are part of the implementation scope.

Blockchain can make a submitted record difficult to alter; it cannot validate
the off-chain combat event that produced the record. Our inference for this
architecture: an authoritative append-only award ledger is sufficient initially;
public anchoring would be an optional audit/export feature, with added cost and
privacy obligations, never an anti-cheat prerequisite. Background:
[NIST IR 8202](https://csrc.nist.gov/pubs/ir/8202/final).

## Rating, queue fallback and bots

Use server Glicko-2 per mode/input/power bracket, not a cumulative win counter.
Reference implementation gate: reproduce [Glickman's worked example](https://www.glicko.net/glicko/glicko2.pdf).
Measure equal-skill populations with different match volumes, varied opponents,
inactivity, boosting rings and repeated AI opponents. Keep reward points and
MMR separate. Confidence should improve with information, not confer unlimited
rank. Bounties cannot transfer MMR or buy ranked results.

Every AI match records `opponent_kind=ai`, reserved visible `[AI]` tag, policy
hash, behavior/build version and content hash. Matchmaking offers labelled AI
fallback; start unrated/exhibition. Bot ranks and human prize eligibility are
distinct fields. Never let fabricated names or tags alone establish bot status.
Bots cannot withdraw money, receive human event prizes or mint farmable tradable
items. Human ranked admission/AI rating policy requires calibration evidence.
New weekly bot builds enter a test league, then a frozen reviewed roster.

## Guild capacity is measured

Prototype authoritative territory ownership and objective events with capped
guild/alliance IDs and replayable rewards. Run native 20v20, 50v50 and 100v100
with pets, chain effects and AOI churn. Report p95/p99 30 Hz tick CPU, bytes per
client, state/replay memory, drops/overflow and crowded 60 FPS GL client frames.
Avoid all-pairs target scans and per-particle nodes. Only call a tier supported
after sustained target-hardware measurements; a 200-object idle demo is not a
200-player war test. Shipping public services still need the launch security
and backend gates in tech/26–27.
