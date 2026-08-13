#!/usr/bin/env python3
"""
External-benchmark regression runner for hif-regression.

Fetches each pinned repository from manifests/external-benchmarks.yml into
a gitignored cache directory at its exact pinned commit (never a floating
branch), enumerates every *.v file under each configured suite path, and
classifies each one exactly like the curated corpus does (PASS /
CLEAN_REJECT / CRASH / TIMEOUT - see toolchain_classify.py).

Only the frontend layer (verilog2hif) is exercised here, matching the
historical practice this pins itself against (hif-muffin's docs/known-
issues.md investigated frontend robustness against real-world files, not
full backend round-trips of arbitrary external designs - that is a much
larger, separately-scoped question).

This script is observation-only: it has no notion of a baseline and never
fails the process based on classification counts. Establishing
manifests/expectations/<suite>.json from a *reviewed* run is a deliberate,
separate step - not something this script does on its own.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from toolchain_classify import (  # noqa: E402
    DEFAULT_TIMEOUT_S,
    STATUS_SEVERITY,
    Tools,
    classify,
    run_tool,
    trim_result,
)


def load_manifest(manifest_path: Path):
    with open(manifest_path) as f:
        return yaml.safe_load(f)


def fetch_ref(repo_url: str, ref: str, dest: Path):
    """Fetch the exact pinned commit into dest, reusing an existing
    checkout if it already matches. Never follows a floating branch."""
    if dest.exists():
        try:
            current = subprocess.run(
                ["git", "-C", str(dest), "rev-parse", "HEAD"],
                capture_output=True, text=True, check=True,
            ).stdout.strip()
            if current == ref:
                return
        except subprocess.CalledProcessError:
            pass
        subprocess.run(["rm", "-rf", str(dest)], check=True)

    dest.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q", str(dest)], check=True)
    subprocess.run(["git", "-C", str(dest), "remote", "add", "origin", repo_url], check=True)
    subprocess.run(["git", "-C", str(dest), "fetch", "--depth", "1", "origin", ref], check=True)
    subprocess.run(["git", "-C", str(dest), "checkout", "-q", "FETCH_HEAD"], check=True)


def classify_file(source: Path, tools: Tools, work_root: Path, timeout_s: int):
    work_dir = work_root / source.stem
    work_dir.mkdir(parents=True, exist_ok=True)
    hif_file = work_dir / f"{source.stem}.hif.xml"
    r = run_tool(
        [tools.verilog2hif, "-o", source.stem, str(source)],
        cwd=work_dir, timeout_s=timeout_s,
    )
    status = classify(r, hif_file.exists())
    return {"status": status, "stages": {"frontend": {"status": status, **trim_result(r)}}}


def run_suite(top_key: str, suite: dict, checkout_root: Path, tools: Tools, work_root: Path, timeout_s: int, only: str):
    suite_root = checkout_root / suite["path"]
    if not suite_root.exists():
        raise SystemExit(f"suite path not found after fetch: {suite_root}")
    files = sorted(suite_root.rglob("*.v"))
    if only:
        files = [f for f in files if only in f.name]

    suite_key = f"{top_key}/{suite['name']}"
    suite_work = work_root / top_key / suite["name"]
    results = []
    for f in files:
        result = classify_file(f, tools, suite_work, timeout_s)
        results.append({
            "file": str(f.relative_to(checkout_root)),
            "status": result["status"],
            "stages": result["stages"],
        })
    return suite_key, results


def build_report(per_suite, manifest_data):
    summary = {}
    suites_out = {}
    for suite_key, results in per_suite.items():
        counts = {"PASS": 0, "CLEAN_REJECT": 0, "CRASH": 0, "TIMEOUT": 0}
        for r in results:
            counts[r["status"]] += 1
        summary[suite_key] = counts
        suites_out[suite_key] = results
    return {
        "corpus": "external",
        "summary": summary,
        "suites": suites_out,
    }


def print_summary(report):
    print("\n== hif-regression: external benchmarks (observation-only) ==\n")
    header = f"{'Suite':<22}{'Total':>7}{'Pass':>7}{'CleanReject':>13}{'Crash':>7}{'Timeout':>9}"
    print(header)
    print("-" * len(header))
    grand = {"PASS": 0, "CLEAN_REJECT": 0, "CRASH": 0, "TIMEOUT": 0}
    for suite_key in sorted(report["summary"]):
        counts = report["summary"][suite_key]
        total = sum(counts.values())
        for k in grand:
            grand[k] += counts[k]
        print(
            f"{suite_key:<22}{total:>7}{counts['PASS']:>7}{counts['CLEAN_REJECT']:>13}"
            f"{counts['CRASH']:>7}{counts['TIMEOUT']:>9}"
        )
    total = sum(grand.values())
    print("-" * len(header))
    print(
        f"{'TOTAL':<22}{total:>7}{grand['PASS']:>7}{grand['CLEAN_REJECT']:>13}"
        f"{grand['CRASH']:>7}{grand['TIMEOUT']:>9}"
    )

    for suite_key in sorted(report["summary"]):
        anomalies = [r for r in report["suites"][suite_key] if r["status"] in ("CRASH", "TIMEOUT")]
        if anomalies:
            print(f"\n{suite_key}: {len(anomalies)} file(s) CRASH/TIMEOUT:")
            for r in anomalies:
                print(f"  - {r['file']}: {r['status']}")
    print(
        "\nThis is an observation-only run - no baseline exists yet. Review "
        "these results before deciding what belongs in manifests/expectations/."
    )
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="manifests/external-benchmarks.yml")
    parser.add_argument("--cache-dir", default="external/.cache")
    parser.add_argument("--bin-dir", default=None)
    parser.add_argument("--work-dir", default=None)
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_S)
    parser.add_argument("--suite", default=None, help="only run this top-level manifest key (e.g. 'logikbench')")
    parser.add_argument("--only", default=None, help="only run files whose name contains this substring")
    parser.add_argument("--report", default="reports/external-report.json")
    args = parser.parse_args()

    manifest_path = Path(args.manifest).resolve()
    manifest = load_manifest(manifest_path)

    cache_root = Path(args.cache_dir).resolve()
    cache_root.mkdir(parents=True, exist_ok=True)

    tools = Tools(args.bin_dir)
    work_root = (Path(args.work_dir) if args.work_dir else Path("reports") / ".run" / "external").resolve()
    if work_root.exists():
        subprocess.run(["rm", "-rf", str(work_root)], check=True)
    work_root.mkdir(parents=True, exist_ok=True)

    per_suite = {}
    for top_key, entry in manifest.items():
        if args.suite and top_key != args.suite:
            continue
        checkout_root = cache_root / top_key
        print(f"-- fetching {top_key} @ {entry['ref']}")
        fetch_ref(entry["repository"], entry["ref"], checkout_root)
        for suite in entry["suites"]:
            suite_key, results = run_suite(
                top_key, suite, checkout_root, tools, work_root, args.timeout, args.only
            )
            per_suite[suite_key] = results
            print(f"   {suite_key}: {len(results)} file(s) classified")

    report = build_report(per_suite, manifest)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2))

    print_summary(report)
    print(f"JSON report: {report_path}")


if __name__ == "__main__":
    main()
