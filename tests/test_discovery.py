import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError  # noqa: E402
from run_regression import discover_designs  # noqa: E402


class TestDiscovery(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _behavioral_design(self):
        d = self.root / "combinational" / "and2"
        d.mkdir(parents=True)
        (d / "and2.v").write_text(
            "module and2(input a, input b, output y);\nassign y=a&b;\nendmodule\n")
        (d / "and2_tb.v").write_text("module and2_tb; endmodule\n")
        (d / "design.json").write_text(json.dumps({
            "top": "and2", "pipeline": "muffin_behavioral",
            "sources": ["and2.v"], "fixtures": {"testbench": "and2_tb.v"}}))
        (d / "behavior.yaml").write_text(
            "runs:\n  - {id: golden, params: {mut: 0}}\nexpectations: []\n")
        return d

    def test_explicit_sources_exclude_the_testbench(self):
        self._behavioral_design()
        designs = discover_designs(self.root, {"combinational": "plain_roundtrip"})
        self.assertEqual(len(designs), 1)
        self.assertEqual([p.name for p in designs[0].sources], ["and2.v"])

    def test_fixtures_resolve_to_paths(self):
        self._behavioral_design()
        design = discover_designs(self.root, {})[0]
        self.assertEqual(design.fixture("testbench", "ctx").name, "and2_tb.v")

    def test_unknown_fixture_names_the_available_ones(self):
        self._behavioral_design()
        design = discover_designs(self.root, {})[0]
        with self.assertRaises(ManifestError) as ctx:
            design.fixture("nope", "ctx")
        self.assertIn("testbench", str(ctx.exception))

    def test_behavior_yaml_is_loaded_and_validated(self):
        self._behavioral_design()
        design = discover_designs(self.root, {})[0]
        self.assertEqual(design.behavior["runs"][0]["id"], "golden")

    def test_single_file_design_still_discovered_without_sidecar(self):
        (self.root / "sequential").mkdir(parents=True)
        (self.root / "sequential" / "counter.v").write_text("module counter; endmodule\n")
        designs = discover_designs(self.root, {"sequential": "plain_roundtrip"})
        self.assertEqual(designs[0].name, "counter")
        self.assertEqual(designs[0].pipeline, "plain_roundtrip")
        self.assertEqual(designs[0].behavior, {})

    def test_multi_file_design_without_explicit_sources_globs_all_v(self):
        d = self.root / "hierarchical" / "h"
        d.mkdir(parents=True)
        (d / "top.v").write_text("module top; endmodule\n")
        (d / "child.v").write_text("module child; endmodule\n")
        (d / "design.json").write_text(json.dumps({"top": "top"}))
        design = discover_designs(self.root, {})[0]
        self.assertEqual(sorted(p.name for p in design.sources), ["child.v", "top.v"])


if __name__ == "__main__":
    unittest.main()
