/-!
The Agent Skill `fvtrace skills install` writes, byte for byte from `skill/fvtrace/`: its own
library (`lakefile.lean` `skillFiles`), so a skill edit rebuilds this module alone.
-/

namespace FvtraceSkill

/-- Path inside the skill folder, content. -/
def files : List (String × String) :=
  [("SKILL.md", include_str "skill/fvtrace/SKILL.md"),
   ("references/stance.md", include_str "skill/fvtrace/references/stance.md"),
   ("references/trace-format.md", include_str "skill/fvtrace/references/trace-format.md"),
   ("assets/example.trace.json", include_str "skill/fvtrace/assets/example.trace.json")]

end FvtraceSkill
