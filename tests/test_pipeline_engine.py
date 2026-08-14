import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from pipeline_engine import resolve_inputs  # noqa: E402


class TestResolveInputs(unittest.TestCase):
    def test_absent_inputs_defaults_to_previous_artifact(self):
        got = resolve_inputs({"id": "b"}, {"a": Path("/w/a.hif")}, "a", [Path("/src.v")], "p")
        self.assertEqual(got, [Path("/w/a.hif")])

    def test_first_operation_defaults_to_design_sources(self):
        got = resolve_inputs({"id": "a"}, {}, None, [Path("/src.v")], "p")
        self.assertEqual(got, [Path("/src.v")])

    def test_explicit_reference_wins(self):
        artifacts = {"a": Path("/w/a.hif"), "b": Path("/w/b.v")}
        got = resolve_inputs({"id": "c", "inputs": ["a"]}, artifacts, "b", [], "p")
        self.assertEqual(got, [Path("/w/a.hif")])


if __name__ == "__main__":
    unittest.main()
