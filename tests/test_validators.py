import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from validators import IMPLS, artifact_differs, artifact_equal  # noqa: E402


class TestComparators(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.a = Path(self.tmp.name) / "a.csv"
        self.b = Path(self.tmp.name) / "b.csv"
        self.c = Path(self.tmp.name) / "c.csv"
        self.a.write_text("time,y\n5,0\n10,1\n")
        self.b.write_text("time,y\n5,0\n10,1\n")
        self.c.write_text("time,y\n5,0\n10,0\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_equal_traces_pass(self):
        ok, mismatch = artifact_equal(self.a, self.b)
        self.assertTrue(ok)
        self.assertIsNone(mismatch)

    def test_different_traces_fail_with_first_differing_line(self):
        ok, mismatch = artifact_equal(self.a, self.c)
        self.assertFalse(ok)
        self.assertIn("line 3", mismatch)
        self.assertIn("10,1", mismatch)
        self.assertIn("10,0", mismatch)

    def test_differs_is_the_inverse(self):
        self.assertTrue(artifact_differs(self.a, self.c)[0])
        self.assertFalse(artifact_differs(self.a, self.b)[0])

    def test_mismatch_excerpt_is_capped(self):
        big_a = Path(self.tmp.name) / "ba.csv"
        big_b = Path(self.tmp.name) / "bb.csv"
        big_a.write_text("\n".join(f"{i},0" for i in range(500)))
        big_b.write_text("\n".join(f"{i},1" for i in range(500)))
        ok, mismatch = artifact_equal(big_a, big_b)
        self.assertFalse(ok)
        self.assertLess(len(mismatch), 2000)

    def test_missing_file_fails_rather_than_raising(self):
        ok, mismatch = artifact_equal(self.a, Path(self.tmp.name) / "ghost.csv")
        self.assertFalse(ok)
        self.assertIn("missing", mismatch.lower())

    def test_every_known_impl_is_registered(self):
        self.assertEqual(
            sorted(IMPLS), ["artifact_differs", "artifact_equal", "artifact_equals_fixture"]
        )


if __name__ == "__main__":
    unittest.main()
