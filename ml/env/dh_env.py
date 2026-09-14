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

_ACT_NAMES = ["noop", "attack", "special", "skill1", "skill2", "skill3",
              "skill4", "dodge"]
ACT_NOOP, ACT_ATTACK, ACT_SPECIAL, ACT_DODGE = 0, 1, 2, 7


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
    lib.dh_env_destroy.argtypes = [ctypes.c_void_p]
    # batched surface: one crossing per TICK instead of 3-4 per env per tick
    lib.dh_env_step_many.restype = ctypes.c_int32
    lib.dh_env_step_many.argtypes = [
        ctypes.POINTER(ctypes.c_void_p), ctypes.c_int32,
        ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_int32),
        ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_int32),
        ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_int32),
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
        self.obs_dim = lib().dh_env_obs_dim(self._handle)
        self._obs = (ctypes.c_float * self.obs_dim)()

    def reset(self, seed: int = 0) -> np.ndarray:
        lib().dh_env_reset(self._handle, seed, self._obs)
        return np.array(self._obs, dtype=np.float32)

    def step(self, move: tuple[float, float], act: int) -> tuple[bool, np.ndarray]:
        done = lib().dh_env_step(self._handle, float(move[0]), float(move[1]),
                                 int(act), self._obs)
        return bool(done), np.array(self._obs, dtype=np.float32)

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
        """moves (N,2) float, acts (N,) int -> (obs, done, hp, winner) views."""
        np.copyto(self._moves, np.asarray(moves, dtype=np.float32).reshape(self.n, 2))
        np.copyto(self._acts, np.asarray(acts, dtype=np.int32).reshape(self.n))
        lib().dh_env_step_many(
            self._handles, self.n,
            self._p(self._moves, ctypes.c_float), self._p(self._acts, ctypes.c_int32),
            self._p(self.obs, ctypes.c_float), self._p(self.done, ctypes.c_int32),
            self._p(self.hp, ctypes.c_float), self._p(self.winner, ctypes.c_int32),
            self.threads)
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
