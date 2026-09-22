# reference_repos/ — third-party code we read, never ship

A landing zone for **external repositories checked out for reference**: read to
learn an approach or adapt behind one of our seams, never imported, never built
as part of Dragon Heroes, never a dependency.

Nothing lives here yet. It exists because the alternative is a clone dropped at
the repo root, where it looks like ours.

## Rules

1. **Read-only.** Code moves out of here by being *reimplemented* behind an
   existing interface, not by being wired in. Nothing under `sim/`, `game/`,
   `genforge/` or `backend/` may import from this tree.
2. **Never committed.** Each checkout is somebody else's repository under
   somebody else's licence, so it stays untracked (`.gitignore` below). Only
   this README is tracked.
3. **Licences are checked before anything is adapted**, and the origin is
   recorded where the adaptation lands.

## Expected first tenant

The local image-generation repo Ricardo is bringing in (roadmap 13b). It gets
**adapted behind the `ImageBackend` seam** in
`genforge/pipeline/image_backend.py` — not rebuilt from nothing, and not made a
runtime dependency of GenForge.
