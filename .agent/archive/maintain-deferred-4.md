# MAINTAIN — deferred rows, fourth sweep (closed; row 8 routed)

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log)

User rulings: row 8 → references, its own IMPLEMENT session (`.agent/route.md`); the hosted plan sells compute past the local limits (spec Decisions, Product).

| row | commit | outcome |
|---|---|---|
| 1 reviewed export runs no what-if | 523f108 (CI 40065957296) | root cause: Lean 4.35's runtime ends `String.toList` in `lean_box_uint32(0)` (a heap object on wasm32), so `String.ofList` read past `Decode.validDate`'s digits → patch: `List.nil` = `lean_box(0)`; review-record differential + e2e red → green; standard-error check + probe `engine-panic`; reviewer-24: 6/6 pass (`maintain-deferred-4/reviewer-24.md`) |
| 2 update automation | 80c0fed | installed (174717623; the user's sudo code on the resubmitted form); waits on Renovate's first run (Dependency Dashboard issue) |
| 3 CI cache, weekly run | — | waits on its trigger: the first scheduled run, Mon 2026-10-26 06:17Z |
| 4 npm release-age holds | 1c21716 | fast-uri entry pruned (b80974e entered it); the rest eligible 10-25 … 10-29 |
| 5 Emscripten 6.0.13 | — | waits: eligible 10-26 |
| 6 Actions | — | waits: eligible 10-28 / 10-29 |
| 7 libuv headers | — | waits: a Lean release naming a newer libuv tag (4.36.0 unreleased) |
| 8 output-quadratic envelopes | close commit | routed: IMPLEMENT — what-ifs by reference (measurements in `route.md`) |
| find: build-cache temporary | 1e8a17d · 544a422 (CI 40070402375) | `writeAtomic` removes its temporary when the write fails |
| close | close commit | rules upkeep (`wasm.md`: patch + cache-key bullets); scratch cleanup; full gate on CI |
