"""
The nightly skips itself when the fingerprint matches the last green run, so a
fingerprint that misses a repository (or orders them unpredictably) would make
it skip runs it should not. These pin the shape without touching the network.
"""
import sys
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from nightly_fingerprint import fingerprint  # noqa: E402


class FingerprintTest(unittest.TestCase):
    def setUp(self):
        self.repositories = yaml.safe_load((ROOT / "manifests" / "repositories.yaml").read_text())
        self.resolved = []

    def resolve(self, url, ref):
        self.resolved.append((url, ref))
        return f"{url.rsplit('/', 1)[-1].removesuffix('.git')}@{ref}"

    def test_every_repository_of_the_develop_manifest_is_in_it(self):
        refs = yaml.safe_load((ROOT / "manifests" / "develop.yaml").read_text())
        lines = fingerprint(refs, self.repositories, "abc", resolve=self.resolve)
        self.assertEqual(lines[0], "hif-regression abc")
        self.assertEqual([line.split()[0] for line in lines[1:]], list(refs))
        self.assertEqual(len(self.resolved), len(refs))

    def test_a_moved_branch_changes_it(self):
        refs = {"hif-core": "develop"}
        before = fingerprint(refs, self.repositories, "abc", resolve=lambda url, ref: "1" * 40)
        after = fingerprint(refs, self.repositories, "abc", resolve=lambda url, ref: "2" * 40)
        self.assertNotEqual(before, after)

    def test_this_repository_moving_changes_it(self):
        refs = {"hif-core": "develop"}
        same = lambda url, ref: "1" * 40  # noqa: E731
        self.assertNotEqual(fingerprint(refs, self.repositories, "abc", resolve=same),
                            fingerprint(refs, self.repositories, "def", resolve=same))

    def test_stable_tags_resolve_through_the_same_path(self):
        refs = yaml.safe_load((ROOT / "manifests" / "stable.yaml").read_text())
        fingerprint(refs, self.repositories, "abc", resolve=self.resolve)
        self.assertTrue(all(ref.startswith("v") for _, ref in self.resolved))


if __name__ == "__main__":
    unittest.main()
