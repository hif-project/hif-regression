"""
Early, explicit validation of hif-regression's manifests.

A malformed manifest should fail with a message naming the file, the pipeline
and the operation - not with a KeyError three layers into execution, after a
toolchain build has already run. Everything here is structural: it checks
shape and cross-references, never whether a tool actually works.
"""
from placeholders import ManifestError

KINDS = ("tool", "simulation", "validation")
KNOWN_IMPLS = ("artifact_equal", "artifact_differs", "artifact_equals_fixture")
LEGACY_KEYS = ("steps", "probes")


def _require(condition, message):
    if not condition:
        raise ManifestError(message)


def validate_pipelines(doc, path):
    pipelines = doc.get("pipelines")
    _require(isinstance(pipelines, dict), f"{path}: missing top-level 'pipelines' mapping")

    for name, pipeline in pipelines.items():
        where = f"{path}: pipeline '{name}'"
        for legacy in LEGACY_KEYS:
            _require(
                legacy not in pipeline,
                f"{where}: '{legacy}' is no longer supported - it was replaced by a "
                f"single ordered 'operations' list. A former probe becomes an "
                f"operation with an explicit 'inputs: [<step_id>]'.",
            )

        operations = pipeline.get("operations")
        _require(isinstance(operations, list) and operations,
                 f"{where}: needs a non-empty 'operations' list")

        seen = []
        for index, op in enumerate(operations):
            op_where = f"{where}, operation #{index}"
            _require(isinstance(op, dict), f"{op_where}: must be a mapping")
            op_id = op.get("id")
            _require(isinstance(op_id, str) and op_id, f"{op_where}: needs a string 'id'")
            _require(op_id not in seen, f"{where}: duplicate operation id '{op_id}'")

            kind = op.get("kind")
            _require(kind in KINDS,
                     f"{where}, operation '{op_id}': unknown kind '{kind}' "
                     f"(expected one of {list(KINDS)})")

            if kind in ("tool", "simulation"):
                _require(isinstance(op.get("use"), str),
                         f"{where}, operation '{op_id}': kind '{kind}' needs a 'use' "
                         f"naming a registry entry")

            for ref in _referenced_ids(op):
                _require(ref in seen,
                         f"{where}, operation '{op_id}': references '{ref}', which is not an "
                         f"earlier operation (earlier ids: {seen})")
            seen.append(op_id)


def _referenced_ids(op):
    """Every operation id this operation names, so forward references can be
    rejected up front. Ordered execution means a reference may only point
    backwards."""
    refs = []
    for ref in op.get("inputs", []) or []:
        if isinstance(ref, str):
            refs.append(ref)
        elif isinstance(ref, dict) and "from" in ref:
            refs.append(ref["from"])
    for src in op.get("sources", []) or []:
        if isinstance(src, dict) and "from" in src:
            refs.append(src["from"])
    return refs


def validate_simulators(doc, path):
    _require(isinstance(doc, dict) and doc, f"{path}: expected a non-empty mapping of simulators")
    for name, sim in doc.items():
        where = f"{path}: simulator '{name}'"
        _require(isinstance(sim, dict), f"{where}: must be a mapping")
        _require(isinstance(sim.get("run"), dict), f"{where}: needs a 'run' phase")
        for phase_name in ("compile", "run"):
            phase = sim.get(phase_name)
            if phase is None:
                continue
            _require(isinstance(phase.get("command"), list) and phase["command"],
                     f"{where}: '{phase_name}' needs a non-empty 'command' list")
            _require(isinstance(phase.get("artifact"), str),
                     f"{where}: '{phase_name}' needs an 'artifact' template")


def validate_validators(doc, path):
    _require(isinstance(doc, dict) and doc, f"{path}: expected a non-empty mapping of validators")
    for name, validator in doc.items():
        where = f"{path}: validator '{name}'"
        _require(isinstance(validator, dict), f"{where}: must be a mapping")
        impl = validator.get("impl")
        _require(impl in KNOWN_IMPLS,
                 f"{where}: unknown impl '{impl}' (known: {list(KNOWN_IMPLS)}). "
                 f"A genuinely new comparison needs a new impl in scripts/validators.py.")


def validate_behavior(doc, path):
    _require(isinstance(doc, dict), f"{path}: expected a mapping")
    runs = doc.get("runs", []) or []
    expectations = doc.get("expectations", []) or []
    _require(isinstance(runs, list), f"{path}: 'runs' must be a list")
    _require(isinstance(expectations, list), f"{path}: 'expectations' must be a list")

    seen_runs = []
    for index, run in enumerate(runs):
        _require(isinstance(run, dict), f"{path}: run #{index} must be a mapping")
        run_id = run.get("id")
        _require(isinstance(run_id, str) and run_id, f"{path}: run #{index} needs a string 'id'")
        _require(run_id not in seen_runs, f"{path}: duplicate run id '{run_id}'")
        seen_runs.append(run_id)

    seen_cases = []
    for index, case in enumerate(expectations):
        _require(isinstance(case, dict), f"{path}: expectation #{index} must be a mapping")
        case_id = case.get("id")
        _require(isinstance(case_id, str) and case_id,
                 f"{path}: expectation #{index} needs a string 'id'")
        _require(case_id not in seen_cases, f"{path}: duplicate expectation id '{case_id}'")
        _require(isinstance(case.get("use"), str),
                 f"{path}: expectation '{case_id}' needs a 'use' naming a validator")
        seen_cases.append(case_id)
