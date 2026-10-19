/-!
# Embedded assets

Files the binary carries, read at build time; `Tests/Assets.lean` holds each byte-equal to its
source file, so a stale embed fails the suite.
-/

namespace Fvtrace.Assets

/-- JSON Schema of the trace format, printed by `fvtrace schema`. -/
def traceSchema : String := include_str "../schema/trace.schema.json"

end Fvtrace.Assets
