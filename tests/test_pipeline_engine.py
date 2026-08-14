import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError  # noqa: E402
from pipeline_engine import check_artifact, resolve_inputs  # noqa: E402


class TestCheckArtifact(unittest.TestCase):
    """An operation that declares an artifact has not succeeded until that
    artifact exists and has content.

    Existence alone is not enough: a producer can fail after creating its
    output and leave it empty (hif2verilog does this when it aborts partway
    through printing - hif-backend#23). An empty .v is valid Verilog and
    reparses cleanly, so a downstream reparse check would report PASS on a
    design that was silently lost."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)

    def test_missing_artifact_is_rejected(self):
        ok, reason = check_artifact(self.tmp / "absent.v")
        self.assertFalse(ok)
        self.assertIn("not produced", reason)

    def test_empty_artifact_is_rejected(self):
        empty = self.tmp / "empty.v"
        empty.touch()
        self.assertTrue(empty.exists(), "precondition: the file exists, it is just empty")
        ok, reason = check_artifact(empty)
        self.assertFalse(ok)
        self.assertIn("empty", reason)
        self.assertIn("0 bytes", reason)

    def test_directory_is_not_an_artifact(self):
        ok, reason = check_artifact(self.tmp)
        self.assertFalse(ok)
        self.assertIn("directory", reason)

    def test_non_empty_artifact_is_accepted(self):
        produced = self.tmp / "real.v"
        produced.write_text("module m; endmodule\n")
        ok, reason = check_artifact(produced)
        self.assertTrue(ok)
        self.assertIsNone(reason)


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

    def test_rejected_artifact_cannot_be_consumed_by_reference(self):
        """A rejected artifact records None rather than being absent. Consuming
        it must fail as loudly as referencing an operation that never ran."""
        artifacts = {"a": None}
        with self.assertRaises(ManifestError) as ctx:
            resolve_inputs({"id": "b", "inputs": ["a"]}, artifacts, None, [], "p")
        self.assertIn("no usable artifact", str(ctx.exception))

    def test_rejected_artifact_cannot_be_consumed_implicitly(self):
        """Same, via the implicit "consume my predecessor" path, which is how
        terse linear pipelines are written."""
        artifacts = {"a": None}
        with self.assertRaises(ManifestError) as ctx:
            resolve_inputs({"id": "b"}, artifacts, "a", [Path("/src.v")], "p")
        self.assertIn("no usable artifact", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
