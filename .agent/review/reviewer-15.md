# reviewer-15 — C-server, Correctness

Target = `48bc51d`; frozen base `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Functional lens only; security observations → Register.

| row | target | verdict | basis |
|---|---|---|---|
| C-server | routes, methods, status codes, order | reviewer-15-F1 | Pure route suite 40/40; raw oversized declared bodies return 413 before specified 405/421/403/415. |
| C-server | /api/answer: answers = CLI bytes, view header, 409, 413, 415 | reviewer-15-F1, reviewer-15-F2 | Native parity: 6 request forms `cmp=0`; inclusive body cap + 409 view passed; oversized transport order + missing item-error view fail. |
| C-server | problem replies + 500 io | unknown | unknown |
| C-server | session cache + invalidation + launch evaluation | unknown | unknown |
| C-server | fixed headers, config ref, start/stop | unknown | unknown |
| C-server | serveCmd ↔ Server wiring | unknown | unknown |
| C-server | tests (Tests/Server, e2e access/proxy, harness teardown) | unknown | unknown |
