# game/prototype/hag.gd

Prototype Fenwitch Hag controller. _summon checks main.REPOP_CAP before every summoned actor, so a boss cannot bypass the active creature budget. Summons remain short-lived actors and do not become permanent dormant encounters. The inherited creature lifecycle and arena hooks remain. residency_probe fills the cap and invokes the actual summon path; arena self-test guards shared behavior. See tech/29 and creature design/13.
