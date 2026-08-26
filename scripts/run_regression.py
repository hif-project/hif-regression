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

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from manifest_schema import (  # noqa: E402
    validate_behavior,
    validate_pipelines,
    validate_simulators,
    validate_validators,
)
from pipeline_engine import load_yaml_manifest, run_pipeline  # noqa: E402
from placeholders import ManifestError  # noqa: E402
from toolchain_classify import (  # noqa: E402
    DEFAULT_TIMEOUT_S,
    STATUS_SEVERITY,
    activate_toolchain,
)

# Report columns, ordered by severity so the table reads left-to-right from
# "fine" to "worst". Derived from STATUS_SEVERITY rather than restated, so a
# future status cannot be added to the classifier and silently omitted here.
STATUS_COLUMNS = sorted(STATUS_SEVERITY, key=lambda s: STATUS_SEVERITY[s])

# Design-level verdicts, appended rather than added to STATUS_SEVERITY: they are
# not things a *stage* can be classified as. A stage is still PASS/FAIL/CRASH as
# before; these describe what that outcome means for a design that declared an
# `expected_failure` in its design.json.
#
#   XFAIL  failed where it said it would, for the reason it said. Not a
#          regression - the bug it documents is filed and still open.
#   XPASS  declared an expected failure and passed anyway. That IS a failure:
#          either the bug was fixed and the key should be removed, or the design
#          stopped exercising what it was written to exercise.
#
# A design that declares an expected failure and then fails somewhere *else*
# keeps its real status, so an unrelated breakage is never absorbed by the key.
STATUS_XFAIL = "XFAIL"
STATUS_XPASS = "XPASS"
STATUS_COLUMNS = STATUS_COLUMNS + [STATUS_XFAIL, STATUS_XPASS]


@dataclasses.dataclass
class Design:
    name: str
    category: str
    sources: list
    top: str
    pipeline: str
    note: str = ""
    root: Path = None
    fixtures: dict = dataclasses.field(default_factory=dict)
    behavior: dict = dataclasses.field(default_factory=dict)
    expected_failure: dict = None

    def fixture(self, fixture_name, context):
        """Fixtures are per-design files a pipeline references by role
        (`testbench`, `expect_sa0_y`, ...) rather than by path, so one shared
        pipeline can serve designs whose files are named differently."""
        path = self.fixtures.get(fixture_name)
        if path is None:
            raise ManifestError(
                f"{context}: design '{self.category}/{self.name}' has no fixture "
                f"'{fixture_name}' (declared: {sorted(self.fixtures)})"
            )
        return path


def parse_expected_failure(meta: dict, sidecar: Path):
    """Validate and return a design's `expected_failure` declaration, if any.

    Shape:

        "expected_failure": {"issue": "hif-frontend#31", "stage": "validate"}

    Both keys are required and neither has a default. `issue` because an
    expected failure with no filed bug behind it is just a disabled test, and
    the whole point is that it stays visible and attributable. `stage` because
    "fails somewhere" is not a claim worth pinning - a design that starts
    crashing in the frontend instead of mismatching in validation has broken
    differently, and that must surface rather than be absorbed.
    """
    declaration = meta.get("expected_failure")
    if declaration is None:
        return None
    if not isinstance(declaration, dict):
        raise SystemExit(f"{sidecar}: 'expected_failure' must be a mapping")
    missing = [k for k in ("issue", "stage") if not declaration.get(k)]
    if missing:
        raise SystemExit(
            f"{sidecar}: 'expected_failure' is missing required key(s) {missing}. "
            f"An expected failure needs the issue it documents and the stage it "
            f"fails at, or it is an untracked disabled test."
        )
    return {"issue": str(declaration["issue"]), "stage": str(declaration["stage"])}


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
                    root=category_dir,
                    expected_failure=parse_expected_failure(meta, sidecar),
                ))
            elif entry.is_dir():
                sidecar = entry / "design.json"
                meta = json.loads(sidecar.read_text()) if sidecar.exists() else {}

                # An explicit `sources` list is what keeps a testbench from
                # being mistaken for a design source once a design gains
                # behavioral fixtures. Without it, the historical glob applies.
                explicit = meta.get("sources")
                if explicit:
                    sources = [entry / s for s in explicit]
                    missing = [str(p) for p in sources if not p.exists()]
                    if missing:
                        raise SystemExit(f"{entry}: design.json lists missing source(s): {missing}")
                else:
                    sources = sorted(entry.glob("*.v"))
                if not sources:
                    continue

                top = meta.get("top")
                if not top:
                    raise SystemExit(
                        f"{entry}: multi-file design needs design.json with a 'top' key"
                    )

                fixtures = {k: entry / v for k, v in (meta.get("fixtures") or {}).items()}
                missing_fixtures = {k: str(p) for k, p in fixtures.items() if not p.exists()}
                if missing_fixtures:
                    raise SystemExit(
                        f"{entry}: design.json lists missing fixture(s): {missing_fixtures}")

                behavior_path = entry / "behavior.yaml"
                behavior = {}
                if behavior_path.exists():
                    behavior = yaml.safe_load(behavior_path.read_text()) or {}
                    validate_behavior(behavior, str(behavior_path))

                designs.append(Design(
                    name=entry.name,
                    category=category,
                    sources=sources,
                    top=top,
                    pipeline=meta.get("pipeline", default_pipeline),
                    note=meta.get("note", ""),
                    root=entry,
                    fixtures=fixtures,
                    behavior=behavior,
                    expected_failure=parse_expected_failure(meta, sidecar),
                ))
    return designs


def run_design(design: Design, pipelines: dict, registries: dict, bin_dir, work_root: Path, timeout_s: int):
    if not design.pipeline:
        raise SystemExit(
            f"{design.category}/{design.name}: no pipeline resolved (no sidecar "
            f"override and no suite_defaults entry for category '{design.category}')"
        )
    work_dir = work_root / design.category / design.name
    result = run_pipeline(
        design.pipeline, pipelines, registries, bin_dir, design.sources, work_dir,
        design.top, timeout_s, design,
    )
    status = result["overall_status"]
    failing_stage = next(
        (name for name, st in result["stages"].items() if st["status"] != "PASS"), None
    )
    resolution = None

    if design.expected_failure:
        expected_stage = design.expected_failure["stage"]
        if status == "PASS":
            # The bug it documents appears to be gone. Loud on purpose: the key
            # has to be removed deliberately, by someone who checks why.
            status = STATUS_XPASS
            resolution = (
                f"declared an expected failure at stage '{expected_stage}' "
                f"({design.expected_failure['issue']}) but passed. If that issue is "
                f"fixed, drop the 'expected_failure' key from design.json."
            )
        elif failing_stage == expected_stage:
            status = STATUS_XFAIL
            resolution = (
                f"failed at '{failing_stage}' as declared "
                f"({design.expected_failure['issue']})"
            )
        else:
            # Real breakage somewhere else. Keep the true status; the key does
            # not cover this and must not hide it.
            resolution = (
                f"declared an expected failure at stage '{expected_stage}' "
                f"({design.expected_failure['issue']}) but failed at "
                f"'{failing_stage}' instead - this is not the documented failure."
            )

    return {
        "design": design,
        "stages": result["stages"],
        "behavioral": result["behavioral"],
        "overall_status": status,
        "failing_stage": failing_stage,
        "resolution": resolution,
    }


def build_report(results, manifest_label):
    designs_out = []
    behavioral_out = []
    counts = {}
    for res in results:
        design = res["design"]
        status = res["overall_status"]
        for case in res.get("behavioral", []):
            behavioral_out.append({
                "design": design.name, "category": design.category,
                "pipeline": design.pipeline, "case": case["id"],
                "validator": case["validator"], "impl": case["impl"],
                "status": case["status"], "mismatch": case["mismatch"],
                "fault_selection": case.get("fault_selection"),
                "resolved_fault_id": case.get("resolved_fault_id"),
                "left": case["left"], "right": case["right"],
            })
        counts.setdefault(design.category, {k: 0 for k in STATUS_COLUMNS})
        counts[design.category][status] += 1
        designs_out.append({
            "name": design.name,
            "category": design.category,
            "top": design.top,
            "sources": [str(s) for s in design.sources],
            "pipeline": design.pipeline,
            "note": design.note,
            "overall_status": status,
            "failing_stage": res.get("failing_stage"),
            "expected_failure": design.expected_failure,
            "resolution": res.get("resolution"),
            "stages": res["stages"],
        })
    return {
        "manifest": manifest_label,
        "corpus": "internal",
        "summary": counts,
        "designs": designs_out,
        "behavioral": behavioral_out,
    }


def print_progress(index, total, design, res):
    """One line per design, as it finishes.

    A full run is otherwise a couple of minutes of silence, which hides both
    where the time goes and - more to the point - which design broke, until
    every other one has also run.

    Nothing parses this. The CI job reads the JSON report and the step summary
    comes from report.py, so this stream is only for whoever is watching it.

    Flushed explicitly because stdout is block-buffered when it is not a
    terminal. Without that the lines arrive in one burst at the end, which is
    the behaviour this exists to remove - in CI most of all, where the run is
    a pipe and never a tty.

    The status is padded to five, which is the width of every status a healthy
    run produces. CLEAN_REJECT and TIMEOUT are wider and push the name across;
    that is deliberate, since both are worth noticing in a scrolling log.
    """
    print(
        f"[{index:>{len(str(total))}}/{total}] {res['overall_status']:<5} "
        f"{design.category}/{design.name}",
        flush=True,
    )


def print_summary(report):
    print(f"\n== hif-regression: curated corpus ({report['manifest']}) ==\n")
    header = (f"{'Category':<15}{'Total':>7}{'Pass':>7}{'CleanReject':>13}"
              f"{'Timeout':>9}{'Fail':>7}{'Crash':>7}{'XFail':>7}{'XPass':>7}")
    print(header)
    print("-" * len(header))
    grand = {k: 0 for k in STATUS_COLUMNS}
    for category, counts in sorted(report["summary"].items()):
        total = sum(counts.values())
        for k in grand:
            grand[k] += counts.get(k, 0)
        print(
            f"{category:<15}{total:>7}{counts['PASS']:>7}{counts['CLEAN_REJECT']:>13}"
            f"{counts['TIMEOUT']:>9}{counts['FAIL']:>7}{counts['CRASH']:>7}"
            f"{counts[STATUS_XFAIL]:>7}{counts[STATUS_XPASS]:>7}"
        )
    total = sum(grand.values())
    print("-" * len(header))
    print(
        f"{'TOTAL':<15}{total:>7}{grand['PASS']:>7}{grand['CLEAN_REJECT']:>13}"
        f"{grand['TIMEOUT']:>9}{grand['FAIL']:>7}{grand['CRASH']:>7}"
        f"{grand[STATUS_XFAIL]:>7}{grand[STATUS_XPASS]:>7}"
    )

    # Expected failures are listed apart from real ones. Mixing them is how a
    # known-red corpus stops being read at all.
    xfails = [d for d in report["designs"] if d["overall_status"] == STATUS_XFAIL]
    if xfails:
        print(f"\n{len(xfails)} expected failure(s) - documented, not regressions:\n")
        for d in xfails:
            print(f"  - {d['category']}/{d['name']}: {d['expected_failure']['issue']} "
                  f"at stage '{d['failing_stage']}'")

    anomalies = [
        d for d in report["designs"]
        if d["overall_status"] not in ("PASS", STATUS_XFAIL)
    ]
    if anomalies:
        print(f"\n{len(anomalies)} design(s) did not cleanly PASS every stage:\n")
        for d in anomalies:
            where = f" at stage '{d['failing_stage']}'" if d["failing_stage"] else ""
            print(f"  - {d['category']}/{d['name']}: {d['overall_status']}{where}")
            if d.get("resolution"):
                print(f"      {d['resolution']}")
            if d["note"]:
                print(f"      note: {d['note']}")

    behavioral = report.get("behavioral") or []
    if behavioral:
        failed = [c for c in behavioral if c["status"] != "PASS"]
        print(f"\nBehavioral: {len(behavioral) - len(failed)} passed, {len(failed)} failed")
        for c in failed:
            print(f"  - {c['category']}/{c['design']} :: {c['case']} "
                  f"[{c['validator']}] {c['status']}")
            if c["fault_selection"]:
                print(f"      fault: {c['fault_selection']} -> id {c['resolved_fault_id']}")
            if c["mismatch"]:
                print(f"      {c['mismatch']}")
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default="designs", help="root directory of the curated corpus")
    parser.add_argument("--tools", default="manifests/tools.yaml")
    parser.add_argument("--pipelines", default="manifests/pipelines.yaml")
    parser.add_argument("--simulators", default="manifests/simulators.yaml")
    parser.add_argument("--validators", default="manifests/validators.yaml")
    parser.add_argument("--bin-dir", default=None, help="directory containing tool binaries (default: PATH)")
    parser.add_argument("--work-dir", default=None, help="scratch directory for intermediate artifacts (default: temp dir under reports/)")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_S, help="per-stage timeout in seconds")
    parser.add_argument("--only", default=None, help="only run designs whose name contains this substring")
    parser.add_argument("--report", default="reports/curated-report.json", help="path to write the JSON report")
    parser.add_argument("--manifest-label", default="unspecified", help="label recorded in the report (e.g. 'develop' or 'stable')")
    parser.add_argument("--quiet", action="store_true", help="suppress the per-design progress lines; print only the summary")
    args = parser.parse_args()

    registries = {
        "tools": load_yaml_manifest(Path(args.tools).resolve()),
        "simulators": load_yaml_manifest(Path(args.simulators).resolve()),
        "validators": load_yaml_manifest(Path(args.validators).resolve()),
    }
    validate_simulators(registries["simulators"], args.simulators)
    validate_validators(registries["validators"], args.validators)
    pipelines = load_yaml_manifest(Path(args.pipelines).resolve())
    validate_pipelines(pipelines, args.pipelines)

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

    total = len(designs)
    if not args.quiet:
        # Before anything runs, say which binaries will run. Testing against a
        # toolchain other than the one you meant fails silently otherwise.
        print()
        for line in activate_toolchain(args.bin_dir):
            print(line, flush=True)
        print(f"\nRunning {total} design(s)...\n", flush=True)
    results = []
    for index, design in enumerate(designs, start=1):
        res = run_design(design, pipelines, registries, args.bin_dir, work_root, args.timeout)
        results.append(res)
        if not args.quiet:
            print_progress(index, total, design, res)
    report = build_report(results, args.manifest_label)

    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2))

    print_summary(report)
    print(f"JSON report: {report_path}")

    # FAIL joins CRASH/TIMEOUT: a behavioral mismatch in the curated corpus is
    # a real regression, not something to observe and move past.
    #
    # XFAIL does not, because it is documented and filed. XPASS does: a design
    # that was supposed to fail and did not is either a fix nobody recorded or a
    # design that quietly stopped testing anything.
    any_failure = any(
        d["overall_status"] in ("CRASH", "TIMEOUT", "FAIL", STATUS_XPASS)
        for d in report["designs"]
    )
    sys.exit(1 if any_failure else 0)


if __name__ == "__main__":
    main()
