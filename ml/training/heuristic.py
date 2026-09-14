"""The heuristic teacher: five rules, and it beats every net this project has
trained (docs/tech/25 §5.2.2).

Ricardo, 2026-09-14, choosing between "clone the heuristic then PPO", "fix
exploration only" and "ship the heuristic": *"Clone the heuristic, then PPO"*.
So this is a TEACHER, not a destination — behaviour cloning gets the student off
the floor (its move head starts alive instead of emitting 0.110 +- 0.006 forever)
and PPO improves a fighter from there instead of searching from noise.

WHY A FUNCTION AND NOT A NET. ml/training/distill.py already has the whole
pipeline — qualify, DAgger collection, KD fit, gate — and needs exactly two
things from a teacher: `forward(x) -> [move2, logits7, dodge1]` and an embedding
row. Neither requires weights. `--teacher heuristic` therefore reuses all of it,
including the qualifying gate ("a teacher that cannot beat the built-in AI has
nothing to teach"), which this passes 12/12 on both builds measured.

THE RULES, in order, and they are the same five as game/arena/heuristic_policy.gd
because a teacher that differs from the policy the gate measures would be a
fourth runtime disagreeing with the other three (the dodge-logit lesson,
docs/tech/25 §5.1):
    1. always walk straight at the foe   <- this one line is the whole margin
    2. spend each kit the moment it is off cooldown, in slot order, within 6 tiles
    3. slam when the special is up, within reach + 16 px
    4. attack within reach + 8 px
    5. otherwise noop

RANKED, NOT ONE-HOT. The logits are utilities, so the KD temperature still means
something and the student learns the teacher's ORDERING (kit > slam > attack >
noop) rather than a hard label. The runtime argmaxes the head, so ranking is
what has to survive distillation.

SILENT ON DODGE, deliberately. The heuristic has no dodge rule, and teaching a
confident "never" would be teaching something the teacher does not know. Both
builds measured have `dodge_max = 0` so it is moot there; the dodge logit is a
mild negative and PPO is expected to rediscover dodging afterwards. Stated here
rather than discovered later from a saturated head.
"""
from __future__ import annotations

import numpy as np

OBS_DIM = 31
EMB_DIM = 16
ACTION_LOGITS = 7
HEAD_DIM = 2 + ACTION_LOGITS + 1

# The thresholds are game/arena/heuristic_policy.gd's, verbatim, in pixels.
KIT_RANGE_PX = 6.0 * 16.0
TILE = 16.0
# Utility scale. Wide enough that argmax is unambiguous, narrow enough that the
# KD temperature can still soften it into a ranking.
U_KIT, U_SPECIAL, U_ATTACK, U_NOOP, U_UNAVAILABLE = 4.0, 3.0, 2.0, 0.5, -4.0
U_DODGE = -2.0


def preferred_range_y(spec: dict) -> float:
    """fighter.gd::preferred_range().y — the band's outer edge."""
    if bool(spec.get("is_ranged", False)):
        return 7.0 * TILE
    return float(spec.get("attack_reach", 2.0 * TILE))


class HeuristicTeacher:
    """Batched, obs-only, stateless. Matches distill.TeacherNet's interface so
    `collect()` and `fit()` need no special case for it."""

    schema = "arena.heuristic.v1"

    def __init__(self, spec: dict, name: str = "heuristic"):
        self.path = f"<{name}>"
        self.spec = dict(spec)
        self.kit_count = len(spec.get("kits", []))
        self.band_y = preferred_range_y(spec)
        self.hidden = ()
        self.activation = "none"
        self.embeddings: dict[str, np.ndarray] = {}

    def embedding(self, key: str) -> np.ndarray:
        """Zeros, and that is the honest answer. The embedding row is content
        identity (canon §9 §5), and a rule that only reads distance and
        cooldowns carries no content identity to hand down. The student's row is
        free to be trained by the PPO stage that follows."""
        return np.zeros(EMB_DIM, dtype=np.float64)

    def forward(self, x: np.ndarray) -> np.ndarray:
        x = np.atleast_2d(np.asarray(x, dtype=np.float64))
        n = x.shape[0]
        y = np.empty((n, HEAD_DIM), dtype=np.float64)

        # 1. walk at the foe. obs[16..17] is the relative position / 512.
        rel = x[:, 16:18]
        norm = np.linalg.norm(rel, axis=1, keepdims=True)
        y[:, 0:2] = np.where(norm > 1e-9, rel / np.maximum(norm, 1e-9), 0.0)

        dist_px = x[:, 18] * 512.0
        logits = np.full((n, ACTION_LOGITS), U_UNAVAILABLE)
        logits[:, 0] = U_NOOP

        # 2. kits first, in slot order, within 6 tiles. A slot this build does
        #    not own is never offered: its cooldown channel reads 0.0 ("ready")
        #    because build_obs only fills i < kit_count, and an unowned slot
        #    would otherwise look permanently available.
        in_kit_range = dist_px < KIT_RANGE_PX
        for i in range(self.kit_count):
            ready = (x[:, 7 + i] <= 1e-3) & in_kit_range
            logits[ready, 3 + i] = U_KIT - 0.1 * i      # earlier slot wins ties

        # 3. slam, 4. attack
        logits[(x[:, 6] <= 1e-3) & (dist_px < self.band_y + 16.0), 2] = U_SPECIAL
        logits[(x[:, 5] <= 1e-3) & (dist_px < self.band_y + 8.0), 1] = U_ATTACK

        y[:, 2:2 + ACTION_LOGITS] = logits
        y[:, 2 + ACTION_LOGITS] = U_DODGE
        return y


def teacher_for(build: str) -> HeuristicTeacher:
    """Build id -> teacher. The spec is needed for kit count and reach, which
    the 31-float observation does not carry."""
    from ml.env.dh_env import specs
    table = specs()
    if build not in table:
        raise SystemExit(f"heuristic: unknown build '{build}'")
    return HeuristicTeacher(table[build], name=f"heuristic:{build}")
