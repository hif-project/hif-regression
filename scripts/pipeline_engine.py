"""
Generic pipeline execution engine for hif-regression.

Reads manifests/tools.yaml (capability registry: command + artifact
templates) and manifests/pipelines.yaml (named step sequences + optional
probes), and executes a named pipeline against a design's source files,
producing the same per-stage PASS/CLEAN_REJECT/CRASH/TIMEOUT classification
run_regression.py always has - just driven by data instead of per-tool
Python branches. Adding a new tool or pipeline is a manifest change; this
module has no tool-specific knowledge.
"""
import glob as globmod
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from toolchain_classify import (  # noqa: E402
    STATUS_SEVERITY,
    classify,
    find_tool,
    run_tool,
    trim_result,
)


class ArtifactResolutionError(Exception):
    pass


def load_tools(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def load_pipelines(path: Path) -> dict:
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


def build_argv(command_template: list, context: dict, inputs: list) -> list:
    argv = []
    for token in command_template:
        if token == "{inputs}":
            argv.extend(str(p) for p in inputs)
        else:
            argv.append(token.format(**context))
    return argv


def run_step(tool_id: str, tools: dict, bin_dir, inputs: list, workdir: Path, name: str, timeout_s: int):
    tool_def = tools[tool_id]
    workdir.mkdir(parents=True, exist_ok=True)
    context = {"input": str(inputs[0]), "workdir": str(workdir), "name": name}
    binary = find_tool(tool_def["command"][0], bin_dir)
    argv = [binary] + build_argv(tool_def["command"][1:], context, inputs)

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


def run_pipeline(
    pipeline_name: str,
    pipelines: dict,
    tools: dict,
    bin_dir,
    sources: list,
    work_root: Path,
    name: str,
    timeout_s: int,
):
    """Runs a named pipeline's main steps (stopping at the first non-PASS),
    then - only if every main step passed - its probes (stopping at the
    first non-PASS probe). Returns {"stages": {step_id: {...}}, "overall_status": ...}."""
    pipeline = pipelines["pipelines"][pipeline_name]
    stages = {}
    step_artifacts = {}
    current_inputs = list(sources)

    all_main_passed = True
    for step in pipeline["steps"]:
        step_id = step["id"]
        status, artifact_path, record = run_step(
            step["tool"], tools, bin_dir, current_inputs, work_root / step_id, name, timeout_s
        )
        stages[step_id] = record
        step_artifacts[step_id] = artifact_path
        if status != "PASS":
            all_main_passed = False
            break
        current_inputs = [artifact_path]

    if all_main_passed:
        for probe in pipeline.get("probes", []):
            after_id = probe["after"]
            tool_id = probe["tool"]
            probe_input = step_artifacts.get(after_id)
            if probe_input is None:
                raise SystemExit(f"pipeline '{pipeline_name}': probe references unknown step id '{after_id}'")
            status, _artifact_path, record = run_step(
                tool_id, tools, bin_dir, [probe_input], work_root / f"probe_{tool_id}", name, timeout_s
            )
            stages[tool_id] = record
            if status != "PASS":
                break

    return {"stages": stages, "overall_status": _worst_status(stages)}
