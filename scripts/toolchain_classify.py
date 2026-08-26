"""
Shared subprocess-running/classification primitives for hif-regression's
runners (curated corpus and external benchmarks). Not an executable script.

Classification: PASS / CLEAN_REJECT / CRASH / TIMEOUT.

Rationale for signal-vs-exit-code as the primary signal: HIF's own
deliberate-rejection macros (messageError/messageAssert, hif-core's
Log.cpp) call exit(EXIT_FAILURE) - never a signal. A signal-terminated
process is never HIF's own controlled rejection path in this codebase.
"""
import functools
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DEFAULT_TIMEOUT_S = 60
# FAIL is produced by validation only (see validators.py) - a tool that exits
# nonzero is CLEAN_REJECT or CRASH, never FAIL. Ordered above TIMEOUT because a
# behavioral mismatch is a harder result than "didn't finish", and below CRASH
# because a crash means we learned nothing at all.
STATUS_SEVERITY = {"PASS": 0, "CLEAN_REJECT": 1, "TIMEOUT": 2, "FAIL": 3, "CRASH": 4}
MAX_CAPTURED_OUTPUT = 4000  # chars kept per stream in a JSON report

# Minimal, explicit, reviewable. Add to this list only after confirming a new
# message is genuinely HIF's own deliberate-rejection convention, not a typo
# match against something else.
CLEAN_REJECT_PATTERNS = [
    re.compile(r"is not supported", re.IGNORECASE),
]


@functools.lru_cache(maxsize=1)
def workspace_toolchain():
    """The toolchain build_toolchain.py leaves in .workspace, if there is one.

    Read automatically so this repository works with no configuration: after
    `scripts/build_toolchain.py`, the runners find the tools with no flags, no
    `source`, and no paths for anyone to fill in.

    Returns None when .workspace has no toolchain.env - an absent or partial
    workspace is the normal state on a fresh clone, not an error.
    """
    env_path = ROOT / ".workspace" / "toolchain.env"
    if not env_path.exists():
        return None
    values = {}
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    prefix = values.get("PREFIX")
    if not prefix:
        return None
    return {
        "bin": Path(prefix) / "bin",
        "build_type": values.get("BUILD_TYPE", "unknown"),
        "refs": {k[:-4].lower().replace("_", "-"): v
                 for k, v in values.items() if k.endswith("_REF")},
        "built_at": time.strftime("%Y-%m-%d %H:%M", time.localtime(env_path.stat().st_mtime)),
    }


def find_tool(name, bin_dir=None):
    """Resolve a tool binary by name: --bin-dir, then PATH, then .workspace.

    The .workspace fallback is deliberately ranked *last*. A developer who
    prepends their own build directories to PATH is making an explicit choice -
    usually to test a fix that is not pushed anywhere yet, which
    build_toolchain.py cannot see because it fetches from the remote - and a
    convenience fallback must not silently override that. Ranking it below PATH
    also makes this change purely additive: no invocation that worked before
    resolves differently now.
    """
    if bin_dir:
        candidate = Path(bin_dir) / name
        if candidate.exists():
            return str(candidate)
    found = shutil.which(name)
    if found:
        return found
    toolchain = workspace_toolchain()
    if toolchain:
        candidate = toolchain["bin"] / name
        if candidate.exists():
            return str(candidate)
    raise SystemExit(
        f"required tool '{name}' not found under --bin-dir, on PATH, or in "
        f".workspace (run `python3 scripts/build_toolchain.py`, or put your own "
        f"build directories on PATH, or pass --bin-dir)"
    )


def activate_toolchain(bin_dir=None):
    """Prepare the environment for the toolchain this run will use, and
    describe it.

    Returns the lines to print. Called once, before any design runs.

    The preparation half is not optional. The binaries build_toolchain.py
    installs carry no RPATH or RUNPATH, so `$PREFIX/lib` has to be on
    LD_LIBRARY_PATH or they fail to start - and a tool that cannot start is
    recorded as CRASH, which reads like a compiler bug in the design rather than
    a missing library.

    It is applied *only* when .workspace is genuinely the winning source.
    Injecting it unconditionally would be actively harmful: LD_LIBRARY_PATH is
    searched before DT_RUNPATH, so it could silently pull a locally built tool
    onto the workspace's older libhif - the exact "validated the wrong binary"
    failure this banner exists to prevent.

    The description half is printed on every run because that failure is
    otherwise silent: testing against a toolchain other than the one you meant,
    and reading the result as if it were about your change.
    """
    try:
        probe = find_tool("verilog2hif", bin_dir)
    except SystemExit:
        return ["toolchain: none found (verilog2hif is missing)"]

    toolchain = workspace_toolchain()
    in_workspace = toolchain is not None and str(toolchain["bin"]) in probe

    if in_workspace:
        lib = Path(toolchain["bin"]).parent / "lib"
        existing = os.environ.get("LD_LIBRARY_PATH", "")
        if str(lib) not in existing.split(os.pathsep):
            os.environ["LD_LIBRARY_PATH"] = (
                f"{lib}{os.pathsep}{existing}" if existing else str(lib)
            )
        try:
            shown = os.path.relpath(toolchain["bin"], ROOT)
        except ValueError:
            shown = str(toolchain["bin"])
        lines = [f"toolchain: {shown}"]
        refs = toolchain["refs"]
        names = sorted(refs)
        for i in range(0, len(names), 2):
            pair = "  ".join(f"{n} {refs[n]}" for n in names[i:i + 2])
            lines.append(f"  {pair}")
        lines.append(f"  built {toolchain['built_at']} ({toolchain['build_type']})")
        return lines

    source = "--bin-dir" if bin_dir and probe.startswith(str(Path(bin_dir))) else "PATH"
    return [f"toolchain: {source} ({probe})"]


class Tools:
    """Eagerly resolves the fixed three tools external-regression uses
    directly (no pipeline/tool-registry involved there)."""

    def __init__(self, bin_dir=None):
        self.verilog2hif = find_tool("verilog2hif", bin_dir)
        self.hif2verilog = find_tool("hif2verilog", bin_dir)
        self.muffin = find_tool("muffin", bin_dir)


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
