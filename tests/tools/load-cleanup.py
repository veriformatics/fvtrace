"""Interrupt each load mode after its stand-in starts; every descendant must stop."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


def descendants(pid):
    try:
        children = Path(f"/proc/{pid}/task/{pid}/children").read_text().split()
    except FileNotFoundError:
        return []
    return [int(child) for child in children] + [p for child in children for p in descendants(int(child))]


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(") ", 1)[1].split()[0] != "Z"
    except FileNotFoundError:
        return False


with tempfile.TemporaryDirectory(prefix="load-cleanup-probe-") as temp:
    directory = Path(temp)
    envfile = directory / "env.sh"
    envfile.write_text('''
playwright() { printf '%s\\n' "$BASHPID" >"$READY"; command sleep 100; }
bash() {
    if [[ "${1:-}" == tools/gate.sh ]]; then
        printf '%s\\n' "$BASHPID" >"$READY"
        command sleep 100
    else command bash "$@"; fi
}
nproc() { printf '1\\n'; }
cut() {
    if [[ "${*: -1}" == /proc/loadavg ]]; then printf '%s\\n' "$LOAD"
    else command cut "$@"; fi
}
export -f playwright bash nproc cut
''')
    for mode, amount, warmup in [("measure", "1", False), ("gate", "1", False),
                                 ("measure", "1", True), ("gate", "1", True)]:
        for sig in [signal.SIGTERM, signal.SIGINT]:
            ready = directory / "ready"
            ready.unlink(missing_ok=True)
            env = dict(os.environ, BASH_ENV=str(envfile), READY=str(ready),
                       LOAD="0.0" if warmup else "10.0")
            with (directory / "log").open("w") as log:
                p = subprocess.Popen(["bash", "tools/e2e-load.sh", mode, amount], env=env,
                                     stdout=log, stderr=log, start_new_session=True)
                owned = []
                try:
                    deadline = time.monotonic() + 15
                    while p.poll() is None and time.monotonic() < deadline:
                        owned = descendants(p.pid)
                        if (warmup and len(owned) >= 2) or (not warmup and ready.exists()):
                            break
                        time.sleep(0.02)
                    assert (len(owned) >= 2 if warmup else ready.exists()), f"{mode}: work did not start"
                    owned = descendants(p.pid)
                    assert len(owned) >= 2, f"{mode}: sampler and command must start"
                    p.send_signal(sig)
                    p.wait(timeout=5)
                    deadline = time.monotonic() + 2
                    while any(alive(pid) for pid in owned) and time.monotonic() < deadline:
                        time.sleep(0.02)
                    remaining = [pid for pid in owned if alive(pid)]
                    phase = "warmup" if warmup else "command"
                    print(f"{mode} {phase} {sig.name}: parent rc={p.returncode}; live descendants={remaining}", flush=True)
                    assert not remaining, f"FAIL: {mode} left children after {sig.name}"
                finally:
                    for pid in owned + [p.pid]:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    p.wait()
