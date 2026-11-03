# reviewer-26 — K-codec + K-check

Target = `48bc51d`, frozen `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Checks = Cleanup + Altitude; one pass per lens × slice. Behavior-preserving findings only; out-of-scope defects → Register.

| row | target | verdict | basis |
|---|---|---|---|
| K-codec | Cleanup: Json + Decode + Encode + Digest | reviewer-26-F1, reviewer-26-F2 | All four modules read; exact hex-digit duplicate + six copies of string-validation protocol; declaration/reference sweep found no dead shipped definition. |
| K-codec | Cleanup: schema + tests | unknown | unknown |
| K-codec | Altitude | unknown | unknown |
| K-check | Cleanup: Model + Check + Lint | unknown | unknown |
| K-check | Cleanup: Spec/WellFormed + Proofs/Check (unused lemmas) + tests | unknown | unknown |
| K-check | Altitude | unknown | unknown |

## Findings

### reviewer-26-F1 — minor — duplicate hex-digit helper

- Location: `Fvtrace/Json.lean:298`, `Fvtrace/Digest.lean:28` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering, Cleanup: existing helpers reused; near-duplicate blocks merged.
- Both modules define the same total `Nat → Char` operation with identical bytes. JSON escaping + SHA formatting maintain two copies of one primitive; their domain + modulo behavior are identical.
- Anchor + proof (expected 2 matches; observed 2, rc 0):
  ```sh
  rg -Fn 'def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace
  ```
  ```text
  Fvtrace/Digest.lean:28:def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!
  Fvtrace/Json.lean:298:def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!
  ```
- Behavior-preserving witness: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/cleanup-equalities.lean` kernel-checks `Json.hexDigit = Digest.hexDigit` by `rfl`; command below, rc 0.
- Fix: one Init-only hex-digit primitive shared by both modules; preserve the current modulo-16 result. No proof/Spec definition names either helper.

### reviewer-26-F2 — minor — string-validator protocol copied six times

- Location: `Fvtrace/Decode.lean:73–104`, `:208–224` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering, Cleanup: near-duplicate blocks merged; deduplicate.
- `text`, `ident`, `sha`, `date`, `arg`, `failReason` each: decode `string`; propagate `none`; check a string predicate; on success return the unchanged string; otherwise report its code + message and return `none`. Only predicate/code/message differ. Six copies of the shared field-decoder protocol can be one helper with those parameters; the separate enum decoder has a distinct value lookup and is not included.
- Anchor: `rg -Fn 'match ← string path v with' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Decode.lean` → lines 74, 83, 92, 99, 111, 209, 216, rc 0; line 111 is the excluded enum decoder. Enclosing six definitions + branches read in full.
- Existing-helper search: `rg -n '(def .*([Vv]alid|[Vv]alidate|[Pp]redicate|[Cc]hecked[Ss]tring)|match ← string path v)'` over `Fvtrace/{Decode,Snapshot,Request}.lean` found these copies + the Boolean predicates, no factoring helper.
- Behavior-preserving witness: six `rfl` equalities in `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/cleanup-equalities.lean` prove each current decoder definition equal to one parameterized helper on its entire `Field` domain (values, paths + diagnostic state), not sampled inputs. Run:
  ```sh
  (cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/cleanup-equalities.lean)
  ```
  Observed: no diagnostics, rc 0 (7 equality examples, including F1).
- Fix: shared validated-string `Field String`, parameterized by predicate, diagnostic code + `String → String` message; preserve each predicate, exact diagnostic bytes + report order. No proved definition needs changing.

## Register

Pending.
