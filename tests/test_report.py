import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from report import render_behavioral  # noqa: E402

REPORT = {"behavioral": [
    {"design": "and2", "category": "combinational", "pipeline": "muffin_behavioral",
     "case": "golden_matches_rtl", "validator": "trace_equal", "status": "PASS",
     "fault_selection": None, "resolved_fault_id": None, "mismatch": None},
    {"design": "and2", "category": "combinational", "pipeline": "muffin_behavioral",
     "case": "sa0_y_expected_trace", "validator": "expected_trace", "status": "FAIL",
     "fault_selection": {"signal": "y", "bit": 0, "type": "stuck-at-0"},
     "resolved_fault_id": 1, "mismatch": "line 5: left='20000,1,1,1' right='20000,1,1,0'"},
]}


class TestRenderBehavioral(unittest.TestCase):
    def test_counts_pass_and_fail(self):
        out = render_behavioral(REPORT)
        self.assertIn("1 passed", out)
        self.assertIn("1 failed", out)

    def test_failing_case_shows_debug_context(self):
        out = render_behavioral(REPORT)
        self.assertIn("sa0_y_expected_trace", out)
        self.assertIn("expected_trace", out)
        self.assertIn("stuck-at-0", out)
        self.assertIn("fault 1", out)

    def test_passing_case_is_not_listed_individually(self):
        self.assertNotIn("golden_matches_rtl", render_behavioral(REPORT))

    def test_absent_section_renders_nothing(self):
        self.assertEqual(render_behavioral({}), "")


if __name__ == "__main__":
    unittest.main()
