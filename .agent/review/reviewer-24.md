| row | target | verdict | basis |
|---|---|---|---|
| C-release | gate.yml (matrix, shards, triggers, cache, permissions) | pass | STAGES = checks/e2e/lean; one shard step; required build/Python/Node tools; weekly cache bypass + pin/toolchain/runtime/build-tool key; read-only permissions + SHA pins; actionlint rc 0; five fanout controls fired. |
| C-release | build.yml (platforms, cache, package, check) | unknown | unknown |
| C-release | release.yml (refusals, attestation, publish, installed, re-check, dry run) | unknown | unknown |
| C-release | codeql.yml | unknown | unknown |
| C-release | tools/release.sh + NOTICES + libuv.txt | unknown | unknown |
| C-release | renovate.json + tests/renovate | unknown | unknown |
| C-release | README Install ↔ release.sh floors + archive names | unknown | unknown |
