import Fvtrace.Spec

namespace Fvtrace.Proofs

theorem versionWellFormed : Spec.VersionWellFormed := by
  unfold Spec.VersionWellFormed Fvtrace.version
  decide

end Fvtrace.Proofs
