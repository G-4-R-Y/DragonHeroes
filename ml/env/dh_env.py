"""dh-env — ctypes binding for libdh-env (sim/libs/dh-env, docs/tech/25).

The fast RL surface: the C++ arena twin (arena.obs.v1, 31 floats) stepped from
Python without Godot in the loop. Fighter specs come from ml/env/specs.json —
GENERATED from the real Godot bodies by game/arena/tools/dump_specs.tscn, so
balance changes reach training by re-dumping, never by hand-editing.

    env = DhEnv("core.arena.cinder_drake", "core.arena.fen_boar_alpha",
                opp="native", seed=7)
    obs = env.reset(seed=1)
    done, obs = env.step(move=(0.5, 0.0), act=3)
"""
from __future__ import annotations

import ctypes
import json
from pathlib import Path

import numpy as np

OBS_DIM = 31
_REPO = Path(__file__).resolve().parents[2]
_LIB_PATH = _REPO / "sim" / "build" / "libs" / "dh-env" / "libdh-env.so"
_SPECS_PATH = _REPO / "ml" / "env" / "specs.json"

KIT_IDS = {"none": 0, "bolt_volley": 1, "radial_slam": 2, "pounce": 3,
           "field_cast": 4, "enrage": 5}
FIELD_KIND_IDS = {"fire": 0, "earth": 1, "mire": 2, "lava": 3, "storm": 4}
OPP = {"native": 0, "scripted": 1, "mlp": 2}
# creature.gd archetype -> DhArchetype (R55). "wisp" is a chassis, not an
# archetype, and setup_from_entry skips it: the stalker swing, like any unknown.
ARCHETYPES = {"stalker": 0, "lunger": 1, "brute": 2}

_ACT_NAMES = ["noop", "attack", "special", "skill1", "skill2", "skill3",
              "skill4", "dodge"]
ACT_NOOP, ACT_ATTACK, ACT_SPECIAL, ACT_DODGE = 0, 1, 2, 7
ACTION_LOGITS = 7          # noop, attack, special, skill1..4 — the categorical

# ---- arena.mask.v1: ACTION MASKING (R50, 2026-09-19) -------------------------
# Which of the seven action logits are AVAILABLE, computed from what the policy
# can see plus two body constants (kit_count, is_player) every runtime knows
# about its own fighter. Unavailable logits go to MASK_NEG before the softmax
# (trainer) or are skipped by the argmax (serving), so pi_theta never puts
# probability on an action the sim would refuse. Why this matters for the KITS
# specifically: a kit on an 8 s cooldown is a no-op on ~299 of every 300 ticks
# it is selectable, so without the mask the credit for "cast a kit" is spread
# across 300 refused picks and one real cast — the gradient towards using the
# kit at all is 1/300 of what it should be, and the measured result was nets
# that argmax to "act 3 forever" (fen_boar v7.0) or never fire a kit (v6.0).
#
# The rule reads the obs the net sees — the DELAYED one (canon §9 §6) — so it
# is bit-identical in ml/training/policy_net.py, ml/training/torch_policy.py,
# game/arena/neural_policy.gd, dh::sim::Arena::action_mask and
# ml/eval/env_parity.py. It is a property of the obs contract, which is why it
# lives here and not in a trainer. Channels: o[5] attack cd fraction, o[6]
# special cd fraction (players; a creature's "special" is one more basic swing
# and shares o[5]), o[7+k] kit k cd fraction, o[12] dodge charges (0 for every
# body without dodges). A cooldown fraction is EXACTLY 0.0 when ready.
MASK_SCHEMA = "arena.mask.v1"
# Finite on purpose: exp(MASK_NEG - lse) underflows to exactly 0.0 in float32,
# and unlike -inf it cannot produce inf*0 = nan in an entropy or a BCE term.
MASK_NEG = -1.0e9


def action_mask(obs, kit_count: int, is_player: bool) -> np.ndarray:
    """arena.mask.v1 -> bool[..., ACTION_LOGITS], True = available. `obs` is
    [..., >=13] (v1 or v2 layout; the channels used are shared)."""
    o = np.asarray(obs, dtype=np.float32)
    m = np.ones(o.shape[:-1] + (ACTION_LOGITS,), dtype=bool)
    m[..., 1] = o[..., 5] <= 0.0
    m[..., 2] = (o[..., 6] <= 0.0) if is_player else (o[..., 5] <= 0.0)
    for k in range(4):
        m[..., 3 + k] = (o[..., 7 + k] <= 0.0) if k < kit_count else False
    return m


def dodge_allowed(obs) -> np.ndarray:
    """The dodge FLAG's mask: a charge must be visible. bool[...]."""
    return np.asarray(obs, dtype=np.float32)[..., 12] > 0.0


def mask_args(build_id: str) -> tuple[int, bool]:
    """(kit_count, is_player) of a build, as the sim sees them (make_spec)."""
    s = specs()[build_id]
    return min(len(s.get("kits", [])), 4), bool(s.get("is_player", False))


class _FighterSpec(ctypes.Structure):
    _fields_ = [
        ("max_hp", ctypes.c_float), ("damage", ctypes.c_float),
        ("move_speed", ctypes.c_float), ("attack_reach", ctypes.c_float),
        ("attack_cd", ctypes.c_float), ("body_radius", ctypes.c_float),
        ("special_cd", ctypes.c_float),
        ("is_player", ctypes.c_int32), ("is_ranged", ctypes.c_int32),
        ("dodge_max", ctypes.c_int32), ("kit_count", ctypes.c_int32),
        ("kit_id", ctypes.c_int32 * 4), ("kit_cd", ctypes.c_float * 4),
        ("kit_range", ctypes.c_float * 4), ("kit_field", ctypes.c_int32 * 4),
    ]


def _load_lib() -> ctypes.CDLL:
    if not _LIB_PATH.exists():
        raise FileNotFoundError(
            f"libdh-env.so missing — build it: cmake --build sim/build -j")
    lib = ctypes.CDLL(str(_LIB_PATH))
    lib.dh_env_create.restype = ctypes.c_void_p
    lib.dh_env_create.argtypes = [_FighterSpec, _FighterSpec, ctypes.c_int32,
                                  ctypes.c_uint64]
    lib.dh_env_create_squad.restype = ctypes.c_void_p
    lib.dh_env_create_squad.argtypes = [_FighterSpec, _FighterSpec, _FighterSpec,
                                        _FighterSpec, ctypes.c_int32,
                                        ctypes.c_uint64]
    lib.dh_env_obs_dim.restype = ctypes.c_int32
    lib.dh_env_obs_dim.argtypes = [ctypes.c_void_p]
    if hasattr(lib, "dh_env_set_opp_policy"):
        lib.dh_env_set_opp_policy.restype = ctypes.c_int32
        lib.dh_env_set_opp_policy.argtypes = [ctypes.c_void_p, ctypes.c_int32]
    if hasattr(lib, "dh_env_set_body_traits"):
        lib.dh_env_set_body_traits.restype = ctypes.c_int32
        lib.dh_env_set_body_traits.argtypes = [ctypes.c_void_p, ctypes.c_int32,
                                               ctypes.c_int32, ctypes.c_float]
    if hasattr(lib, "dh_env_set_body_affix"):
        lib.dh_env_set_body_affix.restype = ctypes.c_int32
        lib.dh_env_set_body_affix.argtypes = [ctypes.c_void_p, ctypes.c_int32,
                                              ctypes.c_int32]
    lib.dh_env_reset.argtypes = [ctypes.c_void_p, ctypes.c_uint64,
                                 ctypes.POINTER(ctypes.c_float)]
    lib.dh_env_step.restype = ctypes.c_int
    lib.dh_env_step.argtypes = [ctypes.c_void_p, ctypes.c_float, ctypes.c_float,
                                ctypes.c_int32, ctypes.POINTER(ctypes.c_float)]
    lib.dh_env_winner.restype = ctypes.c_int
    lib.dh_env_winner.argtypes = [ctypes.c_void_p]
    lib.dh_env_hp_frac.restype = ctypes.c_float
    lib.dh_env_hp_frac.argtypes = [ctypes.c_void_p, ctypes.c_int32]
    # Raw per-episode damage tally (2026-09-14), the twin of the Godot arena's
    # dmg_taken_a/dmg_taken_b. Optional for the same reason as the acts entry
    # point below: a library built before it exists should say so out loud
    # rather than have ctypes read an undeclared return register.
    if hasattr(lib, "dh_env_damage_taken"):
        lib.dh_env_damage_taken.restype = ctypes.c_float
        lib.dh_env_damage_taken.argtypes = [ctypes.c_void_p, ctypes.c_int32]
    if hasattr(lib, "dh_env_damage_by_source"):
        lib.dh_env_damage_by_source.restype = ctypes.c_float
        lib.dh_env_damage_by_source.argtypes = [ctypes.c_void_p, ctypes.c_int32,
                                                ctypes.c_int32]
    # The dodge bit (2026-09-14). Same optional-symbol discipline: a library
    # that predates it would DROP the flag, and a dropped dodge is invisible in
    # every metric the trainer prints.
    if hasattr(lib, "dh_env_action_dodge_bit"):
        lib.dh_env_action_dodge_bit.restype = ctypes.c_int32
        lib.dh_env_action_dodge_bit.argtypes = []
    if hasattr(lib, "dh_env_tick_hz"):
        lib.dh_env_tick_hz.restype = ctypes.c_float
        lib.dh_env_tick_hz.argtypes = []
    lib.dh_env_tick.restype = ctypes.c_uint64
    lib.dh_env_tick.argtypes = [ctypes.c_void_p]
    # arena.trace.v1 (R51) — optional on purpose, like every symbol added after
    # the first release of this header: a stale .so fails on the lookup instead
    # of handing back a buffer of noise that would replay as a match nobody ran.
    if hasattr(lib, "dh_env_trace_begin"):
        lib.dh_env_trace_begin.restype = ctypes.c_int32
        lib.dh_env_trace_begin.argtypes = [ctypes.c_void_p, ctypes.c_int32]
        lib.dh_env_trace_stride.restype = ctypes.c_int32
        lib.dh_env_trace_stride.argtypes = []
        lib.dh_env_trace_len.restype = ctypes.c_int32
        lib.dh_env_trace_len.argtypes = [ctypes.c_void_p]
        lib.dh_env_trace_read.restype = ctypes.c_int32
        lib.dh_env_trace_read.argtypes = [ctypes.c_void_p,
                                          ctypes.POINTER(ctypes.c_float),
                                          ctypes.c_int32]
    lib.dh_env_destroy.argtypes = [ctypes.c_void_p]
    # batched surface: one crossing per TICK instead of 3-4 per env per tick
    lib.dh_env_step_many.restype = ctypes.c_int32
    lib.dh_env_step_many.argtypes = [
        ctypes.POINTER(ctypes.c_void_p), ctypes.c_int32,
        ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_int32),
        ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_int32),
        ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_int32),
        ctypes.c_int32]
    # Same call plus the COMMITTED action per env. Optional symbol, same
    # discipline as the rest: a library without it would leave the commit array
    # untouched and every kit would read as refused.
    if hasattr(lib, "dh_env_step_many_commit"):
        lib.dh_env_step_many_commit.restype = ctypes.c_int32
        lib.dh_env_step_many_commit.argtypes = [
            ctypes.c_void_p, ctypes.c_int32, ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_int32), ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_int32), ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_int32), ctypes.POINTER(ctypes.c_int32),
            ctypes.c_int32]
    lib.dh_env_reset_many.argtypes = [
        ctypes.POINTER(ctypes.c_void_p), ctypes.c_int32,
        ctypes.POINTER(ctypes.c_uint64), ctypes.POINTER(ctypes.c_float)]
    lib.dh_env_shutdown_pool.argtypes = []
    # The frozen self-play opponent. Two entry points: the original (tanh hidden,
    # linear head) and the one that takes per-layer activation codes, which only
    # exists in a library built after 2026-09-13. Declaring argtypes for it is how
    # a stale .so announces itself — an AttributeError here beats a self-play
    # opponent that silently ran the wrong activation for a million steps.
    _opp_args = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_float),
                 ctypes.POINTER(ctypes.c_int32), ctypes.POINTER(ctypes.c_int32),
                 ctypes.c_int32, ctypes.POINTER(ctypes.c_float)]
    lib.dh_env_set_opp_weights.argtypes = _opp_args
    if hasattr(lib, "dh_env_set_opp_weights_acts"):
        lib.dh_env_set_opp_weights_acts.argtypes = \
            _opp_args + [ctypes.POINTER(ctypes.c_int32)]
    return lib


def set_opp_weights(handle: int, params, layer_in, layer_out, emb, acts=None) -> bool:
    """Hand a frozen net to one env's opponent slot. Returns True if the per-layer
    activations went with it; False means the library predates them and the
    opponent will run tanh hidden / linear head whatever `acts` says — which is
    correct for every tanh net and WRONG for anything else, so callers warn."""
    l = lib()
    args = [ctypes.c_void_p(handle),
            params.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),
            layer_in.ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
            layer_out.ctypes.data_as(ctypes.POINTER(ctypes.c_int32)),
            len(layer_in),
            emb.ctypes.data_as(ctypes.POINTER(ctypes.c_float))]
    if acts is not None and hasattr(l, "dh_env_set_opp_weights_acts"):
        l.dh_env_set_opp_weights_acts(
            *args, acts.ctypes.data_as(ctypes.POINTER(ctypes.c_int32)))
        return True
    l.dh_env_set_opp_weights(*args)
    return acts is None


# Dodge is a separate head output, not an eighth action (policy_net.py::act
# returns move, pick, dodge). OR this into the action int to say "this pick,
# and dodge if the pick is refused" — the rule game/arena/neural_policy.gd has
# always used. `act & 7` remains the pick; 0..7 keep their old meanings.
ACT_DODGE = 8


def encode_act(pick, dodge):
    """(pick, dodge) -> the action int dh-env takes. Works on scalars and on
    numpy arrays, so the batched rollout does not need a second code path."""
    return pick + ACT_DODGE * np.asarray(dodge).astype(np.int32)


def tick_hz() -> float:
    """Sim ticks per second, from the sim itself — never a copy.

    env_parity.py held its own 30 against the sim's 60 and reported every dh-env
    episode at twice its length, which made a 2x duration divergence read as a
    perfect match. A constant that has to agree with C is a constant that will
    eventually disagree with C.
    """
    fn = getattr(lib(), "dh_env_tick_hz", None)
    if fn is None:
        raise RuntimeError(
            "libdh-env.so predates dh_env_tick_hz — rebuild it: "
            "cmake --build sim/build --target dh-env")
    return float(fn())


def supports_opp_switch() -> bool:
    """False on a library built before the opponent could be switched mid-run,
    in which case a curriculum would never leave its first phase."""
    return getattr(lib(), "dh_env_set_opp_policy", None) is not None


def supports_dodge_flag() -> bool:
    """False on a library built before the flag existed — in which case the bit
    is silently dropped and the policy never dodges. Check it rather than
    assume: the whole reason this bug survived was that nothing announced it."""
    fn = getattr(lib(), "dh_env_action_dodge_bit", None)
    return fn is not None and int(fn()) == ACT_DODGE


_LIB = None


def lib() -> ctypes.CDLL:
    global _LIB
    if _LIB is None:
        _LIB = _load_lib()
    return _LIB


def specs() -> dict:
    return json.load(open(_SPECS_PATH))["builds"]


def make_spec(build_id: str) -> _FighterSpec:
    s = specs()[build_id]
    out = _FighterSpec()
    out.max_hp = s["max_hp"]
    out.damage = s["damage"]
    out.move_speed = s["move_speed"]
    out.attack_reach = s["attack_reach"]
    out.attack_cd = s["attack_cd"]
    out.body_radius = s["body_radius"]
    out.special_cd = s.get("special_cd", 6.0)
    out.is_player = int(s.get("is_player", False))
    out.is_ranged = int(s.get("is_ranged", False))
    out.dodge_max = s.get("dodge_max", 0)
    kits = s.get("kits", [])[:4]
    out.kit_count = len(kits)
    for i, k in enumerate(kits):
        out.kit_id[i] = KIT_IDS[k["id"]]
        out.kit_cd[i] = k["cd"]
        out.kit_range[i] = k["range"]
        out.kit_field[i] = FIELD_KIND_IDS.get(k.get("kind", "fire"), 0)
    return out


def _power(spec: _FighterSpec) -> float:
    """Rough combat budget: EHP x DPS (what a fight actually trades in)."""
    return spec.max_hp * spec.damage / max(spec.attack_cd, 0.1)


def balance_specs(a: _FighterSpec, b: _FighterSpec) -> tuple[_FighterSpec,
                                                             _FighterSpec]:
    """Normalize BOTH fighters to the geometric-mean power budget (Ricardo:
    "do we balance stats to train in the arena? otherwise it's unfair").
    hp and damage scale by sqrt of the ratio, so EHP and DPS converge
    symmetrically and kits/mechanics — not raw stats — decide the fight.
    Mirror matchups are untouched (s == 1)."""
    import math
    pa, pb = _power(a), _power(b)
    if pa <= 0.0 or pb <= 0.0 or abs(pa - pb) < 1e-6:
        return a, b
    target = math.sqrt(pa * pb)
    for spec, p in ((a, pa), (b, pb)):
        s = math.sqrt(target / p)
        spec.max_hp *= s
        spec.damage *= s
    return a, b


class DhEnv:
    """One arena: learner (build_a) vs an internal-policy opponent (build_b).

    squad=(a_buddy, b_buddy) turns on 2v2 (arena.obs.v2, 36 floats): each side
    fields a second, autonomous melee body — pack tactics, ally field combos.
    """

    def __init__(self, build_a: str, build_b: str, opp: str = "native",
                 seed: int = 0, balance: bool = True,
                 squad: tuple[str, str] | None = None):
        # FIRST, before anything that can raise: __del__ runs on a half-built
        # object too, and `self._handle` missing there turns a clear error (a
        # bad build id out of make_spec) into a confusing AttributeError during
        # interpreter cleanup that hides the one you actually need to read.
        self._handle = None
        self.build_a, self.build_b = build_a, build_b
        # what the opponent's MIND is right now ("native"/"scripted"/"mlp");
        # set_opp keeps it current so a trainer can read back its own curriculum
        self.opp = opp
        sa, sb = make_spec(build_a), make_spec(build_b)
        if balance:
            sa, sb = balance_specs(sa, sb)
        if squad is None:
            self._handle = lib().dh_env_create(sa, sb, OPP[opp], seed)
        else:
            sa2, sb2 = make_spec(squad[0]), make_spec(squad[1])
            if balance:
                sa2, sb2 = balance_specs(sa2, sb2)
            self._handle = lib().dh_env_create_squad(sa, sa2, sb, sb2,
                                                     OPP[opp], seed)
        if not self._handle:
            raise RuntimeError("dh_env_create failed")
        # R55 (2026-09-19): the swing shape creature.gd gives each body through
        # its bestiary archetype (windup_time + pounce/slam), dumped next to the
        # stats. An optional symbol on purpose (dh_env.h): a library too old to
        # have it would fight every body with the stalker swing again — exactly
        # the divergence R55 closed — so refuse loudly rather than train on it.
        traits = getattr(lib(), "dh_env_set_body_traits", None)
        if traits is None:
            raise RuntimeError(
                "libdh-env.so predates dh_env_set_body_traits — rebuild it: "
                "cmake --build sim/build --target dh-env")
        # R55-b: the Fiery elite affix rides the same optional-symbol seam. The
        # other three affixes are stat edits dump_specs.gd already read off the
        # body; Fiery is behaviour (half the swing again, as bolt damage), and
        # cinder_drake wears it — 25 of the 58 bolt damage the arena's native
        # drake dealt per 10 s was this packet, and dh-env had none of it.
        affix = getattr(lib(), "dh_env_set_body_affix", None)
        if affix is None:
            raise RuntimeError(
                "libdh-env.so predates dh_env_set_body_affix — rebuild it: "
                "cmake --build sim/build --target dh-env")
        for who, bid in ((0, build_a), (1, build_b)):
            sp = specs()[bid]
            arch = ARCHETYPES.get(str(sp.get("archetype", "stalker")), 0)
            traits(self._handle, who, arch, float(sp.get("windup_time", 0.0)))
            affix(self._handle, who, 1 if bool(sp.get("fiery", False)) else 0)
        self.obs_dim = lib().dh_env_obs_dim(self._handle)
        self._obs = (ctypes.c_float * self.obs_dim)()

    def reset(self, seed: int = 0) -> np.ndarray:
        lib().dh_env_reset(self._handle, seed, self._obs)
        return np.array(self._obs, dtype=np.float32)

    def step(self, move: tuple[float, float], act: int) -> tuple[bool, np.ndarray]:
        done = lib().dh_env_step(self._handle, float(move[0]), float(move[1]),
                                 int(act), self._obs)
        return bool(done), np.array(self._obs, dtype=np.float32)

    def set_opp(self, opp: str) -> bool:
        """Change the opponent's MIND mid-run — Ricardo's curriculum: "learn
        from scripts first and, once reliably wiining against it, self playing".

        Call it between episodes. Determinism is untouched: the opponent's
        policy is not arena state. Returns False if the library refused the
        switch ("mlp" with no weights handed over yet), and raises rather than
        pretending on a library too old to have the symbol — a curriculum that
        silently never promotes looks exactly like a policy that never learns.
        """
        if opp not in OPP:
            raise ValueError(f"dh_env: unknown opponent '{opp}' — {sorted(OPP)}")
        fn = getattr(lib(), "dh_env_set_opp_policy", None)
        if fn is None:
            raise AttributeError(
                "libdh-env predates dh_env_set_opp_policy: the opponent "
                "curriculum cannot switch and every phase would silently stay "
                "on the first one. Rebuild: cmake --build sim/build -j")
        ok = bool(fn(self._handle, OPP[opp]))
        if ok:
            self.opp = opp
        return ok

    @property
    def winner(self) -> int:
        return lib().dh_env_winner(self._handle)

    def hp_frac(self, who: int) -> float:
        return lib().dh_env_hp_frac(self._handle, who)

    def damage_taken(self, who: int) -> float:
        """Raw damage dealt TO `who` this episode (0 learner, 1 opponent).

        Read it BEFORE the reset that clears it. Raises on a library built
        before the symbol existed, rather than returning a plausible zero that
        would read as "nothing landed" in ml/eval/env_parity.py.
        """
        fn = getattr(lib(), "dh_env_damage_taken", None)
        if fn is None:
            raise RuntimeError(
                "libdh-env.so predates dh_env_damage_taken — rebuild it: "
                "cmake --build sim/build --target dh-env")
        return float(fn(self._handle, who))

    SOURCES = ("contact", "bolt", "field")

    def damage_by_source(self, who: int) -> dict[str, float]:
        """damage_taken(who) split by where the packet came from (R55):
        contact (swing / slam / pounce), bolt (projectile), field (ground). The
        three sum to damage_taken. The twin of the arena row's
        dmg_{contact,bolt,field}_{a,b}. Raises on a library without the symbol,
        for the same reason damage_taken does."""
        fn = getattr(lib(), "dh_env_damage_by_source", None)
        if fn is None:
            raise RuntimeError(
                "libdh-env.so predates dh_env_damage_by_source — rebuild it: "
                "cmake --build sim/build --target dh-env")
        return {name: float(fn(self._handle, who, i))
                for i, name in enumerate(self.SOURCES)}

    # ---- arena.trace.v1 (R51): making a headless match WATCHABLE -----------
    # dh-env has no renderer and must not grow one (sim/ never imports Godot).
    # So the sim hands out what it DID, one row per tick, and the Godot arena
    # replays it: game/arena/trace_policy.gd feeds the recorded commands into
    # real bodies while arena.gd draws these positions as ghosts on top. Where
    # ghost and body come apart is where the two runtimes disagree — the
    # instrument the parity work needs, which hp_frac alone could never be.

    TRACE_SIDE_FIELDS = 11
    # names in frame order, so a reader never indexes by a bare number
    TRACE_FIELDS = ("x", "y", "aim_x", "aim_y", "hp_frac", "windup_t",
                    "dodge_t", "commit", "move_x", "move_y", "act")

    def trace_begin(self, max_ticks: int) -> int:
        """Arm per-tick capture and record the CURRENT state as frame 0.

        One allocation here and none per tick, so a traced run is still a sim
        run. Capture STOPS at max_ticks rather than wrapping — a ring buffer
        would hand back a replay that starts in the middle of the fight. Pass
        max_ticks <= 0 to disarm. Returns the frame capacity.
        """
        fn = getattr(lib(), "dh_env_trace_begin", None)
        if fn is None:
            raise RuntimeError(
                "libdh-env.so predates dh_env_trace_begin — rebuild it: "
                "cmake --build sim/build --target dh-env")
        n = int(fn(self._handle, int(max_ticks)))
        self._trace_cap = n
        return n

    def trace_frames(self) -> np.ndarray:
        """Everything captured so far as (frames, stride) float32.

        Column 0 is the tick; columns 1..11 are side A's TRACE_FIELDS and
        12..22 side B's. Side B's command columns carry what the INTERNAL mind
        (native/scripted/mlp) chose — otherwise unobservable from outside, and
        "the opponent did something different" is the commonest parity bug.
        """
        l = lib()
        if not hasattr(l, "dh_env_trace_len"):
            raise RuntimeError(
                "libdh-env.so predates dh_env_trace_len — rebuild it: "
                "cmake --build sim/build --target dh-env")
        stride = int(l.dh_env_trace_stride())
        if stride != 1 + 2 * self.TRACE_SIDE_FIELDS:
            raise RuntimeError(
                f"arena.trace stride {stride} is not the "
                f"{1 + 2 * self.TRACE_SIDE_FIELDS} this build expects — the .so "
                "and ml/env/dh_env.py disagree about the frame layout")
        n = int(l.dh_env_trace_len(self._handle))
        if n <= 0:
            return np.zeros((0, stride), dtype=np.float32)
        buf = (ctypes.c_float * (n * stride))()
        got = int(l.dh_env_trace_read(self._handle, buf, n * stride))
        return np.array(buf[:got], dtype=np.float32).reshape(got // stride, stride)

    @property
    def tick(self) -> int:
        return lib().dh_env_tick(self._handle)

    @property
    def seconds(self) -> float:
        """Episode length in SIM seconds — the same quantity the Godot arena
        reports as `duration_s`, so the two are directly comparable."""
        return self.tick / tick_hz()

    def close(self) -> None:
        if self._handle:
            lib().dh_env_destroy(self._handle)
            self._handle = None

    def __del__(self):
        # getattr, not self.close(): __del__ can run before __init__ assigned
        # anything at all (an exception inside make_spec, an interpreter
        # already tearing down), and a raise in here is only ever noise on top
        # of the real traceback.
        if getattr(self, "_handle", None):
            self.close()


class VecDhEnv:
    """Many arenas stepped in ONE ctypes crossing (Ricardo, 2026-09-13:
    "A batched step across all environments... is roughly sixteen times of
    headroom sitting there. --> do it!").

    The old rollout crossed into C four times per env per tick (step, two
    hp_frac, winner) and paid Python loop overhead on top, which pinned PPO at
    ~32k steps/s against the 527k the sim alone sustains. Here the whole tick
    is one `dh_env_step_many` call writing into preallocated numpy buffers,
    optionally drained by a persistent C++ worker pool.

        vec = VecDhEnv([DhEnv(...) for _ in range(32)], threads=8)
        obs = vec.reset(seeds)
        obs, done, hp, winner = vec.step(moves, acts)   # moves (N,2), acts (N,)
        vec.reset_done(done_idx, seeds)                 # caller owns boundaries

    Buffers are REUSED between calls: copy anything you need to keep. Episodes
    are never auto-reset, so the terminal observation is still yours to read.
    """

    def __init__(self, envs: list["DhEnv"], threads: int = 1):
        if not envs:
            raise ValueError("VecDhEnv needs at least one env")
        dims = {e.obs_dim for e in envs}
        if len(dims) != 1:
            raise ValueError(f"mixed obs_dim in one VecDhEnv: {sorted(dims)}")
        self.envs = envs
        self.n = len(envs)
        self.obs_dim = envs[0].obs_dim
        self.threads = max(1, int(threads))
        self._handles = (ctypes.c_void_p * self.n)(*[e._handle for e in envs])
        self.obs = np.zeros((self.n, self.obs_dim), dtype=np.float32)
        self.done = np.zeros(self.n, dtype=np.int32)
        self.hp = np.zeros((self.n, 2), dtype=np.float32)
        self.winner = np.zeros(self.n, dtype=np.int32)
        # The action that actually COMMITTED this tick, per env, or -1 if the
        # chosen one was refused. Rewarding intent instead of effect is how a
        # policy learns to spam a kit it never casts (2026-09-14).
        self.commit = np.full(self.n, -1, dtype=np.int32)
        self._has_commit = hasattr(lib(), "dh_env_step_many_commit")
        self._moves = np.zeros((self.n, 2), dtype=np.float32)
        self._acts = np.zeros(self.n, dtype=np.int32)
        self._seeds = np.zeros(self.n, dtype=np.uint64)

    @staticmethod
    def _p(a, t):
        return a.ctypes.data_as(ctypes.POINTER(t))

    def reset(self, seeds) -> np.ndarray:
        self._seeds[:] = np.asarray(seeds, dtype=np.uint64)
        lib().dh_env_reset_many(self._handles, self.n,
                                self._p(self._seeds, ctypes.c_uint64),
                                self._p(self.obs, ctypes.c_float))
        return self.obs

    def step(self, moves, acts):
        """moves (N,2) float, acts (N,) int -> (obs, done, hp, winner) views.

        `self.commit` is filled alongside them: the action that actually took
        effect this tick, or -1 if it was refused. Read it rather than `acts`
        for anything that pays a bonus — `acts` is what the policy WANTED.
        """
        np.copyto(self._moves, np.asarray(moves, dtype=np.float32).reshape(self.n, 2))
        np.copyto(self._acts, np.asarray(acts, dtype=np.int32).reshape(self.n))
        args = [self._handles, self.n,
                self._p(self._moves, ctypes.c_float),
                self._p(self._acts, ctypes.c_int32),
                self._p(self.obs, ctypes.c_float),
                self._p(self.done, ctypes.c_int32),
                self._p(self.hp, ctypes.c_float),
                self._p(self.winner, ctypes.c_int32)]
        if self._has_commit:
            lib().dh_env_step_many_commit(
                *args, self._p(self.commit, ctypes.c_int32), self.threads)
        else:
            self.commit.fill(-1)
            lib().dh_env_step_many(*args, self.threads)
        return self.obs, self.done, self.hp, self.winner

    def reset_done(self, idx, seeds) -> None:
        """Reset just the finished envs; their rows in `obs` are refilled."""
        idx = np.asarray(idx, dtype=np.int64).ravel()
        if idx.size == 0:
            return
        handles = (ctypes.c_void_p * idx.size)(*[self.envs[i]._handle for i in idx])
        s = np.ascontiguousarray(np.asarray(seeds, dtype=np.uint64).ravel())
        buf = np.zeros((idx.size, self.obs_dim), dtype=np.float32)
        lib().dh_env_reset_many(handles, idx.size,
                                self._p(s, ctypes.c_uint64),
                                self._p(buf, ctypes.c_float))
        self.obs[idx] = buf

    def close(self) -> None:
        lib().dh_env_shutdown_pool()
