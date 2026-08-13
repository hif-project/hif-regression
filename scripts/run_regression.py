#!/usr/bin/env python3
"""
Curated-corpus regression runner for hif-regression.

Drives designs/<category>/<name>.v (or <name>/ for multi-file designs)
through a named pipeline (manifests/pipelines.yaml, built from
manifests/tools.yaml) - by default the category's suite_defaults entry,
overridable per design via a "pipeline" sidecar key. Classifies each stage
as one of:

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

This script has no tool-specific knowledge - see pipeline_engine.py and
manifests/tools.yaml. Adding a future tool/pipeline is a manifest change.
"""
import argparse
import dataclasses
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pipeline_engine import load_pipelines, load_tools, run_pipeline  # noqa: E402
from toolchain_classify import DEFAULT_TIMEOUT_S  # noqa: E402


@dataclasses.dataclass
class Design:
    name: str
    category: str
    sources: list
    top: str
    pipeline: str
    note: str = ""


def discover_designs(corpus_root: Path, suite_defaults: dict):
    designs = []
    for category_dir in sorted(p for p in corpus_root.iterdir() if p.is_dir()):
        category = category_dir.name
        default_pipeline = suite_defaults.get(category)
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
                    pipeline=meta.get("pipeline", default_pipeline),
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
                    pipeline=meta.get("pipeline", default_pipeline),
                    note=meta.get("note", ""),
                ))
    return designs


def run_design(design: Design, pipelines: dict, tools: dict, bin_dir, work_root: Path, timeout_s: int):
    if not design.pipeline:
        raise SystemExit(
            f"{design.category}/{design.name}: no pipeline resolved (no sidecar "
            f"override and no suite_defaults entry for category '{design.category}')"
        )
    work_dir = work_root / design.category / design.name
    result = run_pipeline(
        design.pipeline, pipelines, tools, bin_dir, design.sources, work_dir, design.top, timeout_s
    )
    return {"design": design, "stages": result["stages"], "overall_status": result["overall_status"]}


def build_report(results, manifest_label):
    designs_out = []
    counts = {}
    for res in results:
        design = res["design"]
        status = res["overall_status"]
        counts.setdefault(design.category, {"PASS": 0, "CLEAN_REJECT": 0, "CRASH": 0, "TIMEOUT": 0})
        counts[design.category][status] += 1
        designs_out.append({
            "name": design.name,
            "category": design.category,
            "top": design.top,
            "sources": [str(s) for s in design.sources],
            "pipeline": design.pipeline,
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
        print(f"\n{len(anomalies)} design(s) did not cleanly PASS every stage:\n")
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
    parser.add_argument("--tools", default="manifests/tools.yaml")
    parser.add_argument("--pipelines", default="manifests/pipelines.yaml")
    parser.add_argument("--bin-dir", default=None, help="directory containing tool binaries (default: PATH)")
    parser.add_argument("--work-dir", default=None, help="scratch directory for intermediate artifacts (default: temp dir under reports/)")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_S, help="per-stage timeout in seconds")
    parser.add_argument("--only", default=None, help="only run designs whose name contains this substring")
    parser.add_argument("--report", default="reports/curated-report.json", help="path to write the JSON report")
    parser.add_argument("--manifest-label", default="unspecified", help="label recorded in the report (e.g. 'develop' or 'stable')")
    args = parser.parse_args()

    tools = load_tools(Path(args.tools).resolve())
    pipelines = load_pipelines(Path(args.pipelines).resolve())

    corpus_root = Path(args.corpus).resolve()
    designs = discover_designs(corpus_root, pipelines.get("suite_defaults", {}))
    if args.only:
        designs = [d for d in designs if args.only in d.name]
    if not designs:
        raise SystemExit(f"no designs found under {corpus_root} (after --only filter, if any)")

    work_root = (Path(args.work_dir) if args.work_dir else Path("reports") / ".run" / "internal").resolve()
    if work_root.exists():
        shutil.rmtree(work_root)
    work_root.mkdir(parents=True, exist_ok=True)

    results = [run_design(d, pipelines, tools, args.bin_dir, work_root, args.timeout) for d in designs]
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
