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
    lib.dh_env_tick.restype = ctypes.c_uint64
    lib.dh_env_tick.argtypes = [ctypes.c_void_p]
    lib.dh_env_destroy.argtypes = [ctypes.c_void_p]
    return lib


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

    @property
    def tick(self) -> int:
        return lib().dh_env_tick(self._handle)

    def close(self) -> None:
        if self._handle:
            lib().dh_env_destroy(self._handle)
            self._handle = None

    def __del__(self):
        self.close()
