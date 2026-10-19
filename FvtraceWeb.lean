/-!
The GUI files `fvtrace serve` embeds, byte for byte from `web/`: their own library (`lakefile.lean`
`webFiles`), so a GUI edit rebuilds this module alone.
-/

namespace FvtraceWeb

/-- URL path, content type, body. -/
def files : List (String × String × String) :=
  [("/", "text/html; charset=utf-8", include_str "web/index.html"),
   ("/app.js", "text/javascript; charset=utf-8", include_str "web/app.js"),
   ("/style.css", "text/css; charset=utf-8", include_str "web/style.css")]

end FvtraceWeb
