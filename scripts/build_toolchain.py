#!/usr/bin/env python3
"""
Build the HIF toolchain from scratch, into an isolated workspace, from an
explicit ref manifest (manifests/stable.yaml or manifests/develop.yaml) and
the build graph in manifests/repositories.yaml.

Does NOT rely on any pre-existing sibling checkout/build directory on the
machine it runs on - every run starts from fresh clones at the pinned refs.

Usage:
    scripts/build_toolchain.py [--manifest stable|develop|<path>]
                               [--build-type Release|Debug]
                               [--workspace <dir>]
                               [--parallel <n>]

Defaults: --manifest develop --build-type Release --parallel 2
          --workspace <repo-root>/.workspace

On success, writes <workspace>/toolchain.env with WORKSPACE/PREFIX/BUILD_TYPE
so downstream steps (running each repo's ctest, the regression runner, the
nightly workflow) can `source` it instead of re-deriving paths.

Build order comes from a topological sort of repositories.yaml's
depends_on, not the file's insertion order or a hardcoded list - adding a
future tool there is enough, no script change needed.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
REQUIRED_TOOLS = ["git", "cmake", "g++", "flex", "bison"]


def load_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def topological_order(repositories: dict) -> list:
    """Kahn's algorithm - deterministic (ties broken by manifest order),
    and errors clearly on an unknown dependency or a real cycle."""
    remaining = {name: list(info["depends_on"]) for name, info in repositories.items()}
    for name, deps in remaining.items():
        for dep in deps:
            if dep not in repositories:
                raise SystemExit(f"{name}: depends_on unknown repository '{dep}'")

    order = []
    while remaining:
        ready = [name for name, deps in remaining.items() if not deps]
        if not ready:
            raise SystemExit(f"repositories.yaml has a dependency cycle among: {sorted(remaining)}")
        for name in ready:
            order.append(name)
            del remaining[name]
        for deps in remaining.values():
            for name in ready:
                if name in deps:
                    deps.remove(name)
    return order


def resolve_manifest_path(manifest_arg: str) -> Path:
    if manifest_arg in ("stable", "develop"):
        return ROOT / "manifests" / f"{manifest_arg}.yaml"
    return Path(manifest_arg)


def check_required_tools():
    import shutil
    missing = [t for t in REQUIRED_TOOLS if shutil.which(t) is None]
    if missing:
        raise SystemExit(f"Required tool(s) not found on PATH: {', '.join(missing)}")


def run(argv, **kwargs):
    subprocess.run(argv, check=True, **kwargs)


def clone_ref(github_org: str, name: str, ref: str, dest: Path):
    print(f"-- cloning {name} @ {ref}")
    run(["git", "init", "-q", str(dest)])
    run(["git", "-C", str(dest), "remote", "add", "origin", f"https://github.com/{github_org}/{name}.git"])
    run(["git", "-C", str(dest), "fetch", "--depth", "1", "origin", ref])
    run(["git", "-C", str(dest), "checkout", "-q", "FETCH_HEAD"])


def build_one(name: str, info: dict, workspace: Path, prefix: Path, build_type: str, parallel: int):
    print(f"\n== building {name} ==")
    src = workspace / name
    build_dir = src / "build"
    cmake_args = [arg.format(prefix=prefix) for arg in info["cmake_args_template"]]
    run(["cmake", "-S", str(src), "-B", str(build_dir), f"-DCMAKE_BUILD_TYPE={build_type}", *cmake_args])
    run(["cmake", "--build", str(build_dir), "--parallel", str(parallel)])
    run(["cmake", "--install", str(build_dir), "--prefix", str(prefix)])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", default="develop")
    parser.add_argument("--build-type", default="Release", choices=["Release", "Debug"])
    parser.add_argument("--workspace", default=str(ROOT / ".workspace"))
    parser.add_argument("--parallel", type=int, default=2)
    args = parser.parse_args()

    manifest_path = resolve_manifest_path(args.manifest)
    if not manifest_path.exists():
        raise SystemExit(f"Manifest not found: {manifest_path}")
    refs = load_yaml(manifest_path)

    repositories = load_yaml(ROOT / "manifests" / "repositories.yaml")
    for name in repositories:
        if name not in refs:
            raise SystemExit(f"{manifest_path} does not define a ref for '{name}'")

    check_required_tools()

    build_order = topological_order(repositories)
    github_org = os.environ.get("HIF_REGRESSION_GITHUB_ORG", "esd-univr")

    workspace = Path(args.workspace).resolve()
    prefix = workspace / "install"

    print("== hif-regression: build_toolchain ==")
    print(f"manifest:    {manifest_path}")
    print(f"build type:  {args.build_type}")
    print(f"parallel:    {args.parallel}")
    print(f"workspace:   {workspace}")
    print(f"build order: {' -> '.join(build_order)}")
    print(f"refs:        {', '.join(f'{n}={refs[n]}' for n in build_order)}")
    print()

    if workspace.exists():
        run(["rm", "-rf", str(workspace)])
    workspace.mkdir(parents=True)
    prefix.mkdir(parents=True)

    for name in build_order:
        clone_ref(github_org, name, refs[name], workspace / name)

    # hif-core has no HIF dependency of its own (empty cmake_args_template);
    # the rest discover it via cmake/FindHIF.cmake, deterministically pointed
    # at the shared prefix with -DHIF_DIR (checked before any sibling-
    # relative-path fallback). NOTE: -DCMAKE_INSTALL_PREFIX is silently
    # ignored by every repo's top-level CMakeLists.txt (plain set(), no
    # CACHE) - only `cmake --install --prefix` actually redirects it.
    for name in build_order:
        build_one(name, repositories[name], workspace, prefix, args.build_type, args.parallel)

    toolchain_env = workspace / "toolchain.env"
    with open(toolchain_env, "w") as f:
        f.write(f"WORKSPACE={workspace}\n")
        f.write(f"PREFIX={prefix}\n")
        f.write(f"BUILD_TYPE={args.build_type}\n")
        for name in build_order:
            f.write(f"{name.upper().replace('-', '_')}_REF={refs[name]}\n")

    print("\n== build_toolchain: done ==")
    print(f"install prefix: {prefix}")
    print(f"sibling build dirs: {workspace}/<repo>/build")
    print(f"wrote: {toolchain_env}")


if __name__ == "__main__":
    main()
