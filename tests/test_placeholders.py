import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError, expand_argv  # noqa: E402


class TestExpandArgv(unittest.TestCase):
    def test_scalar_substitutes_within_token(self):
        argv = expand_argv(["-o", "{workdir}/sim.vvp"], {"workdir": "/w"}, {}, "op x")
        self.assertEqual(argv, ["-o", "/w/sim.vvp"])

    def test_list_placeholder_expands_to_multiple_argv_entries(self):
        argv = expand_argv(["cc", "{sources}"], {}, {"sources": ["a.v", "b.v"]}, "op x")
        self.assertEqual(argv, ["cc", "a.v", "b.v"])

    def test_empty_list_placeholder_disappears(self):
        argv = expand_argv(["cc", "{defines}", "x"], {}, {"defines": []}, "op x")
        self.assertEqual(argv, ["cc", "x"])

    def test_list_placeholder_inside_larger_token_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            expand_argv(["-I{sources}"], {}, {"sources": ["a"]}, "op x")
        self.assertIn("must be the entire token", str(ctx.exception))
        self.assertIn("op x", str(ctx.exception))

    def test_unknown_placeholder_is_an_error_naming_the_token(self):
        with self.assertRaises(ManifestError) as ctx:
            expand_argv(["{nope}"], {"workdir": "/w"}, {}, "op x")
        self.assertIn("nope", str(ctx.exception))
        self.assertIn("op x", str(ctx.exception))

    def test_literal_token_passes_through(self):
        self.assertEqual(expand_argv(["-g2005"], {}, {}, "op x"), ["-g2005"])


if __name__ == "__main__":
    unittest.main()
