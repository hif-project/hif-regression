#!/usr/bin/env python3
"""
Render hif-regression's JSON reports (curated + external) as a Markdown
summary - for $GITHUB_STEP_SUMMARY, or just local reading.

Pure formatter: it does not decide pass/fail. run_regression.py and
run_external_regression.py each already exit nonzero on a real regression -
that is what fails the CI job; this script only makes the result readable.
Missing report files (e.g. a step upstream never ran) are rendered as
"not run this time", not an error - this is meant to be run with
`if: always()` after possibly-failed steps.
"""
import argparse
import json
from pathlib import Path

# Ordered by severity. A report written before FAIL existed (external
# benchmarks, or an archived curated run) simply has no FAIL key, so counts are
# read with .get rather than assumed present.
STATUS_COLS = ["PASS", "CLEAN_REJECT", "TIMEOUT", "FAIL", "CRASH"]


def _totals_row(rows):
    grand = {k: 0 for k in STATUS_COLS}
    for counts in rows:
        for k in STATUS_COLS:
            grand[k] += counts.get(k, 0)
    return grand


def render_curated(report: dict) -> str:
    lines = ["## Curated corpus", ""]
    lines.append("| Category | Total | Pass | CleanReject | Crash | Timeout |")
    lines.append("|---|---|---|---|---|---|")
    grand = _totals_row(report["summary"].values())
    for category, counts in sorted(report["summary"].items()):
        total = sum(counts.values())
        lines.append(f"| {category} | {total} | {counts['PASS']} | {counts['CLEAN_REJECT']} | {counts['CRASH']} | {counts['TIMEOUT']} |")
    total = sum(grand.values())
    lines.append(f"| **TOTAL** | **{total}** | **{grand['PASS']}** | **{grand['CLEAN_REJECT']}** | **{grand['CRASH']}** | **{grand['TIMEOUT']}** |")

    anomalies = [d for d in report["designs"] if d["overall_status"] != "PASS"]
    if anomalies:
        lines.append("")
        lines.append("**Anomalies:**")
        lines.append("")
        for d in anomalies:
            failing_stage = next((n for n, s in d["stages"].items() if s["status"] != "PASS"), None)
            lines.append(f"- `{d['category']}/{d['name']}`: **{d['overall_status']}** at `{failing_stage}`")
    return "\n".join(lines)


def render_behavioral(report):
    """Behavioral results, summarised. Detail deliberately stays in the JSON
    artifact: a CI summary that dumps whole traces stops being readable exactly
    when it matters most."""
    cases = report.get("behavioral") or []
    if not cases:
        return ""

    passed = [c for c in cases if c["status"] == "PASS"]
    failed = [c for c in cases if c["status"] != "PASS"]

    lines = ["", "## Muffin behavioral acceptance", "",
             f"{len(passed)} passed, {len(failed)} failed "
             f"across {len({c['design'] for c in cases})} design(s)."]

    if failed:
        lines += ["", "| Design | Case | Validator | Fault | Status | Mismatch |",
                  "|---|---|---|---|---|---|"]
        for c in failed:
            selection = c.get("fault_selection")
            fault = "-" if not selection else (
                f"{selection.get('type')} {selection.get('signal')}[{selection.get('bit')}]"
                + (f" (fault {c['resolved_fault_id']})"
                   if c.get("resolved_fault_id") is not None else "")
            )
            mismatch = (c.get("mismatch") or "").replace("|", "\\|")[:120]
            lines.append(f"| `{c['category']}/{c['design']}` | `{c['case']}` | "
                         f"`{c['validator']}` | {fault} | **{c['status']}** | {mismatch} |")
    return "\n".join(lines)


def render_external(report: dict) -> str:
    lines = ["", "## External benchmarks", ""]
    lines.append("| Suite | Total | Pass | CleanReject | Crash | Timeout |")
    lines.append("|---|---|---|---|---|---|")
    grand = _totals_row(report["summary"].values())
    for suite_key, counts in sorted(report["summary"].items()):
        total = sum(counts.values())
        lines.append(f"| {suite_key} | {total} | {counts['PASS']} | {counts['CLEAN_REJECT']} | {counts['CRASH']} | {counts['TIMEOUT']} |")
    total = sum(grand.values())
    lines.append(f"| **TOTAL** | **{total}** | **{grand['PASS']}** | **{grand['CLEAN_REJECT']}** | **{grand['CRASH']}** | **{grand['TIMEOUT']}** |")

    any_comparisons = any(report.get("comparisons", {}).values())
    if any_comparisons:
        lines.append("")
        lines.append("### Comparison against `manifests/expectations/`")
        for suite_key in sorted(report["comparisons"]):
            comparisons = report["comparisons"][suite_key]
            if not comparisons:
                continue
            regressions = [c for c in comparisons if c["verdict"] == "REGRESSION"]
            improvements = [c for c in comparisons if c["verdict"] == "IMPROVEMENT"]
            new = [c for c in comparisons if c["verdict"] == "NEW"]
            match_count = len(comparisons) - len(regressions) - len(improvements) - len(new)
            lines.append("")
            lines.append(f"**{suite_key}**: {match_count} match, {len(improvements)} improvement(s), {len(regressions)} regression(s), {len(new)} new (no baseline)")
            for c in regressions:
                lines.append(f"- :x: REGRESSION `{c['file']}`: expected {c['expected']}, got **{c['status']}**")
            for c in improvements:
                lines.append(f"- :white_check_mark: IMPROVEMENT `{c['file']}`: expected {c['expected']}, got **{c['status']}**")
            for c in new:
                lines.append(f"- :grey_question: NEW `{c['file']}`: {c['status']} (no baseline entry)")
    else:
        lines.append("")
        lines.append("_No `manifests/expectations/` file for any suite that ran - observation-only, nothing to compare against yet._")

    excluded_total = sum(len(v) for v in report.get("excluded", {}).values())
    if excluded_total:
        lines.append("")
        lines.append(f"{excluded_total} file(s) explicitly excluded (see `manifests/external-benchmarks.yml`) - not classified, not counted.")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--curated", default="reports/curated-report.json")
    parser.add_argument("--external", default="reports/external-report.json")
    args = parser.parse_args()

    sections = ["# hif-regression nightly summary", ""]

    curated_path = Path(args.curated)
    if curated_path.exists():
        curated = json.loads(curated_path.read_text())
        sections.append(render_curated(curated))
        behavioral = render_behavioral(curated)
        if behavioral:
            sections.append(behavioral)
    else:
        sections.append("## Curated corpus\n\n_not run this time._")

    external_path = Path(args.external)
    if external_path.exists():
        sections.append(render_external(json.loads(external_path.read_text())))
    else:
        sections.append("\n## External benchmarks\n\n_not run this time._")

    print("\n".join(sections))


if __name__ == "__main__":
    main()
