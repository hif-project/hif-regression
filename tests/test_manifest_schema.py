import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from manifest_schema import (  # noqa: E402
    validate_behavior,
    validate_pipelines,
    validate_simulators,
    validate_validators,
)
from placeholders import ManifestError  # noqa: E402

GOOD = {"pipelines": {"p": {"operations": [
    {"id": "frontend", "kind": "tool", "use": "verilog2hif"},
    {"id": "check", "kind": "validation", "cases": {"from_spec": "expectations"}},
]}}}


class TestPipelines(unittest.TestCase):
    def test_accepts_a_well_formed_pipeline(self):
        validate_pipelines(GOOD, "p.yaml")

    def test_legacy_steps_key_is_rejected_with_migration_hint(self):
        doc = {"pipelines": {"p": {"steps": [{"id": "a", "tool": "t"}]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("operations", str(ctx.exception))
        self.assertIn("steps", str(ctx.exception))

    def test_legacy_probes_key_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [], "probes": []}}}
        with self.assertRaises(ManifestError):
            validate_pipelines(doc, "p.yaml")

    def test_duplicate_operation_id_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [
            {"id": "a", "kind": "tool", "use": "t"},
            {"id": "a", "kind": "tool", "use": "t"},
        ]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("duplicate", str(ctx.exception).lower())

    def test_unknown_kind_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [{"id": "a", "kind": "magic", "use": "t"}]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("magic", str(ctx.exception))

    def test_forward_reference_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [
            {"id": "a", "kind": "tool", "use": "t", "inputs": ["later"]},
            {"id": "later", "kind": "tool", "use": "t"},
        ]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("later", str(ctx.exception))

    def test_tool_operation_without_use_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [{"id": "a", "kind": "tool"}]}}}
        with self.assertRaises(ManifestError):
            validate_pipelines(doc, "p.yaml")


class TestSimulators(unittest.TestCase):
    def test_accepts_compile_and_run(self):
        validate_simulators({"s": {"compile": {"command": ["x"], "artifact": "a"},
                                   "run": {"command": ["y"], "artifact": "b"}}}, "s.yaml")

    def test_missing_run_phase_is_rejected(self):
        with self.assertRaises(ManifestError) as ctx:
            validate_simulators({"s": {"compile": {"command": ["x"], "artifact": "a"}}}, "s.yaml")
        self.assertIn("run", str(ctx.exception))


class TestValidators(unittest.TestCase):
    def test_accepts_known_impl(self):
        validate_validators({"v": {"impl": "artifact_equal"}}, "v.yaml")

    def test_unknown_impl_is_rejected_listing_known_ones(self):
        with self.assertRaises(ManifestError) as ctx:
            validate_validators({"v": {"impl": "telepathy"}}, "v.yaml")
        self.assertIn("telepathy", str(ctx.exception))
        self.assertIn("artifact_equal", str(ctx.exception))


class TestBehavior(unittest.TestCase):
    def test_accepts_runs_and_expectations(self):
        validate_behavior({"runs": [{"id": "golden", "params": {"mut": 0}}],
                           "expectations": [{"id": "e", "use": "trace_equal",
                                             "left": {"from": "s", "run": "golden"},
                                             "right": {"from": "r", "run": "reference"}}]}, "b.yaml")

    def test_duplicate_run_id_is_rejected(self):
        with self.assertRaises(ManifestError):
            validate_behavior({"runs": [{"id": "g"}, {"id": "g"}], "expectations": []}, "b.yaml")

    def test_expectation_without_use_is_rejected(self):
        with self.assertRaises(ManifestError):
            validate_behavior({"runs": [], "expectations": [{"id": "e"}]}, "b.yaml")


if __name__ == "__main__":
    unittest.main()
