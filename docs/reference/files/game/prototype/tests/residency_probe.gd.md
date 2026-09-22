# game/prototype/tests/residency_probe.gd

Instantiates the real Hunt and isolates entity residency from streaming. Asserts wounded ordinary/boss identity and spawn-time stats, paused status timers, water-wisp return, second-hunter interest, symmetric paired bosses, no dead revival/reward duplication, paired cap reservation and capped Hag summons, plus scratch cleanup. Child physics is paused after ready via deferred calls. Companion .tscn/.uid load the test; RESIDENCY OK is required. Ground loot and finite shots are separately covered by ground_state_probe.
