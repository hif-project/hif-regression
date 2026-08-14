"""
The declaratively-selected fault must be the one that actually fires.

Behavioral fixtures name a fault by stable attributes (signal/bit/type) and let
the engine resolve it to whatever numeric id Muffin assigned this time. That
indirection is what stops ids from being hardcoded - but it would be worthless
if the resolver returned a plausible-but-wrong id, because the resulting trace
would still differ from the fault-free one and a `trace_differs` check would
still pass.

This re-resolves every recorded selection against the faults.json that the run
actually produced, and requires the id to match. It reads the report rather
than re-running anything, so it is cheap and can follow any curated run.
"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from record_lookup import resolve_record  # noqa: E402

REPORT = Path("reports/curated-report.json")


def _faults_json_for(case):
    """The enumerate step's artifact lives beside the run directories of the
    same design, under the work root: <design>/<operation>/... - so walk up
    from the trace path to the design root and look for the enumerate output."""
    trace = Path(case["left"])
    for parent in trace.parents:
        candidates = list(parent.glob("enumerate/*.faults.json"))
        if candidates:
            return candidates
    return []


class TestFaultCorrespondence(unittest.TestCase):
    @unittest.skipUnless(REPORT.exists(), "needs a curated run first")
    def test_every_resolved_id_matches_its_declared_attributes(self):
        report = json.loads(REPORT.read_text())
        checked = 0

        for case in report.get("behavioral", []):
            selection = case.get("fault_selection")
            if not selection or case.get("resolved_fault_id") is None:
                continue

            candidates = _faults_json_for(case)
            self.assertEqual(
                len(candidates), 1,
                f"{case['design']}/{case['case']}: expected exactly one faults.json, "
                f"found {len(candidates)}",
            )
            document = json.loads(candidates[0].read_text())
            expected = resolve_record(
                document, "faults", selection, "id",
                f"correspondence check for {case['design']}/{case['case']}",
            )
            self.assertEqual(
                expected, case["resolved_fault_id"],
                f"{case['design']}/{case['case']}: id drifted from its attributes",
            )
            checked += 1

        self.assertGreater(checked, 0, "no fault selections were checked")

    @unittest.skipUnless(REPORT.exists(), "needs a curated run first")
    def test_corpus_asserts_both_detection_outcomes(self):
        """An undetected fault is a real property of fault simulation, not a
        tolerated failure - so the corpus must state at least one of each."""
        report = json.loads(REPORT.read_text())
        validators = {c["validator"] for c in report.get("behavioral", [])}
        self.assertIn("trace_differs", validators, "no detected-fault case in the corpus")

        undetected = [
            c for c in report.get("behavioral", [])
            if c["validator"] == "trace_equal" and c.get("fault_selection")
        ]
        self.assertTrue(
            undetected,
            "no undetected-fault case: a trace_equal expectation on a run with an "
            "active fault selection is what states 'this fault is not observable "
            "under this stimulus'",
        )


if __name__ == "__main__":
    unittest.main()
