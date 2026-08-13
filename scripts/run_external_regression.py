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

Once manifests/expectations/<top-level-key>.json exists for a suite, this
script also compares each file's result against it (see toolchain_classify's
STATUS_SEVERITY for the PASS < CLEAN_REJECT < TIMEOUT < CRASH ordering) and
reports REGRESSION / IMPROVEMENT / MATCH / NEW per file. A file with no
expectations file at all for its top-level key is simply not compared - the
run always succeeds and reports results either way. Establishing that
expectations file from a *reviewed* run is a deliberate, separate step - not
something this script does automatically.

Two-tier timeout: a file with a known-TIMEOUT baseline runs with
--probe-timeout (default 60s) instead of the full --timeout (default 300s)
- just enough to confirm "still stuck" without spending the full budget
re-proving it every night. Everything else (no baseline, or a PASS/
CLEAN_REJECT baseline) always gets the full timeout.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from toolchain_classify import (  # noqa: E402
    STATUS_SEVERITY,
    Tools,
    classify,
    run_tool,
    trim_result,
)

# Deliberately separate from toolchain_classify.DEFAULT_TIMEOUT_S (60s, tuned
# for the curated corpus's tiny hand-written designs). External real-world
# files are calibrated separately - see manifests/expectations/README.md.
EXTERNAL_DEFAULT_TIMEOUT_S = 300

# Files with a known-TIMEOUT baseline get this much shorter timeout instead
# of the full one - just enough to confirm "still stuck" without re-proving
# it from scratch every night (see manifests/expectations/README.md's
# "calibration ceiling vs. nightly operational timeout" policy). If one
# completes within this window, that is an IMPROVEMENT, not a regression.
PROBE_TIMEOUT_S = 60


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


def run_suite(
    top_key: str, suite: dict, checkout_root: Path, tools: Tools, work_root: Path,
    timeout_s: int, probe_timeout_s: int, expectations: dict, only: str,
):
    suite_root = checkout_root / suite["path"]
    if not suite_root.exists():
        raise SystemExit(f"suite path not found after fetch: {suite_root}")

    file_glob = suite.get("file_glob", "**/*.v")
    files = sorted(suite_root.glob(file_glob))
    if only:
        files = [f for f in files if only in f.name]

    excluded_rel_paths = {e["path"]: e["reason"] for e in suite.get("exclude", [])}

    suite_key = f"{top_key}/{suite['name']}"
    suite_expectations = expectations.get(suite_key, {}) if expectations else {}
    suite_work = work_root / top_key / suite["name"]
    results = []
    excluded = []
    for f in files:
        rel = str(f.relative_to(suite_root))
        if rel in excluded_rel_paths:
            excluded.append({"file": str(f.relative_to(checkout_root)), "reason": excluded_rel_paths[rel]})
            continue

        file_key = str(f.relative_to(checkout_root))
        expected_entry = suite_expectations.get(file_key)
        expected_status = expected_entry["stages"]["frontend"]["status"] if expected_entry else None
        # Only a *known-TIMEOUT* baseline gets the short probe - anything with
        # no baseline, or a PASS/CLEAN_REJECT baseline, gets the full budget,
        # so we never mistake "needs 70s" for "stuck" on an unproven file.
        effective_timeout = probe_timeout_s if expected_status == "TIMEOUT" else timeout_s

        result = classify_file(f, tools, suite_work, effective_timeout)
        results.append({
            "file": file_key,
            "status": result["status"],
            "elapsed_s": result["stages"]["frontend"]["elapsed_s"],
            "timeout_used": effective_timeout,
            "stages": result["stages"],
        })
    return suite_key, results, excluded


def load_expectations(expectations_dir: Path, top_key: str):
    path = expectations_dir / f"{top_key}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text())


def compare_to_expectations(suite_key: str, results: list, expectations: dict):
    """Compare each file's frontend-stage status against its expectation, if
    any. Returns a list of {file, status, expected, verdict} - verdict is one
    of MATCH, REGRESSION, IMPROVEMENT, NEW (no expectation entry at all)."""
    suite_expectations = expectations.get(suite_key, {}) if expectations else {}
    comparisons = []
    for r in results:
        expected_entry = suite_expectations.get(r["file"])
        if expected_entry is None:
            comparisons.append({"file": r["file"], "status": r["status"], "expected": None, "verdict": "NEW"})
            continue
        expected_status = expected_entry["stages"]["frontend"]["status"]
        if r["status"] == expected_status:
            verdict = "MATCH"
        elif STATUS_SEVERITY[r["status"]] > STATUS_SEVERITY[expected_status]:
            verdict = "REGRESSION"
        else:
            verdict = "IMPROVEMENT"
        comparisons.append({"file": r["file"], "status": r["status"], "expected": expected_status, "verdict": verdict})
    return comparisons


def build_report(per_suite, comparisons_by_suite):
    summary = {}
    suites_out = {}
    excluded_out = {}
    for suite_key, (results, excluded) in per_suite.items():
        counts = {"PASS": 0, "CLEAN_REJECT": 0, "CRASH": 0, "TIMEOUT": 0}
        for r in results:
            counts[r["status"]] += 1
        summary[suite_key] = counts
        suites_out[suite_key] = results
        excluded_out[suite_key] = excluded
    return {
        "corpus": "external",
        "summary": summary,
        "suites": suites_out,
        "excluded": excluded_out,
        "comparisons": comparisons_by_suite,
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
                print(f"  - {r['file']}: {r['status']} ({r['elapsed_s']}s, timeout={r['timeout_used']}s)")
        excluded = report["excluded"].get(suite_key, [])
        if excluded:
            print(f"\n{suite_key}: {len(excluded)} file(s) explicitly excluded (not classified, not counted):")
            for e in excluded:
                print(f"  - {e['file']}: {e['reason']}")

    any_expectations = any(report["comparisons"].values())
    if any_expectations:
        print("\n== comparison against manifests/expectations/ ==")
        for suite_key in sorted(report["comparisons"]):
            comparisons = report["comparisons"][suite_key]
            if not comparisons:
                continue
            regressions = [c for c in comparisons if c["verdict"] == "REGRESSION"]
            improvements = [c for c in comparisons if c["verdict"] == "IMPROVEMENT"]
            new = [c for c in comparisons if c["verdict"] == "NEW"]
            match_count = len(comparisons) - len(regressions) - len(improvements) - len(new)
            print(f"\n{suite_key}: {match_count} match, {len(improvements)} improvement(s), {len(regressions)} regression(s), {len(new)} new (no baseline)")
            for c in regressions:
                print(f"  REGRESSION  {c['file']}: expected {c['expected']}, got {c['status']}")
            for c in improvements:
                print(f"  IMPROVEMENT {c['file']}: expected {c['expected']}, got {c['status']}")
            for c in new:
                print(f"  NEW         {c['file']}: {c['status']} (no baseline entry)")
    else:
        print(
            "\nNo manifests/expectations/ file for any selected suite - "
            "observation-only, nothing to compare against yet."
        )
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="manifests/external-benchmarks.yml")
    parser.add_argument("--cache-dir", default="external/.cache")
    parser.add_argument("--bin-dir", default=None)
    parser.add_argument("--work-dir", default=None)
    parser.add_argument("--timeout", type=int, default=EXTERNAL_DEFAULT_TIMEOUT_S)
    parser.add_argument("--probe-timeout", type=int, default=PROBE_TIMEOUT_S, help="timeout for files with a known-TIMEOUT baseline")
    parser.add_argument("--suite", default=None, help="only run this top-level manifest key (e.g. 'logikbench')")
    parser.add_argument("--suite-name", default=None, help="only run the suite with this 'name' within the selected top-level key(s) (e.g. 'iscas85')")
    parser.add_argument("--only", default=None, help="only run files whose name contains this substring")
    parser.add_argument("--report", default="reports/external-report.json")
    parser.add_argument("--expectations-dir", default="manifests/expectations")
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

    expectations_dir = Path(args.expectations_dir).resolve()

    per_suite = {}
    comparisons_by_suite = {}
    for top_key, entry in manifest.items():
        if args.suite and top_key != args.suite:
            continue
        checkout_root = cache_root / top_key
        print(f"-- fetching {top_key} @ {entry['ref']}")
        fetch_ref(entry["repository"], entry["ref"], checkout_root)
        expectations = load_expectations(expectations_dir, top_key)
        for suite in entry["suites"]:
            if args.suite_name and suite["name"] != args.suite_name:
                continue
            suite_key, results, excluded = run_suite(
                top_key, suite, checkout_root, tools, work_root,
                args.timeout, args.probe_timeout, expectations, args.only,
            )
            per_suite[suite_key] = (results, excluded)
            comparisons_by_suite[suite_key] = compare_to_expectations(suite_key, results, expectations)
            print(f"   {suite_key}: {len(results)} file(s) classified, {len(excluded)} excluded")

    report = build_report(per_suite, comparisons_by_suite)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2))

    print_summary(report)
    print(f"JSON report: {report_path}")

    regressions = [
        c for comparisons in report["comparisons"].values() for c in comparisons if c["verdict"] == "REGRESSION"
    ]
    new_crashes = [
        c for comparisons in report["comparisons"].values()
        for c in comparisons if c["verdict"] == "NEW" and c["status"] == "CRASH"
    ]
    sys.exit(1 if (regressions or new_crashes) else 0)


if __name__ == "__main__":
    main()
