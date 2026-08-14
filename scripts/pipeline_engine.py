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
            artifact_ok = artifact_path.exists()
        except ArtifactResolutionError as exc:
            artifact_error = str(exc)

    status = classify(r, artifact_ok)
    record = {"status": status, **trim_result(r)}
    if artifact_error:
        record["artifact_error"] = artifact_error
    return status, artifact_path, record


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
        return [artifacts[previous_id]]

    resolved = []
    for ref in refs:
        ref_id = ref["from"] if isinstance(ref, dict) else ref
        if ref_id not in artifacts:
            raise ManifestError(
                f"pipeline '{pipeline_name}', operation '{op['id']}': "
                f"references '{ref_id}', which produced no artifact"
            )
        resolved.append(artifacts[ref_id])
    return resolved


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
            status, record = run_simulation(
                op, registries, bin_dir, artifacts, op_work, name, timeout_s, design
            )
            artifacts[("simulation", op_id)] = record
        elif kind == "validation":
            status, record, cases = run_validation(op, registries, artifacts, design)
            behavioral.extend(cases)
        else:  # unreachable - validate_pipelines rejects unknown kinds
            raise ManifestError(f"pipeline '{pipeline_name}': unknown kind '{kind}'")

        stages[op_id] = record
        previous_id = op_id
        if status != "PASS":
            break

    return {"stages": stages, "behavioral": behavioral,
            "overall_status": _worst_status(stages)}
