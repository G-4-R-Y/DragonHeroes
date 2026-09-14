"""Teacher -> student distillation (Ricardo, 2026-09-13: "train bigger models and
use them to distill smaller ones, as to use the smaller nets in the actual games
and the big ones to act as their teachers once they surpass the default
script/engine behaviour!").

A wide net cannot ship. The numbers are the whole argument: the shipping net is
47->64->64->10 = 7,744 MACs, ~105 us/tick in C++, and one forward runs per agent
per physics tick against a 16,670 us frame. A 256x256 teacher is 80,128 MACs,
~1.09 ms — fifteen of those eat a whole 60 FPS frame. So the teacher trains, and
then it teaches; the 64x64 student is what the game loads.

    # 1. train a teacher (PPO on the GPU is the one that can actually use width)
    ml/.venv/bin/python -m ml.training.ppo --key fen_boar_alpha \
        --build core.arena.fen_boar_alpha --opp-build core.arena.gloamfen_stalker \
        --net relu-wide --steps 2000000       # python3 -m ml.training.arch lists them

    # 2. distill it (this module): qualify -> collect -> fit -> gate
    python3 -m ml.training.distill --key fen_boar_alpha \
        --build core.arena.fen_boar_alpha --teacher fen_boar_alpha@candidate
        # the student is --net default unless you say otherwise; a relu-wide
        # teacher can perfectly well teach a tanh 64x64 student.

THE QUALIFYING GATE IS RICARDO'S CONDITION, MADE EXECUTABLE
"once they surpass the default script/engine behaviour". A teacher that cannot
beat the built-in AI has nothing to teach, and distilling from it would actively
make the student worse than the scripted fallback it replaces. So before a single
observation is collected, the teacher plays `versus` against BOTH baselines in
the real Godot arena and must win both by --qualify-margin. It does not qualify,
nothing is distilled, exit 1.

HOW THE STUDENT LEARNS — DAgger, not plain behaviour cloning
Round 0 rolls out with the TEACHER acting. Every later round rolls out with the
STUDENT acting and the teacher labelling what it would have done. That matters:
a student trained only on states the teacher visits never sees the states its own
early mistakes lead to, and compounding error is the classic failure of naive
cloning. Rollouts run in libdh-env (the C++ arena twin, the same environment PPO
trains in), batched, so a round of 200k samples takes seconds.

The loss is standard knowledge distillation, matched to what the runtime actually
reads from the head:
    move   (2)  MSE                  — a continuous command, copied directly
    action (7)  soft cross-entropy at --temperature, scaled by T^2
    dodge  (1)  BCE against sigmoid(teacher)
The action head is argmaxed by the runtime, so matching the teacher's *ranking*
matters more than its magnitudes — which is exactly what softening with T does.

The embedding row is COPIED from the teacher and frozen: it is content identity
(canon §9 §5), not behaviour, and the student inherits the same content keying.

WHAT IT WRITES
    the student, registered as a normal candidate for <key> (it gates like any
    other net, and it is the one that deploys)
    ml/data/benchmarks/<stamp>__distill__<key>.json   schema arena.distill.v1
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ml.training import league                                          # noqa: E402
from ml.training.policy_net import (ACTION_LOGITS, EMB_DIM, HEAD_DIM,   # noqa: E402
                                    OBS_DIM, PolicyNet, macs, parse_hidden)
from ml.training import arch as arch_mod                                # noqa: E402
from ml.training.arch import (Arch, activation_grad,                    # noqa: E402
                              apply_activation, normalize_act)

BENCH_DIR = league.BENCH_DIR


# ---- the teacher as a batched numpy net ---------------------------------------------


class TeacherNet:
    """Any arena.policy.v1 JSON, forwarded in batches. Shape-agnostic on purpose:
    a teacher can be 256x256 from PPO or 64x64 from ES, and this does not care."""

    def __init__(self, path: str | Path):
        doc = json.loads(Path(path).read_text())
        if doc.get("schema") != "arena.policy.v1":
            raise SystemExit(f"distill: {path} is not an arena.policy.v1 net")
        if int(doc.get("obs_dim", 0)) != OBS_DIM:
            raise SystemExit(f"distill: {path} has obs_dim {doc.get('obs_dim')} != {OBS_DIM}")
        self.path = str(path)
        self.w = [np.asarray(l["w"], dtype=np.float64) for l in doc["layers"]]
        self.b = [np.asarray(l["b"], dtype=np.float64) for l in doc["layers"]]
        # Whatever the teacher was trained with. normalize_act also accepts the
        # old "logits" name PPO's folded head used; an activation neither we nor
        # the arena knows is refused, because distilling from a net we forward
        # WRONG would teach the student the wrong function perfectly.
        try:
            self.acts = [normalize_act(l.get("act", "tanh")) for l in doc["layers"]]
        except ValueError as e:
            raise SystemExit(f"distill: {path}: {e}")
        self.embeddings = {k: np.asarray(v, dtype=np.float64)
                           for k, v in doc.get("embeddings", {}).items()}
        self.hidden = tuple(int(x.shape[0]) for x in self.w[:-1])
        self.activation = self.acts[0] if len(self.acts) > 1 else "linear"

    def embedding(self, key: str) -> np.ndarray:
        row = self.embeddings.get(key, self.embeddings.get("*"))
        if row is None:
            raise SystemExit(f"distill: teacher {self.path} has no embedding for "
                             f"'{key}' and no '*' row")
        return row

    def forward(self, x: np.ndarray) -> np.ndarray:
        for w, b, a in zip(self.w, self.b, self.acts):
            x = apply_activation(x @ w.T + b, a)
        return x


# ---- the student -------------------------------------------------------------------


class Student:
    """The shipping-shaped net, trained by gradient descent instead of ES. Same
    MLP as PolicyNet — this holds it as batched float64 arrays so a training step
    is a handful of matmuls, then hands the weights back to a PolicyNet for export
    (which is what guarantees the runtime reads the same file as always).

    The student's architecture is its OWN (`arch`), independent of the teacher's:
    that is the entire point — a 256x256 relu teacher distilled into whatever
    shape the game can actually afford."""

    def __init__(self, hidden: tuple[int, ...], seed: int = 0,
                 arch: Arch | None = None):
        rng = np.random.default_rng(seed)
        sizes = [OBS_DIM + EMB_DIM, *hidden, HEAD_DIM]
        self.hidden = hidden
        self.arch = arch or Arch(hidden=tuple(hidden))
        self.acts = self.arch.layer_acts(len(sizes) - 1)
        # He init regardless of activation: this is supervised regression onto a
        # teacher, not a fresh search, and the deep-net variance argument holds
        # for tanh here too. (The Arch's init governs FROM-SCRATCH nets — ES/PPO.)
        self.w = [rng.normal(0, np.sqrt(2.0 / sizes[i]), (sizes[i + 1], sizes[i]))
                  for i in range(len(sizes) - 1)]
        self.b = [np.zeros(sizes[i + 1]) for i in range(len(sizes) - 1)]
        self.m = [np.zeros_like(p) for p in self.w + self.b]
        self.v = [np.zeros_like(p) for p in self.w + self.b]
        self.t = 0

    def forward(self, x: np.ndarray) -> tuple[np.ndarray, list[np.ndarray]]:
        acts = [x]
        for (w, b, a) in zip(self.w, self.b, self.acts):
            acts.append(apply_activation(acts[-1] @ w.T + b, a))
        return acts[-1], acts

    def backward(self, acts: list[np.ndarray], dy: np.ndarray,
                 lr: float, beta1=0.9, beta2=0.999, eps=1e-8) -> None:
        grads_w, grads_b = [None] * len(self.w), [None] * len(self.b)
        d = dy
        for i in range(len(self.w) - 1, -1, -1):
            grads_w[i] = d.T @ acts[i]
            grads_b[i] = d.sum(axis=0)
            if i > 0:
                # acts[i] is POST-activation of layer i-1, which is what
                # activation_grad wants (tanh' = 1-y^2, relu' = y>0).
                d = (d @ self.w[i]) * activation_grad(acts[i], self.acts[i - 1])
        self.t += 1
        params = self.w + self.b
        grads = grads_w + grads_b
        for j, (p, g) in enumerate(zip(params, grads)):
            self.m[j] = beta1 * self.m[j] + (1 - beta1) * g
            self.v[j] = beta2 * self.v[j] + (1 - beta2) * (g * g)
            mh = self.m[j] / (1 - beta1 ** self.t)
            vh = self.v[j] / (1 - beta2 ** self.t)
            p -= lr * mh / (np.sqrt(vh) + eps)

    def to_policy_net(self, embeddings: dict[str, np.ndarray]) -> PolicyNet:
        net = PolicyNet(arch=self.arch)
        net.weights = [w.astype(np.float32) for w in self.w]
        net.biases = [b.astype(np.float32) for b in self.b]
        net.embeddings = {k: v.astype(np.float32) for k, v in embeddings.items()}
        return net


def softmax(z: np.ndarray, axis: int = -1) -> np.ndarray:
    z = z - z.max(axis=axis, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=axis, keepdims=True)


def kd_loss_and_grad(student_y: np.ndarray, teacher_y: np.ndarray, temperature: float,
                     w_move: float, w_act: float, w_dodge: float
                     ) -> tuple[dict[str, float], np.ndarray]:
    """Head layout: [move_x, move_y, logit x ACTION_LOGITS, dodge_logit]."""
    n = max(len(student_y), 1)
    d = np.zeros_like(student_y)
    a = 2 + ACTION_LOGITS

    # Every term is a MEAN, so every gradient carries the same 1/n — and the move
    # term's mean is over n*2 elements, which is where its 2 cancels.
    diff = student_y[:, :2] - teacher_y[:, :2]
    move = float(np.mean(diff ** 2))
    d[:, :2] = w_move * diff / n

    t = max(float(temperature), 1e-6)
    p = softmax(teacher_y[:, 2:a] / t)
    q = softmax(student_y[:, 2:a] / t)
    act = float(-np.mean(np.sum(p * np.log(q + 1e-12), axis=1)))
    d[:, 2:a] = w_act * (t * (q - p)) / n          # T^2 * dCE/dz, dz/dlogit = 1/T

    pt = 1.0 / (1.0 + np.exp(-teacher_y[:, a]))
    qs = 1.0 / (1.0 + np.exp(-student_y[:, a]))
    dodge = float(-np.mean(pt * np.log(qs + 1e-12) + (1 - pt) * np.log(1 - qs + 1e-12)))
    d[:, a] = w_dodge * (qs - pt) / n

    agree = float(np.mean(np.argmax(student_y[:, 2:a], axis=1)
                          == np.argmax(teacher_y[:, 2:a], axis=1)))
    return {"move_mse": move, "action_ce": act, "dodge_bce": dodge,
            "action_agreement": agree}, d


# ---- step 1: does the teacher surpass the default behaviour? -------------------------


def qualify(teacher_spec: str, build: str, best_of: int, episodes: int, seed: int,
            jobs: int, speed: str, margin: float,
            progress: league.Progress) -> dict:
    """Ricardo's condition. Both baselines, in the real arena, or no distillation."""
    rows = {}
    for baseline in ("native", "scripted"):
        v = league.versus(teacher_spec, baseline, build, build, best_of, episodes,
                          seed, jobs, speed, label=f"qualify {teacher_spec} vs {baseline}",
                          progress=progress)
        beat = v["winner"] == "a" and v["episode_win_rate_a"] >= margin
        rows[baseline] = {"rounds": f"{v['rounds_a']}-{v['rounds_b']}",
                          "episode_win_rate": v["episode_win_rate_a"],
                          "passed": bool(beat), "out": v["out"]}
        print(f"[distill] qualify vs {baseline}: {v['rounds_a']}-{v['rounds_b']} "
              f"(episode win rate {v['episode_win_rate_a']:.3f}, need > {margin}) "
              f"-> {'PASS' if beat else 'FAIL'}", flush=True)
    ok = all(r["passed"] for r in rows.values())
    progress.emit("distill_qualify", passed=ok, **{k: v["episode_win_rate"]
                                                   for k, v in rows.items()})
    return {"passed": ok, "margin": margin, "checks": rows}


# ---- step 2: collect (obs, what the teacher would do) --------------------------------


def collect(teacher: TeacherNet, student: Student | None, emb: np.ndarray,
            build: str, opp_build: str, opp: str, envs: int, steps: int,
            seed: int, threads: int) -> tuple[np.ndarray, np.ndarray, float]:
    """One DAgger round. `student is None` -> the TEACHER drives (round 0);
    otherwise the STUDENT drives and the teacher only labels, so the samples come
    from the distribution the student will actually be in."""
    from ml.env.dh_env import DhEnv, VecDhEnv
    vec = VecDhEnv([DhEnv(build, opp_build, opp=opp, seed=seed + i)
                    for i in range(envs)], threads=threads)
    rng = np.random.default_rng(seed)
    obs = vec.reset(np.arange(envs, dtype=np.uint64) + seed)
    xs = np.empty((steps, OBS_DIM + EMB_DIM))
    ys = np.empty((steps, HEAD_DIM))
    emb_tile = np.tile(emb, (envs, 1))
    wins, ends, got = 0, 0, 0
    t0 = time.monotonic()
    try:
        while got < steps:
            x = np.concatenate([obs.astype(np.float64), emb_tile], axis=1)
            ty = teacher.forward(x)
            take = min(envs, steps - got)
            xs[got:got + take] = x[:take]
            ys[got:got + take] = ty[:take]
            got += take
            drive = ty if student is None else student.forward(x)[0]
            moves = np.clip(drive[:, :2], -1.0, 1.0).astype(np.float32)
            acts = np.argmax(drive[:, 2:2 + ACTION_LOGITS], axis=1).astype(np.int32)
            obs, done, _hp, winner = vec.step(moves, acts)
            idx = np.flatnonzero(done)
            if idx.size:
                ends += idx.size
                wins += int(np.sum(winner[idx] == 0))
                vec.reset_done(idx, rng.integers(0, 2**63, idx.size, dtype=np.uint64))
                obs = vec.obs
    finally:
        for e in vec.envs:
            e.close()
    rate = got / max(time.monotonic() - t0, 1e-9)
    # 0 wins of 0 episodes is not a 0% win rate — with few samples no episode
    # finishes, and printing 0.00 would read as "the driver lost everything".
    wr = wins / ends if ends else float("nan")
    print(f"[distill] collected {got:,} samples "
          f"({'teacher' if student is None else 'student'} driving, "
          f"{ends} episodes, driver win rate "
          f"{'n/a — no episode finished' if ends == 0 else f'{wr:.2f}'}) "
          f"at {rate:,.0f}/s", flush=True)
    return xs, ys, wr


# ---- step 3: fit ---------------------------------------------------------------------


def fit(student: Student, xs: np.ndarray, ys: np.ndarray, epochs: int, batch: int,
        lr: float, temperature: float, weights: tuple[float, float, float],
        seed: int, progress: league.Progress) -> dict:
    rng = np.random.default_rng(seed)
    stats: dict = {}
    for ep in range(epochs):
        order = rng.permutation(len(xs))
        totals: dict[str, float] = {}
        n_batches = 0
        for i in range(0, len(order) - batch + 1, batch):
            sel = order[i:i + batch]
            y, acts = student.forward(xs[sel])
            parts, dy = kd_loss_and_grad(y, ys[sel], temperature, *weights)
            student.backward(acts, dy, lr)
            for k, v in parts.items():
                totals[k] = totals.get(k, 0.0) + v
            n_batches += 1
        stats = {k: round(v / max(n_batches, 1), 5) for k, v in totals.items()}
        print(f"[distill] epoch {ep + 1}/{epochs} " +
              "  ".join(f"{k}={v}" for k, v in stats.items()), flush=True)
        progress.emit("distill_epoch", epoch=ep + 1, epochs=epochs, **stats)
    return stats


# ---- the whole thing -----------------------------------------------------------------


def distill(key: str, build: str, teacher_spec: str, opp_build: str = "",
            hidden: str = "", arch: Arch | None = None,
            opp: str = "native", envs: int = 64,
            samples: int = 200_000, dagger_rounds: int = 3, epochs: int = 4,
            batch: int = 512, lr: float = 1e-3, temperature: float = 2.0,
            weights: tuple[float, float, float] = (1.0, 1.0, 0.5),
            qualify_best_of: int = 5, qualify_episodes: int = 2,
            qualify_margin: float = 0.55, skip_qualify: bool = False,
            seed: int = 2026, jobs: int = 1, speed: str = "max", threads: int = 1,
            do_gate: bool = True, gate_episodes: int = 4,
            out_path: Path | None = None,
            progress: league.Progress | None = None) -> dict:
    progress = progress or league.Progress(None)
    started, t0 = time.strftime("%Y-%m-%dT%H:%M:%S"), time.monotonic()
    opp_build = opp_build or build
    teacher_path, teacher_label = league.resolve_policy(teacher_spec)
    if teacher_path in ("native", "scripted"):
        raise SystemExit("distill: the teacher must be a net, not a baseline")
    teacher = TeacherNet(teacher_path)
    student_arch = arch or Arch()
    if hidden:
        student_arch = Arch.from_dict(
            {**student_arch.to_dict(), "hidden": list(parse_hidden(hidden))},
            name=student_arch.name)
    want = student_arch.hidden
    print(f"[distill] {key}: teacher {teacher_label} {list(teacher.hidden)} "
          f"{teacher.activation} ({macs(teacher.hidden):,} MACs) -> student "
          f"{list(want)} {student_arch.activation} ({macs(want):,} MACs), "
          f"{macs(teacher.hidden) / max(macs(want), 1):.1f}x smaller", flush=True)
    progress.emit("distill_start", key=key, build=build, teacher=teacher_label,
                  teacher_hidden=list(teacher.hidden), student_hidden=list(want))

    verdict: dict = {"schema": "arena.distill.v1", "started": started, "key": key,
                     "build": build, "opp_build": opp_build,
                     "teacher": {"spec": teacher_spec, "label": teacher_label,
                                 "path": teacher_path, "hidden": list(teacher.hidden),
                                 "activation": teacher.activation,
                                 "macs": macs(teacher.hidden)},
                     "student": {"hidden": list(want), "macs": macs(want),
                                 "arch": student_arch.to_dict()},
                     "rounds": []}

    # 1. the teacher must surpass the default behaviour
    if skip_qualify:
        verdict["qualify"] = {"passed": True, "skipped": True}
        print("[distill] --skip-qualify: distilling from an UNQUALIFIED teacher", flush=True)
    else:
        verdict["qualify"] = qualify(teacher_spec, build, qualify_best_of,
                                     qualify_episodes, seed, jobs, speed,
                                     qualify_margin, progress)
        if not verdict["qualify"]["passed"]:
            verdict["student"]["trained"] = False
            verdict["finished"] = time.strftime("%Y-%m-%dT%H:%M:%S")
            _write(verdict, out_path, key)
            print(f"[distill] {key}: the teacher does not surpass the default "
                  f"script/engine behaviour — nothing distilled", flush=True)
            progress.emit("distill_done", key=key, distilled=False,
                          reason="teacher did not qualify")
            return verdict

    # 2 + 3. DAgger: collect, fit, repeat with the student driving
    emb = teacher.embedding(key if key in teacher.embeddings else "*")
    student = Student(want, seed=seed, arch=student_arch)
    xs_all: list[np.ndarray] = []
    ys_all: list[np.ndarray] = []
    for r in range(max(1, dagger_rounds)):
        xs, ys, drive_wr = collect(teacher, None if r == 0 else student, emb, build,
                                   opp_build, opp, envs, samples, seed + r * 7919,
                                   threads)
        xs_all.append(xs)
        ys_all.append(ys)
        stats = fit(student, np.concatenate(xs_all), np.concatenate(ys_all),
                    epochs, batch, lr, temperature, weights, seed + r, progress)
        verdict["rounds"].append({"round": r, "driver": "teacher" if r == 0 else "student",
                                  "samples": int(sum(len(x) for x in xs_all)),
                                  "driver_win_rate": (None if drive_wr != drive_wr
                                                      else round(drive_wr, 4)), **stats})

    # 4. export + register as a normal candidate: the student gates like any net
    net = student.to_policy_net({(key if key in teacher.embeddings else "*"): emb})
    reg = league.load_registry()
    entry = league.registry_add(reg, key, "species", f"distilled:{teacher_label}")
    entry["eval"] = {"trainer": "distill", "teacher": teacher_label,
                     "teacher_hidden": list(teacher.hidden), "hidden": list(want)}
    league.save_net(net, entry)
    league.save_registry(reg)
    verdict["student"].update({"trained": True, "version": int(entry["version"]),
                               "game_json": entry["game_json"]})
    print(f"[distill] {key}: registered v{entry['version']} (student candidate)", flush=True)

    if do_gate:
        from ml.eval.gate import run_gate
        reg = league.load_registry()
        cand = next(p for p in reg["policies"]
                    if p["key"] == key and int(p["version"]) == int(entry["version"]))
        ok = bool(run_gate(reg, cand, build, gate_episodes))
        league.save_registry(reg)
        verdict["gate"] = {"passed": ok, "checks": cand.get("eval", {}).get("checks", {})}
        progress.emit("gate", **{"version": entry["version"], "pass": ok,
                                 "metrics": verdict["gate"]["checks"]})

    verdict["finished"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    verdict["wall_s"] = round(time.monotonic() - t0, 1)
    _write(verdict, out_path, key)
    progress.emit("distill_done", key=key, distilled=True,
                  version=entry["version"], out=verdict["out"])
    return verdict


def _write(verdict: dict, out_path: Path | None, key: str) -> None:
    if out_path is None:
        BENCH_DIR.mkdir(parents=True, exist_ok=True)
        out_path = BENCH_DIR / f"{time.strftime('%Y-%m-%d_%H%M%S')}__distill__{key}.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(verdict, indent=1))
    verdict["out"] = str(out_path)
    print(f"[distill] {out_path}", flush=True)


def main() -> int:
    ap = argparse.ArgumentParser(prog="ml.training.distill", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", required=True)
    ap.add_argument("--build", required=True)
    ap.add_argument("--teacher", required=True,
                    help="the wide net, in `league versus --a` syntax: a path, "
                         "<key>, <key>@v7, <key>@candidate")
    ap.add_argument("--opp-build", default="", help="who the rollouts fight (default: itself)")
    ap.add_argument("--opp", default="native", choices=["native", "scripted", "mlp"])
    # The STUDENT's architecture (the teacher's comes off its own file). Same
    # five flags as every other trainer — ml/training/arch.py.
    arch_mod.add_arguments(ap)
    ap.add_argument("--envs", type=int, default=64)
    ap.add_argument("--samples", type=int, default=200_000, help="per DAgger round")
    ap.add_argument("--dagger-rounds", type=int, default=3,
                    help="1 = plain behaviour cloning; more = the student's own states")
    ap.add_argument("--epochs", type=int, default=4)
    ap.add_argument("--batch", type=int, default=512)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--temperature", type=float, default=2.0)
    ap.add_argument("--w-move", type=float, default=1.0)
    ap.add_argument("--w-act", type=float, default=1.0)
    ap.add_argument("--w-dodge", type=float, default=0.5)
    ap.add_argument("--qualify-best-of", type=int, default=5)
    ap.add_argument("--qualify-episodes", type=int, default=2)
    ap.add_argument("--qualify-margin", type=float, default=0.55,
                    help="episode win rate the teacher must clear vs BOTH baselines")
    ap.add_argument("--skip-qualify", action="store_true",
                    help="distill from a teacher that has not beaten the baselines "
                         "(for experiments; it is the one check Ricardo asked for)")
    ap.add_argument("--no-gate", action="store_true")
    ap.add_argument("--gate-episodes", type=int, default=4)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--jobs", type=int, default=1, help="qualify matches in parallel")
    ap.add_argument("--speed", default=league.DEFAULT_SPEED)
    ap.add_argument("--threads", type=int, default=1, help="libdh-env worker threads")
    ap.add_argument("--out", default="")
    ap.add_argument("--progress-file", default=None)
    a = ap.parse_args()
    progress = league.Progress(a.progress_file or league.progress_path(a.key))
    with progress.guard():
        v = distill(a.key, a.build, a.teacher, opp_build=a.opp_build,
                    arch=arch_mod.from_args(a),
                    opp=a.opp, envs=a.envs, samples=a.samples,
                    dagger_rounds=a.dagger_rounds, epochs=a.epochs, batch=a.batch,
                    lr=a.lr, temperature=a.temperature,
                    weights=(a.w_move, a.w_act, a.w_dodge),
                    qualify_best_of=a.qualify_best_of,
                    qualify_episodes=a.qualify_episodes,
                    qualify_margin=a.qualify_margin, skip_qualify=a.skip_qualify,
                    seed=a.seed, jobs=a.jobs, speed=a.speed, threads=a.threads,
                    do_gate=not a.no_gate, gate_episodes=a.gate_episodes,
                    out_path=Path(a.out) if a.out else None, progress=progress)
    return 0 if v["student"].get("trained") else 1


if __name__ == "__main__":
    raise SystemExit(main())
