# genforge/service — v0 implemented (stub provider)

`app.py` is the v0 FastAPI service: `POST /generate/creature` runs the
parts-sheet → skeleton → baked-frames pipeline (`../pipeline/`) behind the
procedural stub provider and writes candidate bundles (parts sheet + baked
strips + atlas + `provenance.json`) **only** under `../candidates/`.

```bash
uvicorn genforge.service.app:app --reload    # from the repo root
```

The full API contract lives in [docs/tech/28-generation-service.md](../../docs/tech/28-generation-service.md);
the roadmap (docs/business/31) phases in the rest: text-gen JSON candidates
assisting the internal weekly rehearsal (M2–M3), style-locked image models
replacing the stub after the art-pipeline test (M4, per docs/design/17 §5),
full weekly-runbook integration with curation gates (M5+). v0 is synchronous;
real image jobs move to the async 202 + job-poll flow of docs/tech/28 §5.

Internal network only — GenForge never talks to game servers or clients.
