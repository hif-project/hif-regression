import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError  # noqa: E402
from pipeline_engine import (  # noqa: E402
    ArtifactResolutionError,
    check_artifact,
    resolve_artifacts,
    resolve_inputs,
    run_step,
)


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


class TestResolveArtifacts(unittest.TestCase):
    """A declared artifact names one file or several, and the difference is a
    property of the tool, not of the design.

    hif2verilog emits one `.v` per HIF DesignUnit. A Verilog design arrives at
    the backend already flattened, so it produces one file; a VHDL design whose
    component instantiations survived produces a file per entity. Both are the
    complete artifact - resolving to just one of them would silently drop the
    rest of the hierarchy and still reparse cleanly."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)

    def test_glob_matching_one_file_resolves_to_it(self):
        (self.tmp / "top.v").write_text("module top; endmodule\n")
        got = resolve_artifacts("{workdir}/*.v", {"workdir": str(self.tmp)})
        self.assertEqual(got, [self.tmp / "top.v"])

    def test_glob_matching_several_files_resolves_to_all_of_them(self):
        (self.tmp / "top.v").write_text("module top; endmodule\n")
        (self.tmp / "cell.v").write_text("module cell; endmodule\n")
        got = resolve_artifacts("{workdir}/*.v", {"workdir": str(self.tmp)})
        self.assertEqual(got, [self.tmp / "cell.v", self.tmp / "top.v"],
                         "all matches, in a deterministic order")

    def test_glob_matching_nothing_is_still_an_error(self):
        with self.assertRaises(ArtifactResolutionError) as ctx:
            resolve_artifacts("{workdir}/*.v", {"workdir": str(self.tmp)})
        self.assertIn("no files", str(ctx.exception))

    def test_pattern_without_a_glob_is_taken_literally(self):
        got = resolve_artifacts("{workdir}/n.hif.xml", {"workdir": str(self.tmp)})
        self.assertEqual(got, [self.tmp / "n.hif.xml"],
                         "not globbed, so not required to exist yet - check_artifact decides that")


class TestSingleInputTools(unittest.TestCase):
    """`{input}` is singular by contract. Letting a multi-file artifact reach a
    tool that declares it would mean picking one file and discarding the rest,
    which is the guess the artifact rules exist to prevent. Tools that declare
    `{inputs}` take them all."""

    def test_single_input_tool_refuses_a_multi_file_artifact(self):
        tools = {"hif2vhdl": {"command": ["hif2vhdl", "{input}", "-D", "{workdir}"],
                              "artifact": "{workdir}/out.vhd"}}
        with self.assertRaises(ManifestError) as ctx:
            run_step("hif2vhdl", tools, None,
                     [Path("/w/top.v"), Path("/w/cell.v")], Path("/w"), "n", 10)
        message = str(ctx.exception)
        self.assertIn("single {input}", message)
        self.assertIn("2 files", message)
        self.assertIn("{inputs}", message, "the message names the fix")


class TestResolveInputs(unittest.TestCase):
    def test_absent_inputs_defaults_to_previous_artifact(self):
        got = resolve_inputs({"id": "b"}, {"a": [Path("/w/a.hif")]}, "a", [Path("/src.v")], "p")
        self.assertEqual(got, [Path("/w/a.hif")])

    def test_first_operation_defaults_to_design_sources(self):
        got = resolve_inputs({"id": "a"}, {}, None, [Path("/src.v")], "p")
        self.assertEqual(got, [Path("/src.v")])

    def test_explicit_reference_wins(self):
        artifacts = {"a": [Path("/w/a.hif")], "b": [Path("/w/b.v")]}
        got = resolve_inputs({"id": "c", "inputs": ["a"]}, artifacts, "b", [], "p")
        self.assertEqual(got, [Path("/w/a.hif")])

    def test_multi_file_artifact_is_flattened_into_the_input_list(self):
        """A predecessor that produced several files hands all of them on, so a
        `{inputs}` tool reparses the whole hierarchy rather than its top."""
        artifacts = {"a": [Path("/w/top.v"), Path("/w/cell.v")]}
        got = resolve_inputs({"id": "b"}, artifacts, "a", [], "p")
        self.assertEqual(got, [Path("/w/top.v"), Path("/w/cell.v")])

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
