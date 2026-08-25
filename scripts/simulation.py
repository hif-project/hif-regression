"""
Generic simulation execution for hif-regression.

A simulation operation compiles/elaborates once and then executes N runs of
that same compiled artifact, each with its own parameters and its own trace
artifact. That structure is the point: it is what stops a fault campaign from
recompiling one netlist per fault, and it is equally what would let a future
C++ backend flow compile with g++ once and execute the binary repeatedly.

This module decides nothing about pass/fail beyond "did the simulator run" -
comparing traces is validation's job (see validators.py), deliberately kept
separate so a behavioral failure says whether the simulator or the expectation
was at fault.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from placeholders import ManifestError, expand_argv  # noqa: E402
from record_lookup import is_lookup, resolve_record  # noqa: E402
from toolchain_classify import classify, find_tool, run_tool, trim_result  # noqa: E402


def resolve_params(params, artifacts, context):
    """Run parameters are literals, or a generic lookup into an earlier
    operation's JSON artifact (see record_lookup). Nothing here knows what the
    parameter means to the design."""
    resolved = {}
    for key, value in (params or {}).items():
        if not is_lookup(value):
            resolved[key] = value
            continue
        source_id = value["from"]
        artifact = artifacts.get(source_id)
        if artifact is None:
            raise ManifestError(
                f"{context}: parameter '{key}' reads from operation '{source_id}', "
                f"which produced no artifact (available: {sorted(str(k) for k in artifacts)})"
            )
        if len(artifact) != 1:
            raise ManifestError(
                f"{context}: parameter '{key}' reads from operation '{source_id}', "
                f"which produced {len(artifact)} files; a record lookup needs exactly one"
            )
        document = json.loads(Path(artifact[0]).read_text())
        resolved[key] = resolve_record(
            document, value["array"], value["where"], value["take"],
            f"{context}, parameter '{key}'",
        )
    return resolved


def _collect_sources(op, artifacts, design, context):
    """Sources are earlier operations' artifacts, per-design fixtures, or the
    design's own sources - named by role, so one shared pipeline serves designs
    whose files differ."""
    sources = []
    for entry in op.get("sources", []):
        if not isinstance(entry, dict):
            raise ManifestError(f"{context}: each 'sources' entry must be a mapping, got {entry!r}")
        if "from" in entry:
            artifact = artifacts.get(entry["from"])
            if artifact is None:
                raise ManifestError(
                    f"{context}: sources reference operation '{entry['from']}', "
                    f"which produced no artifact")
            # An operation's artifact may be several files - hif2verilog emits
            # one `.v` per design unit, so a hierarchy that survived to the
            # emitter arrives here as a file per module. The simulator compiles
            # all of them.
            sources.extend(Path(a) for a in artifact)
        elif "fixture" in entry:
            sources.append(design.fixture(entry["fixture"], context))
        elif entry.get("design") == "sources":
            sources.extend(design.sources)
        else:
            raise ManifestError(f"{context}: unrecognised sources entry {entry!r}")
    return sources


def run_simulation(op, registries, bin_dir, artifacts, workdir, name, timeout_s, design):
    op_id = op["id"]
    context = f"simulation operation '{op_id}'"
    sim = registries["simulators"].get(op["use"])
    if sim is None:
        raise ManifestError(f"{context}: unknown simulator '{op['use']}' "
                            f"(known: {sorted(registries['simulators'])})")

    workdir.mkdir(parents=True, exist_ok=True)
    sim_timeout = sim.get("timeout_s", timeout_s)
    record = {"kind": "simulation", "use": op["use"], "runs": {}}

    scalars = {"workdir": str(workdir), "name": name,
               "top": str(op.get("top", "{name}_tb")).format(name=name)}
    sources = _collect_sources(op, artifacts, design, context)

    compiled = None
    compile_phase = sim.get("compile")
    if compile_phase:
        define_template = compile_phase.get("define_template", "-D{value}")
        lists = {
            "sources": [str(p) for p in sources],
            "options": list(compile_phase.get("options", [])),
            "defines": [define_template.format(value=d) for d in op.get("defines", [])],
        }
        binary = find_tool(compile_phase["command"][0], bin_dir)
        argv = [binary] + expand_argv(compile_phase["command"][1:], scalars, lists, context)
        result = run_tool(argv, cwd=workdir, timeout_s=sim_timeout)

        artifact_ok = False
        if not result["timed_out"] and result["returncode"] == 0:
            compiled = Path(compile_phase["artifact"].format(**scalars))
            artifact_ok = compiled.exists()
        status = classify(result, artifact_ok)
        record["compile"] = {"status": status, "phase": "compile", **trim_result(result)}
        if status != "PASS":
            # `phase` names where execution stopped, which is what makes a
            # failure attributable to compilation rather than to execution.
            record["phase"] = "compile"
            record["status"] = status
            return status, record

    record["phase"] = "run"
    run_phase = sim["run"]
    worst = "PASS"
    for run in op["_runs"]:
        run_id = run["id"]
        rundir = workdir / run_id
        rundir.mkdir(parents=True, exist_ok=True)
        run_context = f"{context}, run '{run_id}'"

        params = resolve_params(run.get("params"), artifacts, run_context)
        run_scalars = dict(scalars)
        run_scalars["rundir"] = str(rundir)
        run_scalars["compiled"] = str(compiled) if compiled else ""
        run_scalars["trace"] = run_phase["artifact"].format(**run_scalars)

        param_template = run_phase.get("param_template", "{key}={value}")
        lists = {"params": [param_template.format(key=k, value=v) for k, v in params.items()]}

        binary = find_tool(run_phase["command"][0], bin_dir)
        argv = [binary] + expand_argv(run_phase["command"][1:], run_scalars, lists, run_context)
        result = run_tool(argv, cwd=rundir, timeout_s=sim_timeout)

        trace = Path(run_scalars["trace"])
        artifact_ok = (not result["timed_out"] and result["returncode"] == 0 and trace.exists())
        status = classify(result, artifact_ok)

        # What each declarative lookup actually selected, so the report can show
        # both the stable selector and the numeric id it resolved to.
        selections = {
            k: {"where": v["where"], "resolved": params[k]}
            for k, v in (run.get("params") or {}).items() if is_lookup(v)
        }
        record["runs"][run_id] = {
            "status": status, "phase": "run", "params": params,
            "selections": selections, "trace": str(trace), **trim_result(result),
        }
        if status != "PASS":
            worst = status

    record["status"] = worst
    return worst, record
