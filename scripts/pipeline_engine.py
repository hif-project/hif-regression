"""
Generic pipeline execution engine for hif-regression.

Reads the capability registries (manifests/tools.yaml, simulators.yaml,
validators.yaml) and manifests/pipelines.yaml (named, ordered operation
sequences), and executes a named pipeline against a design's source files.

An operation is one of three kinds - `tool`, `simulation` or `validation` -
and dispatch happens on that kind alone. This module has no knowledge of any
individual tool, simulator or validator: adding a new one is a manifest
change, and adding a new *kind* of execution is the only thing that would
touch this file.

Execution is strictly top-to-bottom. There is no dependency resolution, no
topological sort and no parallelism - an operation may reference earlier
operations by id, which is enough to make data flow explicit without becoming
a workflow engine.
"""
import glob as globmod
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from manifest_schema import validate_pipelines  # noqa: E402
from placeholders import ManifestError, expand_argv  # noqa: E402
from simulation import run_simulation  # noqa: E402
from toolchain_classify import (  # noqa: E402
    STATUS_SEVERITY,
    classify,
    find_tool,
    run_tool,
    trim_result,
)
from validators import run_validation  # noqa: E402


class ArtifactResolutionError(Exception):
    pass


def load_tools(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def load_pipelines(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def load_yaml_manifest(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def check_artifact(path: Path):
    """An operation that declares an artifact has not succeeded until that
    artifact exists *and* has content.

    Existence alone is not enough. A producer can fail after creating its
    output file and leave it empty - hif2verilog does exactly this when it
    aborts partway through printing (hif-backend#23) - and an empty file is
    happily consumed by the next operation. An empty `.v` is valid Verilog
    that reparses cleanly, so a downstream "did it reparse?" check reports
    PASS on a design that was silently lost.

    Returns (ok, reason). `reason` is None when ok.
    """
    if not path.exists():
        return False, f"declared artifact was not produced: {path}"
    if path.is_dir():
        return False, f"declared artifact is a directory, expected a file: {path}"
    if path.stat().st_size == 0:
        return False, (
            f"declared artifact is empty (0 bytes): {path} - the operation exited 0 but "
            f"produced nothing, so anything consuming it would be working from an empty file"
        )
    return True, None


def resolve_artifact(template: str, context: dict) -> Path:
    pattern = template.format(**context)
    if "*" in pattern or "?" in pattern:
        matches = sorted(Path(p) for p in globmod.glob(pattern))
        if len(matches) != 1:
            raise ArtifactResolutionError(
                f"artifact pattern '{pattern}' matched {len(matches)} file(s), expected exactly 1"
            )
        return matches[0]
    return Path(pattern)


def run_step(tool_id: str, tools: dict, bin_dir, inputs: list, workdir: Path, name: str, timeout_s: int):
    tool_def = tools[tool_id]
    workdir.mkdir(parents=True, exist_ok=True)
    context = {"input": str(inputs[0]), "workdir": str(workdir), "name": name}
    binary = find_tool(tool_def["command"][0], bin_dir)
    argv = [binary] + expand_argv(
        tool_def["command"][1:],
        context,
        {"inputs": [str(p) for p in inputs]},
        f"tool '{tool_id}'",
    )

    r = run_tool(argv, cwd=workdir, timeout_s=timeout_s)

    artifact_path = None
    artifact_ok = False
    artifact_error = None
    if not r["timed_out"] and r["returncode"] == 0:
        try:
            artifact_path = resolve_artifact(tool_def["artifact"], context)
            artifact_ok, artifact_error = check_artifact(artifact_path)
        except ArtifactResolutionError as exc:
            artifact_error = str(exc)

    status = classify(r, artifact_ok)
    record = {"status": status, **trim_result(r)}
    if artifact_error:
        record["artifact_error"] = artifact_error
    # Hand back an artifact only when it passed the check. The pipeline also
    # stops at the first non-PASS, so today nothing downstream would run
    # anyway - but that makes "a rejected artifact is never consumed" a
    # consequence of the loop's control flow rather than a property of the
    # data. Returning None keeps it true regardless.
    return status, (artifact_path if artifact_ok else None), record


def _worst_status(stages: dict) -> str:
    if not stages:
        return "PASS"
    return max(stages.values(), key=lambda s: STATUS_SEVERITY[s["status"]])["status"]


def resolve_inputs(op, artifacts, previous_id, sources, pipeline_name):
    """An operation with no explicit 'inputs' consumes its predecessor's
    artifact - which keeps linear pipelines terse - and the first operation
    consumes the design's own sources. An explicit reference names an earlier
    operation, which is what a former probe becomes."""
    refs = op.get("inputs")
    if not refs:
        if previous_id is None:
            return list(sources)
        if artifacts.get(previous_id) is None:
            raise ManifestError(
                f"pipeline '{pipeline_name}', operation '{op['id']}': "
                f"its predecessor '{previous_id}' produced no usable artifact"
            )
        return [artifacts[previous_id]]

    resolved = []
    for ref in refs:
        ref_id = ref["from"] if isinstance(ref, dict) else ref
        # `is None` matters as much as absence: an operation that ran but
        # whose artifact was rejected (missing, empty, a directory) records a
        # None, and must not be silently consumed as though it had produced
        # something.
        if artifacts.get(ref_id) is None:
            raise ManifestError(
                f"pipeline '{pipeline_name}', operation '{op['id']}': "
                f"references '{ref_id}', which produced no usable artifact"
            )
        resolved.append(artifacts[ref_id])
    return resolved


def _from_spec(value, design, kind, op_id):
    """`runs`/`cases` are either a literal list or {from_spec: <key>}, which
    reads the list from the design's behavior.yaml. This is what lets one
    shared pipeline serve many designs whose fault cases differ. The engine
    performs a list lookup and attaches no meaning to the contents."""
    if isinstance(value, list):
        return value
    if isinstance(value, dict) and "from_spec" in value:
        key = value["from_spec"]
        if design is None:
            raise ManifestError(
                f"operation '{op_id}': '{kind}: {{from_spec: {key}}}' requires a "
                f"design with a behavior.yaml")
        entries = design.behavior.get(key)
        if entries is None:
            raise ManifestError(
                f"operation '{op_id}': design '{design.category}/{design.name}' "
                f"behavior.yaml has no '{key}' list (has: {sorted(design.behavior)})")
        return entries
    raise ManifestError(
        f"operation '{op_id}': '{kind}' must be a list or {{from_spec: <key>}}")


def run_pipeline(
    pipeline_name: str,
    pipelines: dict,
    registries: dict,
    bin_dir,
    sources: list,
    work_root: Path,
    name: str,
    timeout_s: int,
    design=None,
):
    """Executes a named pipeline's operations strictly in order, stopping at
    the first non-PASS. Dispatch is on `kind` alone - this function has no
    knowledge of any individual tool, simulator or validator."""
    validate_pipelines(pipelines, "manifests/pipelines.yaml")
    pipeline = pipelines["pipelines"][pipeline_name]

    stages = {}
    artifacts = {}
    behavioral = []
    previous_id = None

    for op in pipeline["operations"]:
        op_id = op["id"]
        kind = op["kind"]
        op_work = work_root / op_id

        if kind == "tool":
            inputs = resolve_inputs(op, artifacts, previous_id, sources, pipeline_name)
            status, artifact_path, record = run_step(
                op["use"], registries["tools"], bin_dir, inputs, op_work, name, timeout_s
            )
            record["kind"] = "tool"
            record["phase"] = "execute"
            artifacts[op_id] = artifact_path
        elif kind == "simulation":
            resolved = dict(op, _runs=_from_spec(op.get("runs", []), design, "runs", op_id))
            status, record = run_simulation(
                resolved, registries, bin_dir, artifacts, op_work, name, timeout_s, design
            )
            artifacts[("simulation", op_id)] = record
        elif kind == "validation":
            resolved = dict(op, _cases=_from_spec(op.get("cases", []), design, "cases", op_id))
            status, record, cases = run_validation(resolved, registries, artifacts, design)
            behavioral.extend(cases)
        else:  # unreachable - validate_pipelines rejects unknown kinds
            raise ManifestError(f"pipeline '{pipeline_name}': unknown kind '{kind}'")

        stages[op_id] = record
        previous_id = op_id
        if status != "PASS":
            break

    return {"stages": stages, "behavioral": behavioral,
            "overall_status": _worst_status(stages)}
