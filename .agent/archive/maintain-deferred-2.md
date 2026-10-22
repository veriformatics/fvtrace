# MAINTAIN — deferred rows, second sweep (closed)

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log)

- Queue empty at start (0c8bf91 routed its last row to IMPLEMENT); three finds → rows (fc908cf)
- [ ] update automation (row 1): owed (user) = the Renovate app install; the row stays in `.agent/deferred.md`
- [x] e155e74 secret scanning + push protection (row 2; user approval): enabled, read back
- [x] 20e9e70 private vulnerability reporting + `SECURITY.md` (row 3; user approval): enabled, read back
- [x] close: rules upkeep (ops.md probe list → the script), temp cleanup, full gate on a clean tree; closed by the commit that adds this file
