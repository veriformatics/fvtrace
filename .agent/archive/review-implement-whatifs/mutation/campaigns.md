# Mutation campaigns (scripts as run; each ran in a scratch copy of the tree, `.scratch/mut` or `.scratch/refs/…`)

## mutate-u3 → `mutate-u3.log`

```bash
set -uo pipefail
node tools/mutate.mjs Fvtrace/Request.lean --lines 1-90 --timeout 900
node tools/mutate.mjs Fvtrace/Evaluate.lean --lines 83-90,130-193,242-261 --timeout 900
node tools/mutate.mjs Fvtrace/Cli.lean --lines 159-160,400-407,420-422,438-440,649-657 --timeout 900 --test "lake test"
```

## mutate-u6 → `mutate-u6.log`

```bash
set -uo pipefail
node tools/mutate.mjs Fvtrace/Snapshot.lean --lines 73-74,77-77,90-116 --timeout 900
```

## mutate-u6b → `mutate-u6b.log`

```bash
set -uo pipefail
node tools/mutate.mjs Fvtrace/Server.lean --lines 33-40,132-133,137-153,155-181,184-185,190-190,208-209,217-217,227-228,230-230 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Session.lean --lines 58-59,65-65,69-75,80-81,96-114 --timeout 900 --test 'lake test'
```

## mutate-u7c → `mutate-u7c.log`

```bash
set -uo pipefail
cd .scratch/mut || exit 1
node tools/mutate.mjs Fvtrace/Json.lean --lines 108-112,116-119,126-126,157-167,287-288,304-337,350-364,366-375,377-382,385-385 --timeout 900 --test 'lake test'
```

## mutate-r4f5 → `mutate-r4f5.log`

```bash
set -uo pipefail
cd .scratch/mut || exit 1
node tools/mutate.mjs Fvtrace/Session.lean --lines 66-66 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Json.lean --lines 307-307,314-316 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Evaluate.lean --lines 78-78,148-148 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Server.lean --lines 88-88,102-103,223-223,231-231 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Export.lean --lines 28-28,32-32 --timeout 900 --test 'lake test'
```

## mutate-r4f5b → `mutate-r4f5b.log`

```bash
set -uo pipefail
cd .scratch/mut || exit 1
for f in Tests/Evaluate.lean Tests/Export.lean Tests/Server.lean; do
  cp $f .scratch/mut/$f
done
node tools/mutate.mjs Fvtrace/Evaluate.lean --lines 78-78,148-148 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Server.lean --lines 88-88,231-231 --timeout 900 --test 'lake test'
node tools/mutate.mjs Fvtrace/Export.lean --lines 32-32 --timeout 900 --test 'lake test'
```
