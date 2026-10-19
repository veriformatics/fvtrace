# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""fvTrace prototype GUI server. GET /api/trace → evaluated fixture;
POST /api/evaluate {"overrides": {"O3": "proved"}} → what-if evaluation.
Static: / redirects to /variants/graph/ (claim circuits)."""

import argparse
import json
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from engine import evaluate  # noqa: E402

TRACE = json.loads((ROOT / "fixture" / "tau-amyloid.json").read_text())


class Handler(SimpleHTTPRequestHandler):
    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0] == "/api/trace":
            return self._json(evaluate(TRACE))
        return super().do_GET()

    def do_POST(self):
        if self.path != "/api/evaluate":
            return self._json({"error": "not found"}, 404)
        try:
            n = int(self.headers.get("Content-Length", 0))
            req = json.loads(self.rfile.read(n) or b"{}")
            return self._json(evaluate(TRACE, req.get("overrides")))
        except (ValueError, AttributeError) as e:
            return self._json({"error": str(e)}, 400)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format, *args):
        pass


def main():
    ap = argparse.ArgumentParser(description="Serve the fvTrace prototype GUI.")
    ap.add_argument("--port", type=int, default=8642)
    ap.add_argument("--host", default="127.0.0.1")
    a = ap.parse_args()
    srv = ThreadingHTTPServer((a.host, a.port), partial(Handler, directory=str(ROOT / "web")))
    print(f"fvTrace prototype → http://{a.host}:{a.port}/", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
