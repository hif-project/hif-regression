"""
Shared subprocess-running/classification primitives for hif-regression's
runners (curated corpus and external benchmarks). Not an executable script.

Classification: PASS / CLEAN_REJECT / CRASH / TIMEOUT.

Rationale for signal-vs-exit-code as the primary signal: HIF's own
deliberate-rejection macros (messageError/messageAssert, hif-core's
Log.cpp) call exit(EXIT_FAILURE) - never a signal. A signal-terminated
process is never HIF's own controlled rejection path in this codebase.
"""
import re
import shutil
import subprocess
import time
from pathlib import Path

DEFAULT_TIMEOUT_S = 60
STATUS_SEVERITY = {"PASS": 0, "CLEAN_REJECT": 1, "TIMEOUT": 2, "CRASH": 3}
MAX_CAPTURED_OUTPUT = 4000  # chars kept per stream in a JSON report

# Minimal, explicit, reviewable. Add to this list only after confirming a new
# message is genuinely HIF's own deliberate-rejection convention, not a typo
# match against something else.
CLEAN_REJECT_PATTERNS = [
    re.compile(r"is not supported", re.IGNORECASE),
]


class Tools:
    def __init__(self, bin_dir=None):
        self.verilog2hif = self._find("verilog2hif", bin_dir)
        self.hif2verilog = self._find("hif2verilog", bin_dir)
        self.muffin = self._find("muffin", bin_dir)

    @staticmethod
    def _find(name, bin_dir):
        if bin_dir:
            candidate = Path(bin_dir) / name
            if candidate.exists():
                return str(candidate)
        found = shutil.which(name)
        if not found:
            raise SystemExit(
                f"required tool '{name}' not found on PATH or under --bin-dir "
                f"(did you `source .workspace/toolchain.env` and add $PREFIX/bin "
                f"to PATH, or pass --bin-dir?)"
            )
        return found


def run_tool(argv, cwd, timeout_s):
    start = time.monotonic()
    try:
        proc = subprocess.run(
            argv, cwd=cwd, capture_output=True, text=True, timeout=timeout_s
        )
        return {
            "returncode": proc.returncode,
            "stdout": proc.stdout,
            "stderr": proc.stderr,
            "elapsed_s": round(time.monotonic() - start, 3),
            "timed_out": False,
        }
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        return {
            "returncode": None,
            "stdout": stdout.decode() if isinstance(stdout, bytes) else stdout,
            "stderr": stderr.decode() if isinstance(stderr, bytes) else stderr,
            "elapsed_s": round(time.monotonic() - start, 3),
            "timed_out": True,
        }


def classify(run_result, artifact_ok):
    if run_result["timed_out"]:
        return "TIMEOUT"
    rc = run_result["returncode"]
    if rc == 0:
        return "PASS" if artifact_ok else "CRASH"
    if rc is not None and rc < 0:
        return "CRASH"  # killed by a signal - never HIF's own deliberate exit()
    stderr = run_result["stderr"] or ""
    for pattern in CLEAN_REJECT_PATTERNS:
        if pattern.search(stderr):
            return "CLEAN_REJECT"
    return "CRASH"  # unrecognized nonzero exit - stay conservative, surface it


def trim_result(run_result):
    trimmed = dict(run_result)
    for key in ("stdout", "stderr"):
        if trimmed[key] and len(trimmed[key]) > MAX_CAPTURED_OUTPUT:
            trimmed[key] = trimmed[key][:MAX_CAPTURED_OUTPUT] + "... [truncated]"
    return trimmed
