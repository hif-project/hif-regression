#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Build the HIF toolchain (hif-core -> hif-frontend -> hif-backend -> hif-muffin)
# from scratch, into an isolated workspace, from an explicit ref manifest.
#
# Does NOT rely on any pre-existing sibling checkout/build directories on the
# machine it runs on - every run starts from fresh clones at the pinned refs.
#
# Usage:
#   scripts/build_toolchain.sh [--manifest stable|develop|<path>]
#                              [--build-type Release|Debug]
#                              [--workspace <dir>]
#                              [--parallel <n>]
#
# Defaults: --manifest develop --build-type Release --parallel 2
#           --workspace <repo-root>/.workspace
#
# On success, writes <workspace>/toolchain.env with WORKSPACE/PREFIX/BUILD_TYPE
# so downstream steps (running each repo's ctest, the regression runner, the
# nightly workflow) can `source` it instead of re-deriving paths.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MANIFEST="develop"
BUILD_TYPE="Release"
WORKSPACE="$ROOT/.workspace"
PARALLEL=2
GITHUB_ORG="${HIF_REGRESSION_GITHUB_ORG:-esd-univr}"
REPOS=(hif-core hif-frontend hif-backend hif-muffin)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        --build-type) BUILD_TYPE="$2"; shift 2 ;;
        --workspace) WORKSPACE="$2"; shift 2 ;;
        --parallel) PARALLEL="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

case "$BUILD_TYPE" in
    Release|Debug) ;;
    *) echo "--build-type must be 'Release' or 'Debug', got '$BUILD_TYPE'" >&2; exit 1 ;;
esac

case "$MANIFEST" in
    stable|develop) MANIFEST_PATH="$ROOT/manifests/$MANIFEST.env" ;;
    *) MANIFEST_PATH="$MANIFEST" ;;
esac
if [[ ! -f "$MANIFEST_PATH" ]]; then
    echo "Manifest not found: $MANIFEST_PATH" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$MANIFEST_PATH"
for var in HIF_CORE_REF HIF_FRONTEND_REF HIF_BACKEND_REF HIF_MUFFIN_REF; do
    if [[ -z "${!var:-}" ]]; then
        echo "Manifest $MANIFEST_PATH does not define $var" >&2
        exit 1
    fi
done

for tool in git cmake g++ flex bison; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found on PATH: $tool" >&2
        exit 1
    fi
done

echo "== hif-regression: build_toolchain =="
echo "manifest:    $MANIFEST_PATH"
echo "build type:  $BUILD_TYPE"
echo "parallel:    $PARALLEL"
echo "workspace:   $WORKSPACE"
echo "refs:        hif-core=$HIF_CORE_REF hif-frontend=$HIF_FRONTEND_REF hif-backend=$HIF_BACKEND_REF hif-muffin=$HIF_MUFFIN_REF"
echo

rm -rf "$WORKSPACE"
mkdir -p "$WORKSPACE"
PREFIX="$WORKSPACE/install"
mkdir -p "$PREFIX"

clone_ref() {
    local name="$1" ref="$2" dest="$3"
    echo "-- cloning $name @ $ref"
    git init -q "$dest"
    git -C "$dest" remote add origin "https://github.com/$GITHUB_ORG/$name.git"
    git -C "$dest" fetch --depth 1 origin "$ref"
    git -C "$dest" checkout -q FETCH_HEAD
}

declare -A REF_FOR=(
    [hif-core]="$HIF_CORE_REF"
    [hif-frontend]="$HIF_FRONTEND_REF"
    [hif-backend]="$HIF_BACKEND_REF"
    [hif-muffin]="$HIF_MUFFIN_REF"
)

for repo in "${REPOS[@]}"; do
    clone_ref "$repo" "${REF_FOR[$repo]}" "$WORKSPACE/$repo"
done

# hif-core has no HIF dependency of its own; the other three all discover it
# via cmake/FindHIF.cmake, deterministically pointed at the shared prefix
# with -DHIF_DIR (checked before any sibling-relative-path fallback).
# NOTE: -DCMAKE_INSTALL_PREFIX is silently ignored by every repo's top-level
# CMakeLists.txt (plain `set()`, no CACHE) - only `cmake --install --prefix`
# actually redirects the install location.
for repo in "${REPOS[@]}"; do
    echo
    echo "== building $repo =="
    extra_args=()
    if [[ "$repo" != "hif-core" ]]; then
        extra_args+=(-DHIF_DIR="$PREFIX")
    fi
    cmake -S "$WORKSPACE/$repo" -B "$WORKSPACE/$repo/build" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" "${extra_args[@]}"
    cmake --build "$WORKSPACE/$repo/build" --parallel "$PARALLEL"
    cmake --install "$WORKSPACE/$repo/build" --prefix "$PREFIX"
done

cat > "$WORKSPACE/toolchain.env" <<EOF
WORKSPACE=$WORKSPACE
PREFIX=$PREFIX
BUILD_TYPE=$BUILD_TYPE
HIF_CORE_REF=$HIF_CORE_REF
HIF_FRONTEND_REF=$HIF_FRONTEND_REF
HIF_BACKEND_REF=$HIF_BACKEND_REF
HIF_MUFFIN_REF=$HIF_MUFFIN_REF
EOF

echo
echo "== build_toolchain: done =="
echo "install prefix: $PREFIX"
echo "sibling build dirs: $WORKSPACE/<repo>/build"
echo "wrote: $WORKSPACE/toolchain.env"
