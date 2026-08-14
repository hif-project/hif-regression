import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError  # noqa: E402
from simulation import resolve_params  # noqa: E402


class TestResolveParams(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.faults = Path(self.tmp.name) / "f.json"
        self.faults.write_text(json.dumps({"faults": [
            {"id": 1, "type": "stuck-at-0", "bit": 0, "signal": "y"},
            {"id": 2, "type": "stuck-at-1", "bit": 0, "signal": "y"},
        ]}))

    def tearDown(self):
        self.tmp.cleanup()

    def test_literal_param_passes_through(self):
        self.assertEqual(resolve_params({"mut": 0}, {}, "run r"), {"mut": 0})

    def test_lookup_param_resolves_against_artifact(self):
        got = resolve_params(
            {"mut": {"from": "enumerate", "array": "faults",
                     "where": {"signal": "y", "bit": 0, "type": "stuck-at-1"}, "take": "id"}},
            {"enumerate": self.faults}, "run r")
        self.assertEqual(got, {"mut": 2})

    def test_lookup_against_unknown_operation_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_params({"mut": {"from": "nope", "array": "faults", "where": {}, "take": "id"}},
                           {}, "run r")
        self.assertIn("nope", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
