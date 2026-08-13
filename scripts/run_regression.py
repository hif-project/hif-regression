#!/usr/bin/env python3
"""
Curated-corpus regression runner for hif-regression.

Drives designs/<category>/<name>.v (or <name>/ for multi-file designs)
through the real toolchain (verilog2hif -> hif2verilog -> verilog2hif, plus
optional muffin instrumentation), classifying each stage as one of:

    PASS          - tool exited 0 and produced the expected artifact
    CLEAN_REJECT  - tool exited nonzero, not killed by a signal, and stderr
                    matches a known, explicit "deliberately unsupported"
                    message pattern
    CRASH         - killed by a signal, OR exited nonzero without matching
                    any known clean-rejection pattern (unrecognized failures
                    are conservatively CRASH, not silently bucketed away)
    TIMEOUT       - exceeded --timeout seconds

Rationale for signal-vs-exit-code as the primary signal: HIF's own
deliberate-rejection macros (messageError/messageAssert, hif-core's
Log.cpp) call exit(EXIT_FAILURE) - never a signal. A signal-terminated
process is never HIF's own controlled rejection path in this codebase.
"""
import argparse
import dataclasses
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

DEFAULT_TIMEOUT_S = 60
DEFAULT_LAYERS = ["frontend", "backend", "reparse"]
STATUS_SEVERITY = {"PASS": 0, "CLEAN_REJECT": 1, "TIMEOUT": 2, "CRASH": 3}

# Minimal, explicit, reviewable. Add to this list only after confirming a new
# message is genuinely HIF's own deliberate-rejection convention, not a typo
# match against something else.
CLEAN_REJECT_PATTERNS = [
    re.compile(r"is not supported", re.IGNORECASE),
]

MAX_CAPTURED_OUTPUT = 4000  # chars kept per stream in the JSON report


@dataclasses.dataclass
class Design:
    name: str
    category: str
    sources: list
    top: str
    layers: list
    muffin: bool
    note: str = ""


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


def discover_designs(corpus_root: Path):
    designs = []
    for category_dir in sorted(p for p in corpus_root.iterdir() if p.is_dir()):
        category = category_dir.name
        for entry in sorted(category_dir.iterdir()):
            if entry.name.startswith("."):
                continue
            if entry.is_file() and entry.suffix == ".v":
                sidecar = entry.with_suffix(".json")
                meta = json.loads(sidecar.read_text()) if sidecar.exists() else {}
                designs.append(Design(
                    name=entry.stem,
                    category=category,
                    sources=[entry],
                    top=meta.get("top", entry.stem),
                    layers=meta.get("layers", DEFAULT_LAYERS),
                    muffin=meta.get("muffin", False),
                    note=meta.get("note", ""),
                ))
            elif entry.is_dir():
                sidecar = entry / "design.json"
                meta = json.loads(sidecar.read_text()) if sidecar.exists() else {}
                sources = sorted(entry.glob("*.v"))
                if not sources:
                    continue
                top = meta.get("top")
                if not top:
                    raise SystemExit(
                        f"{entry}: multi-file design needs design.json with a 'top' key"
                    )
                designs.append(Design(
                    name=entry.name,
                    category=category,
                    sources=sources,
                    top=top,
                    layers=meta.get("layers", DEFAULT_LAYERS),
                    muffin=meta.get("muffin", False),
                    note=meta.get("note", ""),
                ))
    return designs


def _run(argv, cwd, timeout_s):
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


def _trim(run_result):
    trimmed = dict(run_result)
    for key in ("stdout", "stderr"):
        if trimmed[key] and len(trimmed[key]) > MAX_CAPTURED_OUTPUT:
            trimmed[key] = trimmed[key][:MAX_CAPTURED_OUTPUT] + "... [truncated]"
    return trimmed


def run_design(design: Design, tools: Tools, work_root: Path, timeout_s: int):
    work_dir = work_root / design.category / design.name
    work_dir.mkdir(parents=True, exist_ok=True)
    stages = {}

    def record(stage_name, run_result, artifact_ok):
        status = classify(run_result, artifact_ok)
        stages[stage_name] = {"status": status, **_trim(run_result)}
        return status

    hif_file = work_dir / f"{design.top}.hif.xml"
    if "frontend" in design.layers:
        r = _run(
            [tools.verilog2hif, "-o", design.top, *[str(s) for s in design.sources]],
            cwd=work_dir, timeout_s=timeout_s,
        )
        if record("frontend", r, hif_file.exists()) != "PASS":
            return {"design": design, "stages": stages}

    regen_dir = work_dir / "regen"
    regen_files = []
    if "backend" in design.layers:
        r = _run(
            [tools.hif2verilog, str(hif_file), "-D", str(regen_dir)],
            cwd=work_dir, timeout_s=timeout_s,
        )
        regen_files = sorted(regen_dir.glob("*.v")) if regen_dir.exists() else []
        if record("backend", r, bool(regen_files)) != "PASS":
            return {"design": design, "stages": stages}

    if "reparse" in design.layers:
        reparse_dir = work_dir / "reparse"
        reparse_dir.mkdir(exist_ok=True)
        reparsed_hif = reparse_dir / f"{design.top}.hif.xml"
        r = _run(
            [tools.verilog2hif, "-o", design.top, *[str(f) for f in regen_files]],
            cwd=reparse_dir, timeout_s=timeout_s,
        )
        if record("reparse", r, reparsed_hif.exists()) != "PASS":
            return {"design": design, "stages": stages}

    if design.muffin:
        faults_json = work_dir / f"{design.top}.faults.json"
        r = _run(
            [tools.muffin, str(hif_file), "--list-faults", str(faults_json)],
            cwd=work_dir, timeout_s=timeout_s,
        )
        if record("muffin_list_faults", r, faults_json.exists()) != "PASS":
            return {"design": design, "stages": stages}

        instrumented = work_dir / f"{design.top}.instrumented.hif.xml"
        r = _run(
            [tools.muffin, str(hif_file), "--instrument", "-o", str(instrumented)],
            cwd=work_dir, timeout_s=timeout_s,
        )
        record("muffin_instrument", r, instrumented.exists())

    return {"design": design, "stages": stages}


def overall_status(stages):
    if not stages:
        return "PASS"
    return max(stages.values(), key=lambda s: STATUS_SEVERITY[s["status"]])["status"]


def build_report(results, manifest_label):
    designs_out = []
    counts = {}
    for res in results:
        design = res["design"]
        status = overall_status(res["stages"])
        counts.setdefault(design.category, {"PASS": 0, "CLEAN_REJECT": 0, "CRASH": 0, "TIMEOUT": 0})
        counts[design.category][status] += 1
        designs_out.append({
            "name": design.name,
            "category": design.category,
            "top": design.top,
            "sources": [str(s) for s in design.sources],
            "muffin": design.muffin,
            "note": design.note,
            "overall_status": status,
            "stages": res["stages"],
        })
    return {
        "manifest": manifest_label,
        "corpus": "internal",
        "summary": counts,
        "designs": designs_out,
    }


def print_summary(report):
    print(f"\n== hif-regression: curated corpus ({report['manifest']}) ==\n")
    header = f"{'Category':<15}{'Total':>7}{'Pass':>7}{'CleanReject':>13}{'Crash':>7}{'Timeout':>9}"
    print(header)
    print("-" * len(header))
    grand = {"PASS": 0, "CLEAN_REJECT": 0, "CRASH": 0, "TIMEOUT": 0}
    for category, counts in sorted(report["summary"].items()):
        total = sum(counts.values())
        for k in grand:
            grand[k] += counts[k]
        print(
            f"{category:<15}{total:>7}{counts['PASS']:>7}{counts['CLEAN_REJECT']:>13}"
            f"{counts['CRASH']:>7}{counts['TIMEOUT']:>9}"
        )
    total = sum(grand.values())
    print("-" * len(header))
    print(
        f"{'TOTAL':<15}{total:>7}{grand['PASS']:>7}{grand['CLEAN_REJECT']:>13}"
        f"{grand['CRASH']:>7}{grand['TIMEOUT']:>9}"
    )

    anomalies = [
        d for d in report["designs"] if d["overall_status"] != "PASS"
    ]
    if anomalies:
        print(f"\n{len(anomalies)} design(s) did not cleanly PASS every layer:\n")
        for d in anomalies:
            failing_stage = next(
                (name for name, s in d["stages"].items() if s["status"] != "PASS"),
                None,
            )
            print(f"  - {d['category']}/{d['name']}: {d['overall_status']} at stage '{failing_stage}'")
            if d["note"]:
                print(f"      note: {d['note']}")
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default="designs", help="root directory of the curated corpus")
    parser.add_argument("--bin-dir", default=None, help="directory containing verilog2hif/hif2verilog/muffin (default: PATH)")
    parser.add_argument("--work-dir", default=None, help="scratch directory for intermediate artifacts (default: temp dir under reports/)")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_S, help="per-stage timeout in seconds")
    parser.add_argument("--only", default=None, help="only run designs whose name contains this substring")
    parser.add_argument("--report", default="reports/curated-report.json", help="path to write the JSON report")
    parser.add_argument("--manifest-label", default="unspecified", help="label recorded in the report (e.g. 'develop' or 'stable')")
    args = parser.parse_args()

    corpus_root = Path(args.corpus).resolve()
    designs = discover_designs(corpus_root)
    if args.only:
        designs = [d for d in designs if args.only in d.name]
    if not designs:
        raise SystemExit(f"no designs found under {corpus_root} (after --only filter, if any)")

    tools = Tools(args.bin_dir)

    work_root = (Path(args.work_dir) if args.work_dir else Path("reports") / ".run" / "internal").resolve()
    if work_root.exists():
        shutil.rmtree(work_root)
    work_root.mkdir(parents=True, exist_ok=True)

    results = [run_design(d, tools, work_root, args.timeout) for d in designs]
    report = build_report(results, args.manifest_label)

    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2))

    print_summary(report)
    print(f"JSON report: {report_path}")

    any_crash_or_timeout = any(
        d["overall_status"] in ("CRASH", "TIMEOUT") for d in report["designs"]
    )
    sys.exit(1 if any_crash_or_timeout else 0)


if __name__ == "__main__":
    main()
