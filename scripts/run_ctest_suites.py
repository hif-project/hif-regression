#!/usr/bin/env python3
"""
Run each repo's own CTest suite (from manifests/repositories.yaml, so the
list of repos lives in exactly one place) against an already-built
workspace. Every repo runs regardless of whether an earlier one failed -
one repo's own regression should not hide whether the others are healthy -
and the script fails at the end if any of them did.
"""
import argparse
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True, help="workspace dir written by build_toolchain.py")
    parser.add_argument("--repositories", default=str(ROOT / "manifests" / "repositories.yaml"))
    args = parser.parse_args()

    repositories = yaml.safe_load(Path(args.repositories).read_text())
    workspace = Path(args.workspace)

    failed = []
    for name in repositories:
        build_dir = workspace / name / "build"
        print(f"::group::ctest {name}")
        result = subprocess.run(["ctest", "--test-dir", str(build_dir), "--output-on-failure"])
        print("::endgroup::")
        if result.returncode != 0:
            failed.append(name)

    if failed:
        print(f"CTest failed for: {', '.join(failed)}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
