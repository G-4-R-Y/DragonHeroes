# Source-file continuation notes

These notes complement the systems map and law docs. A path mirrors its source:
`game/prototype/pickup.gd` → `game/prototype/pickup.gd.md` here. Keep responsibility,
state ownership, callers, invariants, tests and known limits current in the same
change as the implementation. Generated `.uid`, capture and build artifacts are
documented by the owning source note rather than recursive notes about notes.

Initial coverage: encounter/loot/projectile residency and Hunt water teardown.
The wider repository is not yet fully covered; R30 tracks that continuing work.

- [Encounter residency](game/prototype/encounter_residency.gd.md)
- [Ground loot](game/prototype/pickup.gd.md)
- [Projectiles](game/prototype/projectile.gd.md)
- [World presentation/streaming](game/prototype/world_gen.gd.md)
- [Ground-state outcome gate](game/prototype/tests/ground_state_probe.gd.md)
- [Repeated Hunt exit gate](tools/check_hunt_exit.py.md)
- [Narrative graph](genforge/living/narrative.py.md)
- [Candidate validation](genforge/living/validation.py.md)
- [Weekly drafting](genforge/living/draft.py.md)
- [Local review builds](genforge/living/build.py.md)
- [Narrative outcomes test](genforge/tests/test_narrative.py.md)

Other source notes:

- [game/prototype/main.gd](game/prototype/main.gd.md)
- [game/prototype/hag.gd](game/prototype/hag.gd.md)
- [game/prototype/tests/residency_probe.gd](game/prototype/tests/residency_probe.gd.md)
- [game/prototype/tests/residency_capture.gd](game/prototype/tests/residency_capture.gd.md)
- [tools/install_linux_launcher.py](tools/install_linux_launcher.py.md)
- [genforge/tests/test_renewal.py](genforge/tests/test_renewal.py.md)
- [genforge/tests/test_living.py](genforge/tests/test_living.py.md)
