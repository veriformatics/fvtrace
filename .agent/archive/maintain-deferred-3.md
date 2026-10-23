# MAINTAIN — deferred rows, third sweep (closed)

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log; paused at 5dcacb4, resumed after the template refresh 489df40)

- [ ] update automation (row 1): ecd8e6b `renovate.json` re-validated (Renovate 44.176.3 `--strict`, RE2); the install form, closed by a Neo restart, resubmitted with the approved scope; GitHub's "Confirm access" awaits the user's code → owed (user), the row stays in `.agent/deferred.md`
- [x] 6a73af1 GUI copy names the engine (row 2): `web/index.html` experiments sentence → the user's wording
- [x] cd69935 page engine on macOS + Windows (row 3): portability jobs green on 0526dbc (run 39769654379)
- [x] 10a8c87 what-if messages (new row, user wording): `Overrides.parse` messages, rejected token first
- [x] 752ee38 + 27787a1 e2e under host load (find): measured; user ruling = default limit 90 s + `smoke` 300 s; `tools/e2e-load.sh`; 3 gates on nixbox at ≥ 1.5× load
- [x] 0182781 CI engine-build cache (template-refresh find): every job that builds; reviewer-1 F1–F4 fixed; its scheduled-run check waits on its trigger (deferred row)
- [x] 8f9c4e6 Version.lean comment (template-refresh find)
- [x] close: rules upkeep (ops.md's CI cache detail → wasm.md, which now loads for `gate.yml`), scratch + temp cleanup, full gate on a clean tree; closed by the commit that adds this file
