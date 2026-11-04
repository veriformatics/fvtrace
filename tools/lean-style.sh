#!/usr/bin/env bash
# Layout rules for tracked Lean sources (the 4.35 toolchain ships no formatter): no tabs, no
# trailing whitespace, lines ≤ 100 characters, final newline. Prints `file:line: rule` per finding.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1

mapfile -t files < <(git ls-files -co --exclude-standard -- '*.lean')
# An empty selection (a moved tree, a broken pattern) would read as clean.
[[ ${#files[@]} -gt 0 ]] || { printf 'lean-style: no Lean file selected\n' >&2; exit 1; }
rc=0
for f in "${files[@]}"; do
    LC_ALL=C.UTF-8 awk -v f="$f" '
        /\t/ { printf "%s:%d: tab\n", f, FNR; bad = 1 }
        /[ \t]$/ { printf "%s:%d: trailing whitespace\n", f, FNR; bad = 1 }
        length($0) > 100 { printf "%s:%d: line longer than 100 characters\n", f, FNR; bad = 1 }
        END { exit bad }
    ' "$f" || rc=1
    if [[ -s "$f" && "$(tail -c 1 "$f" | od -An -c | tr -d ' ')" != '\n' ]]; then
        printf '%s: no final newline\n' "$f"
        rc=1
    fi
    # Layout (lean.md): Spec = the human-read claims (no proof imports, no theorem); shipped modules
    # import `Init` + `Std` + their own alone (`import Lean` links all of Lean). TrustMain + tests
    # are dev-only.
    case "$f" in
    Fvtrace/Spec.lean | Fvtrace/Spec/*)
        LC_ALL=C.UTF-8 awk -v f="$f" '
            /^import Fvtrace\.Proofs/ { printf "%s:%d: Spec imports Proofs\n", f, FNR; bad = 1 }
            /^(private |protected )?(theorem|lemma) / { printf "%s:%d: Spec holds a theorem\n", f, FNR; bad = 1 }
            END { exit bad }' "$f" || rc=1
        ;;
    TrustMain.lean | Test*.lean | Tests/* | lakefile.lean) ;;
    *)
        LC_ALL=C.UTF-8 awk -v f="$f" '
            /^import Lean([. ]|$)/ { printf "%s:%d: shipped module imports Lean\n", f, FNR; bad = 1 }
            END { exit bad }' "$f" || rc=1
        ;;
    esac
done
exit $rc
