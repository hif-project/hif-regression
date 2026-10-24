#!/usr/bin/env python3
"""
What a nightly run would test, as one line per repository.

The floating-develop nightly builds the refs of manifests/<manifest>.yaml from
the repositories in manifests/repositories.yaml, plus this repository's own
engine, tests and corpus. If none of those commits moved since the last green
run, running again would test exactly the same code. This prints

    hif-regression <sha>
    hif-core <sha>
    ...

so the workflow can hash it and skip the run when the hash matches the last
green one. It only resolves refs (`git ls-remote`); it clones nothing.

    scripts/nightly_fingerprint.py [--manifest develop|stable|<path>] [--self-sha SHA]
"""
import argparse
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def ls_remote(url: str, ref: str) -> str:
    """The commit `ref` points to in `url`: a branch, else a (peeled) tag, else
    `ref` itself when it already is a full commit id."""
    for pattern in (f"refs/heads/{ref}", f"refs/tags/{ref}^{{}}", f"refs/tags/{ref}"):
        out = subprocess.run(["git", "ls-remote", url, pattern], capture_output=True,
                             text=True, check=True).stdout.split()
        if out:
            return out[0]
    if len(ref) == 40 and all(c in "0123456789abcdef" for c in ref):
        return ref
    raise LookupError(f"{url}: no branch or tag named {ref!r}")


def fingerprint(refs: dict, repositories: dict, self_sha: str, resolve=ls_remote) -> list:
    """One `name sha` line per repository, this repository first, then the
    manifest order (which is what the build follows)."""
    lines = [f"hif-regression {self_sha}"]
    for name, ref in refs.items():
        lines.append(f"{name} {resolve(repositories[name]['repository'], str(ref))}")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--manifest", default="develop")
    parser.add_argument("--self-sha", default=None,
                        help="commit of this repository (default: git rev-parse HEAD)")
    args = parser.parse_args()
    manifest = Path(args.manifest)
    if not manifest.exists():
        manifest = ROOT / "manifests" / f"{args.manifest}.yaml"
    refs = yaml.safe_load(manifest.read_text())
    repositories = yaml.safe_load((ROOT / "manifests" / "repositories.yaml").read_text())
    self_sha = args.self_sha or subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                               capture_output=True, text=True, check=True).stdout.strip()
    print("\n".join(fingerprint(refs, repositories, self_sha)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
