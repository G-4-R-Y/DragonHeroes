# game/prototype/encounter_residency.gd

Owns the local Hunt's active/dormant presentation lifetime. Parent main.gd supplies
world readiness, chunk coordinates and boss slots; creatures and ground_loot groups
supply live bodies. Per-Hunt chunk files hold primitive whitelisted records, stable
encounter IDs and original loot dictionaries. Rolled markers prevent exploration
from retaining a world-sized visited dictionary.

Sleep 1152 px / wake 960 px from every hunter. One weak queued body or scanned file
per frame; a paired boss can wake two bodies atomically against the 120 cap. Loot
wakes independently of that cap. Potential targets of live finite projectiles do
not sleep. Files are claimed before activation; a collected item or killed actor
has no remaining restorable record. Failed writes retain the live entity.

Creature timers pause while dormant; attacks return through a readable recovery.
Projectiles are not serialized or frozen: projectile.gd owns finite flight. Loot
has no distance/age expiry during the Hunt. Normal exit deletes only this adapter's
owned scratch directory. Crash orphan cleanup, official server storage and bounded
rendering of extreme piles of nearby loot remain separate work.

Gates: residency_probe (HP/statuses/duos/death/co-op/cap/water), ground_state_probe
(original rolls/full bag/full creature cap/collection once/projectile interest),
residency_capture (actual streamed GL return and frame samples). Law: tech/29,
design/28. Generated .uid and the capture/test companions belong to these sources.
