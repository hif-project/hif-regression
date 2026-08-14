import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError  # noqa: E402
from record_lookup import is_lookup, resolve_record  # noqa: E402

DOC = {
    "schema_version": 2,
    "faults": [
        {"id": 1, "type": "stuck-at-0", "bit": 0, "signal": "y"},
        {"id": 2, "type": "stuck-at-1", "bit": 0, "signal": "y"},
        {"id": 3, "type": "stuck-at-0", "bit": 1, "signal": "q"},
    ],
}


class TestResolveRecord(unittest.TestCase):
    def test_selects_unique_record_and_takes_field(self):
        got = resolve_record(
            DOC, "faults", {"signal": "y", "bit": 0, "type": "stuck-at-0"}, "id", "case c"
        )
        self.assertEqual(got, 1)

    def test_numeric_filter_matches_json_number_via_string_compare(self):
        self.assertEqual(resolve_record(DOC, "faults", {"bit": 1}, "id", "case c"), 3)

    def test_zero_matches_is_an_error_listing_the_filter(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "faults", {"signal": "nope"}, "id", "case c")
        self.assertIn("matched 0", str(ctx.exception))
        self.assertIn("case c", str(ctx.exception))

    def test_multiple_matches_is_an_error_listing_candidates(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "faults", {"signal": "y"}, "id", "case c")
        self.assertIn("matched 2", str(ctx.exception))

    def test_missing_array_key_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "nope", {"bit": 0}, "id", "case c")
        self.assertIn("nope", str(ctx.exception))

    def test_missing_take_field_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "faults", {"bit": 1}, "nosuch", "case c")
        self.assertIn("nosuch", str(ctx.exception))

    def test_is_lookup_detects_the_mapping_form(self):
        self.assertTrue(
            is_lookup({"from": "enumerate", "array": "faults", "where": {}, "take": "id"})
        )
        self.assertFalse(is_lookup(0))
        self.assertFalse(is_lookup("golden"))


if __name__ == "__main__":
    unittest.main()
