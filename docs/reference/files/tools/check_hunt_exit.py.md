# tools/check_hunt_exit.py

Runs sequential real headless Hunt boots with verbose resource diagnostics,
isolated XDG save/config/cache directories and full logs in candidates/hunt-exit.
Defaults to 12 runs of 150 frames. Rejects errors, leaked RIDs/ObjectDB instances,
resources still in use and 120-second timeouts; writes machine-readable receipts.
The deterministic off-tree water fixture lives in ground_state_probe. Repeated
random boots complement that fixture, never prove the absence of every future leak.
