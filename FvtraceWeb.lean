/-!
The GUI files `fvtrace serve` embeds, byte for byte from `web/`: their own library (`lakefile.lean`
`webFiles`), so a GUI edit rebuilds this module alone.
-/

namespace FvtraceWeb

/-- URL path, content type, body. -/
def files : List (String × String × String) :=
  [("/", "text/html; charset=utf-8", include_str "web/index.html"),
   ("/style.css", "text/css; charset=utf-8", include_str "web/style.css"),
   ("/app.js", "text/javascript; charset=utf-8", include_str "web/app.js"),
   ("/circuit.js", "text/javascript; charset=utf-8", include_str "web/circuit.js"),
   ("/dom.js", "text/javascript; charset=utf-8", include_str "web/dom.js"),
   ("/engine.js", "text/javascript; charset=utf-8", include_str "web/engine.js"),
   ("/envelope.js", "text/javascript; charset=utf-8", include_str "web/envelope.js"),
   ("/panels.js", "text/javascript; charset=utf-8", include_str "web/panels.js"),
   ("/tour.js", "text/javascript; charset=utf-8", include_str "web/tour.js"),
   ("/words.js", "text/javascript; charset=utf-8", include_str "web/words.js"),
   ("/worker.js", "text/javascript; charset=utf-8", include_str "web/worker.js")]

end FvtraceWeb
