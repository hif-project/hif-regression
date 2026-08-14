"""
Validation: separate, first-class assertions over simulation results.

Validators never execute anything. They consume artifacts produced by earlier
operations and return a verdict plus a concise, bounded mismatch excerpt -
bounded because a failing trace comparison must be readable in a CI summary,
with the full artifacts left on disk for whoever needs them.

A validation FAIL is a real behavioral regression, distinct from a CRASH (the
tool fell over) and from a TIMEOUT (it never finished). That distinction is the
whole reason validation is not folded into simulation.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from placeholders import ManifestError  # noqa: E402

MAX_MISMATCH_CHARS = 800


def _read_lines(path):
    p = Path(path)
    if not p.exists():
        return None
    return p.read_text().splitlines()


def _first_difference(left_lines, right_lines, left_label, right_label):
    for index, (l, r) in enumerate(zip(left_lines, right_lines), start=1):
        if l != r:
            return f"line {index}: {left_label}={l!r} {right_label}={r!r}"
    if len(left_lines) != len(right_lines):
        return (f"line count differs: {left_label}={len(left_lines)} "
                f"{right_label}={len(right_lines)}")
    return None


def _cap(text):
    if text and len(text) > MAX_MISMATCH_CHARS:
        return text[:MAX_MISMATCH_CHARS] + "... [truncated]"
    return text


def artifact_equal(left, right):
    left_lines = _read_lines(left)
    right_lines = _read_lines(right)
    if left_lines is None:
        return False, f"missing artifact: {left}"
    if right_lines is None:
        return False, f"missing artifact: {right}"
    diff = _first_difference(left_lines, right_lines, "left", "right")
    return (diff is None), _cap(diff)


def artifact_differs(left, right):
    equal, _ = artifact_equal(left, right)
    if equal:
        return False, "artifacts are identical, but a difference was expected"
    return True, None


def artifact_equals_fixture(left, expected):
    return artifact_equal(left, expected)


IMPLS = {
    "artifact_equal": artifact_equal,
    "artifact_differs": artifact_differs,
    "artifact_equals_fixture": artifact_equals_fixture,
}


def _operand(ref, artifacts, design, context):
    """A validation operand is a named run's trace, or a checked-in fixture."""
    if not isinstance(ref, dict):
        raise ManifestError(f"{context}: operand must be a mapping, got {ref!r}")
    if "fixture" in ref:
        return design.fixture(ref["fixture"], context)
    if "from" not in ref:
        raise ManifestError(f"{context}: operand needs 'from' or 'fixture', got {ref!r}")

    stage = artifacts.get(("simulation", ref["from"]))
    if stage is None:
        raise ManifestError(
            f"{context}: references simulation '{ref['from']}', which did not run")
    run_id = ref.get("run")
    run = stage["runs"].get(run_id)
    if run is None:
        raise ManifestError(
            f"{context}: simulation '{ref['from']}' has no run '{run_id}' "
            f"(runs: {sorted(stage['runs'])})")
    return Path(run["trace"])


def _selection_of(ref, artifacts):
    """The declarative selector and the id it resolved to, so a failing case
    can be debugged without re-deriving which fault was actually active."""
    if not isinstance(ref, dict) or "from" not in ref:
        return None, None
    stage = artifacts.get(("simulation", ref["from"]))
    if stage is None:
        return None, None
    run = stage["runs"].get(ref.get("run"))
    if not run or not run.get("selections"):
        return None, None
    first = next(iter(run["selections"].values()))
    return first["where"], first["resolved"]


def run_validation(op, registries, artifacts, design):
    op_id = op["id"]
    cases = op.get("_cases", [])
    record = {"kind": "validation", "phase": "validate", "cases": {}}
    results = []
    worst = "PASS"

    for case in cases:
        case_id = case["id"]
        context = f"validation operation '{op_id}', case '{case_id}'"
        validator = registries["validators"].get(case["use"])
        if validator is None:
            raise ManifestError(
                f"{context}: unknown validator '{case['use']}' "
                f"(known: {sorted(registries['validators'])})")

        impl_name = validator["impl"]
        left = _operand(case["left"], artifacts, design, context)
        right_ref = case.get("right") or case.get("expected")
        right = _operand(right_ref, artifacts, design, context)

        ok, mismatch = IMPLS[impl_name](left, right)
        status = "PASS" if ok else "FAIL"
        if status != "PASS":
            worst = "FAIL"

        selection, resolved = _selection_of(case["left"], artifacts)
        entry = {
            "id": case_id, "validator": case["use"], "impl": impl_name,
            "status": status, "mismatch": mismatch,
            "left": str(left), "right": str(right),
            "fault_selection": selection, "resolved_fault_id": resolved,
        }
        record["cases"][case_id] = entry
        results.append(entry)

    record["status"] = worst
    return worst, record, results
