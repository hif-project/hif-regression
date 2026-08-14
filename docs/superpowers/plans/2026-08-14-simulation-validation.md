# Simulation and Validation Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend hif-regression so pipelines can execute tools, simulate generated artifacts, and validate simulation results as three distinct generic concepts, and expand the curated corpus to 48 designs of which 11 carry real Muffin behavioral acceptance tests.

**Architecture:** `pipelines.yaml` moves from `steps`+`probes` to one ordered `operations` list where each operation declares `id`, `kind` (`tool`/`simulation`/`validation`) and `use`. Execution stays strictly sequential — no DAG, no scheduler. Simulators and validators get their own registries alongside `tools.yaml`. Simulation compiles once and runs many times; fault IDs are resolved by a generic JSON record lookup so nothing Muffin-specific enters the engine.

**Tech Stack:** Python 3 (stdlib + `pyyaml` only), `unittest` for engine tests (deliberately not pytest — no new dependency), Icarus Verilog (`iverilog`/`vvp`) resolved from PATH, CSV traces.

**Spec:** `docs/superpowers/specs/2026-08-14-simulation-validation-design.md`

## Global Constraints

- **No new Python dependencies.** `pyyaml` is the only third-party import. Engine tests use stdlib `unittest`.
- **No simulator vendoring, building, installing, or version-pinning in this repo.** The registry describes invocation only; binaries resolve via the existing `find_tool` (`--bin-dir` then PATH). CI provisioning is a workflow concern.
- **`-g2005`** is the Icarus language flag. Verified sufficient: `hif2verilog` emits `input wire [31:0] muffinMutPort`.
- **No product-specific branching in the engine.** `if tool == "muffin"` or equivalent is a plan failure. The engine knows kinds, registries, placeholders and artifacts — never a HIF tool's name.
- **No `designs/behavioral/` directory.** Behavioral is an orthogonal capability; designs gain it by moving to directory form inside their existing category. No design is duplicated to be simulated.
- **Curated failures are real failures.** Never weaken an expectation to make a fixture pass; fix the fixture.
- **If a genuine Muffin behavioral bug appears, STOP.** Do not modify `hif-muffin`. Report reproducer, expected, actual, artifacts, likely layer.
- **Placeholder semantics are fixed:** scalar `{input} {workdir} {name} {top} {compiled} {trace} {rundir}` substitute within a token; list `{inputs} {sources} {defines} {params} {options}` must be the entire token.
- **Statuses:** `PASS < CLEAN_REJECT < TIMEOUT < FAIL < CRASH`. `FAIL` is produced by validation only.
- **Pre-refactor baseline** is `/tmp/claude-1000/-home-enrico-repository-hif/3e305375-b44f-4cec-bf4b-c5ca4711e22e/scratchpad/baseline-classification.json`: 12 designs, all PASS. Stage keys and order must survive the migration unchanged.
- **Toolchain env** for every run: `source .workspace/toolchain.env && export PATH="$PREFIX/bin:$PATH" && export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"`.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/placeholders.py` | NEW. Scalar/list placeholder expansion into argv, with diagnostics. |
| `scripts/record_lookup.py` | NEW. Generic "one record from a JSON array, take a field" resolver. |
| `scripts/manifest_schema.py` | NEW. Early validation of all four manifests + `behavior.yaml`. |
| `scripts/simulation.py` | NEW. Generic compile-once/run-many simulator executor. |
| `scripts/validators.py` | NEW. Generic comparators + dispatch by `impl`. |
| `scripts/pipeline_engine.py` | MODIFY. Ordered `operations` loop dispatching on `kind`. |
| `scripts/run_regression.py` | MODIFY. Discovery of `sources`/`fixtures`/`behavior.yaml`; behavioral report section. |
| `scripts/report.py` | MODIFY. Behavioral Markdown section. |
| `scripts/toolchain_classify.py` | MODIFY. Add `FAIL` to severity table. |
| `manifests/simulators.yaml` | NEW. |
| `manifests/validators.yaml` | NEW. |
| `manifests/pipelines.yaml` | MODIFY. `operations` model + `muffin_behavioral`. |
| `tests/*.py` | NEW. stdlib unittest for the five engine modules. |
| `designs/**` | Corpus expansion to 48. |
| `docs/adding-things.md` | NEW. How to add a tool/simulator/validator/pipeline/behavioral test. |
| `.github/workflows/nightly.yml` | MODIFY. Provision `iverilog`; run engine unit tests. |

---

### Task 1: Placeholder expansion + FAIL status

**Files:**
- Create: `scripts/placeholders.py`
- Modify: `scripts/toolchain_classify.py:19`
- Test: `tests/test_placeholders.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `expand_argv(template: list[str], scalars: dict[str,str], lists: dict[str,list[str]], where: str) -> list[str]`; raises `ManifestError`. Also `class ManifestError(Exception)`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_placeholders.py
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError, expand_argv


class TestExpandArgv(unittest.TestCase):
    def test_scalar_substitutes_within_token(self):
        argv = expand_argv(["-o", "{workdir}/sim.vvp"], {"workdir": "/w"}, {}, "op x")
        self.assertEqual(argv, ["-o", "/w/sim.vvp"])

    def test_list_placeholder_expands_to_multiple_argv_entries(self):
        argv = expand_argv(["cc", "{sources}"], {}, {"sources": ["a.v", "b.v"]}, "op x")
        self.assertEqual(argv, ["cc", "a.v", "b.v"])

    def test_empty_list_placeholder_disappears(self):
        argv = expand_argv(["cc", "{defines}", "x"], {}, {"defines": []}, "op x")
        self.assertEqual(argv, ["cc", "x"])

    def test_list_placeholder_inside_larger_token_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            expand_argv(["-I{sources}"], {}, {"sources": ["a"]}, "op x")
        self.assertIn("must be the entire token", str(ctx.exception))
        self.assertIn("op x", str(ctx.exception))

    def test_unknown_placeholder_is_an_error_naming_the_token(self):
        with self.assertRaises(ManifestError) as ctx:
            expand_argv(["{nope}"], {"workdir": "/w"}, {}, "op x")
        self.assertIn("nope", str(ctx.exception))
        self.assertIn("op x", str(ctx.exception))

    def test_literal_token_passes_through(self):
        self.assertEqual(expand_argv(["-g2005"], {}, {}, "op x"), ["-g2005"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_placeholders -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'placeholders'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/placeholders.py
"""
Placeholder expansion for hif-regression's argv templates.

Two fixed kinds, deliberately small and non-recursive - this is argv
substitution, not a scripting language:

  scalar - substituted inside a token: {input} {workdir} {name} {top}
           {compiled} {trace} {rundir}
  list   - must be the ENTIRE token, expands to 0..n argv entries:
           {inputs} {sources} {defines} {params} {options}

A list placeholder buried inside a larger token is an error rather than a
silent str(list) coercion, and an unknown placeholder is an error naming the
operation and the offending token. Manifest mistakes should be loud and
locatable, not mysterious argv.
"""
import re

PLACEHOLDER_RE = re.compile(r"\{([a-z_]+)\}")


class ManifestError(Exception):
    pass


def expand_argv(template, scalars, lists, where):
    argv = []
    for token in template:
        names = PLACEHOLDER_RE.findall(token)
        list_names = [n for n in names if n in lists]

        if list_names:
            if len(names) != 1 or token != "{%s}" % list_names[0]:
                raise ManifestError(
                    f"{where}: list placeholder '{{{list_names[0]}}}' must be the "
                    f"entire token, got '{token}'"
                )
            argv.extend(str(v) for v in lists[list_names[0]])
            continue

        unknown = [n for n in names if n not in scalars]
        if unknown:
            raise ManifestError(
                f"{where}: unknown placeholder '{{{unknown[0]}}}' in token '{token}' "
                f"(known scalars: {sorted(scalars)}; known lists: {sorted(lists)})"
            )
        argv.append(token.format(**scalars))
    return argv
```

- [ ] **Step 4: Add FAIL to the severity table**

Modify `scripts/toolchain_classify.py:19` from:

```python
STATUS_SEVERITY = {"PASS": 0, "CLEAN_REJECT": 1, "TIMEOUT": 2, "CRASH": 3}
```

to:

```python
# FAIL is produced by validation only (see validators.py) - a tool that exits
# nonzero is CLEAN_REJECT or CRASH, never FAIL. Ordered above TIMEOUT because a
# behavioral mismatch is a harder result than "didn't finish", and below CRASH
# because a crash means we learned nothing at all.
STATUS_SEVERITY = {"PASS": 0, "CLEAN_REJECT": 1, "TIMEOUT": 2, "FAIL": 3, "CRASH": 4}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 6 tests PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/placeholders.py scripts/toolchain_classify.py tests/test_placeholders.py
git commit -m "feat: fixed placeholder expansion rules and FAIL status"
```

---

### Task 2: Generic JSON record lookup

**Files:**
- Create: `scripts/record_lookup.py`
- Test: `tests/test_record_lookup.py`

**Interfaces:**
- Consumes: `ManifestError` from `placeholders`.
- Produces: `resolve_record(document: dict, array: str, where: dict, take: str, context: str) -> object`; `is_lookup(value) -> bool`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_record_lookup.py
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError
from record_lookup import is_lookup, resolve_record

DOC = {
    "schema_version": 2,
    "faults": [
        {"id": 1, "type": "stuck-at-0", "bit": 0, "signal": "y"},
        {"id": 2, "type": "stuck-at-1", "bit": 0, "signal": "y"},
        {"id": 3, "type": "stuck-at-0", "bit": 1, "signal": "q"},
    ],
}


class TestResolveRecord(unittest.TestCase):
    def test_selects_unique_record_and_takes_field(self):
        got = resolve_record(DOC, "faults", {"signal": "y", "bit": 0, "type": "stuck-at-0"}, "id", "case c")
        self.assertEqual(got, 1)

    def test_numeric_filter_matches_json_number_via_string_compare(self):
        self.assertEqual(resolve_record(DOC, "faults", {"bit": 1}, "id", "case c"), 3)

    def test_zero_matches_is_an_error_listing_the_filter(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "faults", {"signal": "nope"}, "id", "case c")
        self.assertIn("matched 0", str(ctx.exception))
        self.assertIn("case c", str(ctx.exception))

    def test_multiple_matches_is_an_error_listing_candidates(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "faults", {"signal": "y"}, "id", "case c")
        self.assertIn("matched 2", str(ctx.exception))

    def test_missing_array_key_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "nope", {"bit": 0}, "id", "case c")
        self.assertIn("nope", str(ctx.exception))

    def test_missing_take_field_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_record(DOC, "faults", {"bit": 1}, "nosuch", "case c")
        self.assertIn("nosuch", str(ctx.exception))

    def test_is_lookup_detects_the_mapping_form(self):
        self.assertTrue(is_lookup({"from": "enumerate", "array": "faults", "where": {}, "take": "id"}))
        self.assertFalse(is_lookup(0))
        self.assertFalse(is_lookup("golden"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_record_lookup -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'record_lookup'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/record_lookup.py
"""
Generic single-record lookup into a JSON artifact produced by an earlier
operation.

Exists so a behavioral test can name a fault by its stable attributes
(signal/bit/type) instead of a numeric id that legitimately moves whenever a
design's assignments change. The engine therefore never hardcodes a fault id -
and equally never learns what a fault is: this resolves "the one object in
array A whose fields equal W, field T of it" against any JSON document.

Deliberately NOT a query language: equality only, no operators, no nesting, no
expressions. Values compare as strings so `bit: 0` matches JSON `0` without
type-coercion surprises. A filter that does not match exactly one record is a
hard error - an ambiguous selector in a regression fixture is a bug in the
fixture, not something to resolve by picking the first hit.
"""
from placeholders import ManifestError

_LOOKUP_KEYS = {"from", "array", "where", "take"}


def is_lookup(value):
    return isinstance(value, dict) and _LOOKUP_KEYS.issubset(value.keys())


def resolve_record(document, array, where, take, context):
    records = document.get(array)
    if not isinstance(records, list):
        raise ManifestError(
            f"{context}: JSON document has no array '{array}' "
            f"(top-level keys: {sorted(document)})"
        )

    matches = [
        r for r in records
        if all(str(r.get(k)) == str(v) for k, v in where.items())
    ]

    if len(matches) != 1:
        raise ManifestError(
            f"{context}: filter {where} matched {len(matches)} record(s) in "
            f"'{array}', expected exactly 1. Candidates: {records}"
        )

    record = matches[0]
    if take not in record:
        raise ManifestError(
            f"{context}: matched record has no field '{take}' "
            f"(fields: {sorted(record)})"
        )
    return record[take]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 13 tests PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/record_lookup.py tests/test_record_lookup.py
git commit -m "feat: generic JSON record lookup for declarative fault selection"
```

---

### Task 3: Manifest schema validation

**Files:**
- Create: `scripts/manifest_schema.py`
- Test: `tests/test_manifest_schema.py`

**Interfaces:**
- Consumes: `ManifestError`.
- Produces: `validate_pipelines(doc, path)`, `validate_simulators(doc, path)`, `validate_validators(doc, path)`, `validate_behavior(doc, path)`. Each raises `ManifestError` or returns `None`.
- Constant: `KINDS = ("tool", "simulation", "validation")`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_manifest_schema.py
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from manifest_schema import (validate_behavior, validate_pipelines,
                             validate_simulators, validate_validators)
from placeholders import ManifestError

GOOD = {"pipelines": {"p": {"operations": [
    {"id": "frontend", "kind": "tool", "use": "verilog2hif"},
    {"id": "check", "kind": "validation", "cases": {"from_spec": "expectations"}},
]}}}


class TestPipelines(unittest.TestCase):
    def test_accepts_a_well_formed_pipeline(self):
        validate_pipelines(GOOD, "p.yaml")

    def test_legacy_steps_key_is_rejected_with_migration_hint(self):
        doc = {"pipelines": {"p": {"steps": [{"id": "a", "tool": "t"}]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("operations", str(ctx.exception))
        self.assertIn("steps", str(ctx.exception))

    def test_legacy_probes_key_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [], "probes": []}}}
        with self.assertRaises(ManifestError):
            validate_pipelines(doc, "p.yaml")

    def test_duplicate_operation_id_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [
            {"id": "a", "kind": "tool", "use": "t"},
            {"id": "a", "kind": "tool", "use": "t"},
        ]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("duplicate", str(ctx.exception).lower())

    def test_unknown_kind_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [{"id": "a", "kind": "magic", "use": "t"}]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("magic", str(ctx.exception))

    def test_forward_reference_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [
            {"id": "a", "kind": "tool", "use": "t", "inputs": ["later"]},
            {"id": "later", "kind": "tool", "use": "t"},
        ]}}}
        with self.assertRaises(ManifestError) as ctx:
            validate_pipelines(doc, "p.yaml")
        self.assertIn("later", str(ctx.exception))

    def test_tool_operation_without_use_is_rejected(self):
        doc = {"pipelines": {"p": {"operations": [{"id": "a", "kind": "tool"}]}}}
        with self.assertRaises(ManifestError):
            validate_pipelines(doc, "p.yaml")


class TestSimulators(unittest.TestCase):
    def test_accepts_compile_and_run(self):
        validate_simulators({"s": {"compile": {"command": ["x"], "artifact": "a"},
                                   "run": {"command": ["y"], "artifact": "b"}}}, "s.yaml")

    def test_missing_run_phase_is_rejected(self):
        with self.assertRaises(ManifestError) as ctx:
            validate_simulators({"s": {"compile": {"command": ["x"], "artifact": "a"}}}, "s.yaml")
        self.assertIn("run", str(ctx.exception))


class TestValidators(unittest.TestCase):
    def test_accepts_known_impl(self):
        validate_validators({"v": {"impl": "artifact_equal"}}, "v.yaml")

    def test_unknown_impl_is_rejected_listing_known_ones(self):
        with self.assertRaises(ManifestError) as ctx:
            validate_validators({"v": {"impl": "telepathy"}}, "v.yaml")
        self.assertIn("telepathy", str(ctx.exception))
        self.assertIn("artifact_equal", str(ctx.exception))


class TestBehavior(unittest.TestCase):
    def test_accepts_runs_and_expectations(self):
        validate_behavior({"runs": [{"id": "golden", "params": {"mut": 0}}],
                           "expectations": [{"id": "e", "use": "trace_equal",
                                             "left": {"from": "s", "run": "golden"},
                                             "right": {"from": "r", "run": "reference"}}]}, "b.yaml")

    def test_duplicate_run_id_is_rejected(self):
        with self.assertRaises(ManifestError):
            validate_behavior({"runs": [{"id": "g"}, {"id": "g"}], "expectations": []}, "b.yaml")

    def test_expectation_without_use_is_rejected(self):
        with self.assertRaises(ManifestError):
            validate_behavior({"runs": [], "expectations": [{"id": "e"}]}, "b.yaml")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_manifest_schema -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'manifest_schema'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/manifest_schema.py
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
                     f"{where}, operation '{op_id}': unknown kind '{kind}' (expected one of {list(KINDS)})")

            if kind in ("tool", "simulation"):
                _require(isinstance(op.get("use"), str),
                         f"{where}, operation '{op_id}': kind '{kind}' needs a 'use' naming a registry entry")

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
        run = sim.get("run")
        _require(isinstance(run, dict), f"{where}: needs a 'run' phase")
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
        _require(isinstance(case_id, str) and case_id, f"{path}: expectation #{index} needs a string 'id'")
        _require(case_id not in seen_cases, f"{path}: duplicate expectation id '{case_id}'")
        _require(isinstance(case.get("use"), str),
                 f"{path}: expectation '{case_id}' needs a 'use' naming a validator")
        seen_cases.append(case_id)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 26 tests PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/manifest_schema.py tests/test_manifest_schema.py
git commit -m "feat: early manifest validation with locatable diagnostics"
```

---

### Task 4: Operations model for tools + pipelines.yaml migration

This is the equivalence-critical task. Nothing new runs yet; the existing 12 designs must classify identically.

**Files:**
- Modify: `scripts/pipeline_engine.py` (replace `run_pipeline`, keep `run_step`/`resolve_artifact`)
- Modify: `manifests/pipelines.yaml`
- Test: `tests/test_pipeline_engine.py`

**Interfaces:**
- Consumes: `expand_argv`, `ManifestError`, `validate_pipelines`.
- Produces: `run_pipeline(pipeline_name, pipelines, registries, bin_dir, sources, work_root, name, timeout_s, design=None) -> {"stages": dict, "behavioral": list, "overall_status": str}`. `registries` is `{"tools": ..., "simulators": ..., "validators": ...}`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_pipeline_engine.py
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from pipeline_engine import resolve_inputs


class TestResolveInputs(unittest.TestCase):
    def test_absent_inputs_defaults_to_previous_artifact(self):
        got = resolve_inputs({"id": "b"}, {"a": Path("/w/a.hif")}, "a", [Path("/src.v")], "p")
        self.assertEqual(got, [Path("/w/a.hif")])

    def test_first_operation_defaults_to_design_sources(self):
        got = resolve_inputs({"id": "a"}, {}, None, [Path("/src.v")], "p")
        self.assertEqual(got, [Path("/src.v")])

    def test_explicit_reference_wins(self):
        artifacts = {"a": Path("/w/a.hif"), "b": Path("/w/b.v")}
        got = resolve_inputs({"id": "c", "inputs": ["a"]}, artifacts, "b", [], "p")
        self.assertEqual(got, [Path("/w/a.hif")])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_pipeline_engine -v`
Expected: FAIL — `ImportError: cannot import name 'resolve_inputs'`

- [ ] **Step 3: Implement `resolve_inputs` and the operations loop**

Replace `run_pipeline` in `scripts/pipeline_engine.py` with:

```python
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


def run_pipeline(pipeline_name, pipelines, registries, bin_dir, sources,
                 work_root, name, timeout_s, design=None):
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
```

Add to the imports at the top of `pipeline_engine.py`:

```python
from manifest_schema import validate_pipelines
from placeholders import ManifestError, expand_argv
from simulation import run_simulation
from validators import run_validation
```

Change `build_argv` usage inside `run_step` to go through `expand_argv`:

```python
    binary = find_tool(tool_def["command"][0], bin_dir)
    argv = [binary] + expand_argv(
        tool_def["command"][1:],
        {"input": str(inputs[0]), "workdir": str(workdir), "name": name},
        {"inputs": [str(p) for p in inputs]},
        f"tool '{tool_id}'",
    )
```

Delete the now-unused `build_argv`.

- [ ] **Step 4: Migrate `manifests/pipelines.yaml`**

Replace the file's `pipelines:` block with (keeping the `suite_defaults` block and updating the header comment to describe `operations`):

```yaml
pipelines:
  plain_roundtrip:
    operations:
      - {id: frontend, kind: tool, use: verilog2hif}
      - {id: backend,  kind: tool, use: hif2verilog}
      - {id: reparse,  kind: tool, use: verilog2hif}

  muffin_roundtrip:
    operations:
      - {id: frontend, kind: tool, use: verilog2hif}
      - {id: backend,  kind: tool, use: hif2verilog}
      - {id: reparse,  kind: tool, use: verilog2hif}
      # Former probes: both examine the frontend's output rather than the
      # previous operation's, which is now stated explicitly instead of via a
      # separate 'probes' section. Ids and order are unchanged so report stage
      # keys stay stable across the migration.
      - {id: muffin_list_faults, kind: tool, use: muffin_list_faults, inputs: [frontend]}
      - {id: muffin_instrument,  kind: tool, use: muffin_instrument,  inputs: [frontend]}
```

- [ ] **Step 5: Create stub `simulation.py` and `validators.py` so imports resolve**

```python
# scripts/simulation.py  (filled in by Task 5)
def run_simulation(op, registries, bin_dir, artifacts, workdir, name, timeout_s, design):
    raise NotImplementedError("simulation kind lands in Task 5")
```

```python
# scripts/validators.py  (filled in by Task 6)
def run_validation(op, registries, artifacts, design):
    raise NotImplementedError("validation kind lands in Task 6")
```

- [ ] **Step 6: Run unit tests**

Run: `python3 -m unittest discover -s tests -v`
Expected: 29 tests PASS

- [ ] **Step 7: Prove classification equivalence against the pre-refactor baseline**

```bash
source .workspace/toolchain.env
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
SCRATCH=/tmp/claude-1000/-home-enrico-repository-hif/3e305375-b44f-4cec-bf4b-c5ca4711e22e/scratchpad
python3 scripts/run_regression.py --manifest-label develop --report "$SCRATCH/after.json"
python3 - <<'PY'
import json, sys, os
scratch = os.environ.get("SCRATCH", ".")
before = json.load(open(f"{scratch}/baseline-classification.json"))
after_raw = json.load(open(f"{scratch}/after.json"))
after = {d['category']+'/'+d['name']: {'overall': d['overall_status'],
         'stages': {k: v['status'] for k, v in d['stages'].items()},
         'pipeline': d['pipeline']} for d in after_raw['designs']}
if before == after:
    print("EQUIVALENT: all 12 designs classify identically, same stage keys and order")
    sys.exit(0)
for key in sorted(set(before) | set(after)):
    if before.get(key) != after.get(key):
        print(f"DIFF {key}\n  before={before.get(key)}\n  after ={after.get(key)}")
sys.exit(1)
PY
```

Expected: `EQUIVALENT: all 12 designs classify identically, same stage keys and order`

If it differs, the migration is wrong — fix the migration, never the baseline.

- [ ] **Step 8: Commit**

```bash
git add scripts/pipeline_engine.py scripts/simulation.py scripts/validators.py manifests/pipelines.yaml tests/test_pipeline_engine.py
git commit -m "refactor: single ordered operations model replacing steps/probes"
```

---

### Task 5: Simulator registry and compile-once/run-many executor

**Files:**
- Create: `manifests/simulators.yaml`
- Rewrite: `scripts/simulation.py`
- Test: `tests/test_simulation.py`

**Interfaces:**
- Consumes: `expand_argv`, `resolve_record`/`is_lookup`, `find_tool`, `run_tool`, `classify`, `trim_result`, `resolve_artifact`.
- Produces: `run_simulation(op, registries, bin_dir, artifacts, workdir, name, timeout_s, design) -> (status, record)` where `record["runs"]` maps `run_id -> {"status", "trace", "params", ...}`. Also `resolve_params(params, artifacts, context) -> dict`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_simulation.py
import json, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError
from simulation import resolve_params


class TestResolveParams(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.faults = Path(self.tmp.name) / "f.json"
        self.faults.write_text(json.dumps({"faults": [
            {"id": 1, "type": "stuck-at-0", "bit": 0, "signal": "y"},
            {"id": 2, "type": "stuck-at-1", "bit": 0, "signal": "y"},
        ]}))

    def tearDown(self):
        self.tmp.cleanup()

    def test_literal_param_passes_through(self):
        self.assertEqual(resolve_params({"mut": 0}, {}, "run r"), {"mut": 0})

    def test_lookup_param_resolves_against_artifact(self):
        got = resolve_params(
            {"mut": {"from": "enumerate", "array": "faults",
                     "where": {"signal": "y", "bit": 0, "type": "stuck-at-1"}, "take": "id"}},
            {"enumerate": self.faults}, "run r")
        self.assertEqual(got, {"mut": 2})

    def test_lookup_against_unknown_operation_is_an_error(self):
        with self.assertRaises(ManifestError) as ctx:
            resolve_params({"mut": {"from": "nope", "array": "faults", "where": {}, "take": "id"}},
                           {}, "run r")
        self.assertIn("nope", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_simulation -v`
Expected: FAIL — `ImportError: cannot import name 'resolve_params'`

- [ ] **Step 3: Write `manifests/simulators.yaml`**

```yaml
# Simulator capability registry: how to compile/elaborate a design and how to
# execute it, as data. The engine understands only declared inputs, outputs,
# placeholders and result artifacts - never a specific simulator, filename or
# design-under-test port.
#
# The compile/run split is what makes compile-once/run-many possible: an
# instrumented Muffin design carries every fault in one netlist, so each fault
# selection is another `run` of the same compiled artifact, never a recompile.
#
# Binaries resolve through find_tool (--bin-dir, then PATH). This repo never
# installs, builds, vendors or version-pins a simulator - provisioning belongs
# to the environment (apt in CI, whatever is present locally).
#
# Placeholders: scalar {workdir} {name} {top} {compiled} {trace} {rundir};
# list {sources} {defines} {params} {options} (each must be a whole token).

iverilog:
  language: verilog
  # -g2005 is sufficient: hif2verilog renders Muffin's activation port as
  # `input wire [31:0] muffinMutPort`, a legal Verilog-2001 port. Verified
  # against real generated output.
  compile:
    command: ["iverilog", "{options}", "{defines}", "-o", "{workdir}/sim.vvp", "-s", "{top}", "{sources}"]
    artifact: "{workdir}/sim.vvp"
    options: ["-g2005"]
    define_template: "-D{value}"
  run:
    command: ["vvp", "{compiled}", "{params}", "+trace={trace}"]
    artifact: "{rundir}/trace.csv"
    param_template: "+{key}={value}"
  timeout_s: 60
```

- [ ] **Step 4: Write `scripts/simulation.py`**

```python
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
                f"which produced no artifact (available: {sorted(artifacts)})"
            )
        document = json.loads(Path(artifact).read_text())
        resolved[key] = resolve_record(
            document, value["array"], value["where"], value["take"],
            f"{context}, parameter '{key}'",
        )
    return resolved


def _collect_sources(op, artifacts, design, context):
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
            sources.append(Path(artifact))
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
        record["phase"] = "compile"
        if status != "PASS":
            record["status"] = status
            return status, record

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
            record["phase"] = "run"
            worst = status

    record["status"] = worst
    return worst, record
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 32 tests PASS

- [ ] **Step 6: Commit**

```bash
git add manifests/simulators.yaml scripts/simulation.py tests/test_simulation.py
git commit -m "feat: generic simulator registry with compile-once/run-many execution"
```

---

### Task 6: Validators

**Files:**
- Create: `manifests/validators.yaml`
- Rewrite: `scripts/validators.py`
- Test: `tests/test_validators.py`

**Interfaces:**
- Consumes: `ManifestError`.
- Produces: `run_validation(op, registries, artifacts, design) -> (status, record, cases)` where each case is a dict with `id`, `validator`, `impl`, `status`, `mismatch`. Also `artifact_equal(left, right)`, `artifact_differs(left, right)`, `artifact_equals_fixture(left, expected)`, each returning `(bool, str|None)`, and `IMPLS` mapping name to callable.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_validators.py
import sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from validators import IMPLS, artifact_differs, artifact_equal


class TestComparators(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.a = Path(self.tmp.name) / "a.csv"
        self.b = Path(self.tmp.name) / "b.csv"
        self.c = Path(self.tmp.name) / "c.csv"
        self.a.write_text("time,y\n5,0\n10,1\n")
        self.b.write_text("time,y\n5,0\n10,1\n")
        self.c.write_text("time,y\n5,0\n10,0\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_equal_traces_pass(self):
        ok, mismatch = artifact_equal(self.a, self.b)
        self.assertTrue(ok)
        self.assertIsNone(mismatch)

    def test_different_traces_fail_with_first_differing_line(self):
        ok, mismatch = artifact_equal(self.a, self.c)
        self.assertFalse(ok)
        self.assertIn("line 3", mismatch)
        self.assertIn("10,1", mismatch)
        self.assertIn("10,0", mismatch)

    def test_differs_is_the_inverse(self):
        self.assertTrue(artifact_differs(self.a, self.c)[0])
        self.assertFalse(artifact_differs(self.a, self.b)[0])

    def test_mismatch_excerpt_is_capped(self):
        big_a = Path(self.tmp.name) / "ba.csv"
        big_b = Path(self.tmp.name) / "bb.csv"
        big_a.write_text("\n".join(f"{i},0" for i in range(500)))
        big_b.write_text("\n".join(f"{i},1" for i in range(500)))
        ok, mismatch = artifact_equal(big_a, big_b)
        self.assertFalse(ok)
        self.assertLess(len(mismatch), 2000)

    def test_missing_file_fails_rather_than_raising(self):
        ok, mismatch = artifact_equal(self.a, Path(self.tmp.name) / "ghost.csv")
        self.assertFalse(ok)
        self.assertIn("missing", mismatch.lower())

    def test_every_known_impl_is_registered(self):
        self.assertEqual(sorted(IMPLS), ["artifact_differs", "artifact_equal", "artifact_equals_fixture"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_validators -v`
Expected: FAIL — `ImportError: cannot import name 'IMPLS'`

- [ ] **Step 3: Write `manifests/validators.yaml`**

```yaml
# Validator registry: named assertions over result artifacts.
#
# A validator consumes results and makes one claim. It never runs anything -
# executing a simulator is simulation's job. Keeping the two apart is what lets
# a failed behavioral test say whether the design misbehaved or the expectation
# was wrong.
#
# `impl` selects a generic comparator in scripts/validators.py. Adding a
# validator is normally a line here; a new impl is written only when the
# comparison itself is genuinely new. Nothing here is specific to Muffin, to
# faults, or to Verilog - `trace_equal` would compare an RTL trace against a
# C++ trace unchanged.

trace_equal:
  impl: artifact_equal

trace_differs:
  impl: artifact_differs

expected_trace:
  impl: artifact_equals_fixture
```

- [ ] **Step 4: Write `scripts/validators.py`**

```python
"""
Validation: separate, first-class assertions over simulation results.

Validators never execute anything. They consume artifacts produced by earlier
operations and return a verdict plus a concise, bounded mismatch excerpt -
bounded because a failing trace comparison must be readable in a CI summary,
with the full artifacts left on disk for whoever needs them.

A validation FAIL is a real behavioral regression, distinct from a CRASH (the
tool fell over) and from a TIMEOUT (it never finished). That distinction is the
whole reason validation is not folded into simulation.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from placeholders import ManifestError  # noqa: E402

MAX_MISMATCH_CHARS = 800


def _read_lines(path):
    p = Path(path)
    if not p.exists():
        return None
    return p.read_text().splitlines()


def _first_difference(left_lines, right_lines, left_label, right_label):
    for index, (l, r) in enumerate(zip(left_lines, right_lines), start=1):
        if l != r:
            return f"line {index}: {left_label}={l!r} {right_label}={r!r}"
    if len(left_lines) != len(right_lines):
        return (f"line count differs: {left_label}={len(left_lines)} "
                f"{right_label}={len(right_lines)}")
    return None


def _cap(text):
    if text and len(text) > MAX_MISMATCH_CHARS:
        return text[:MAX_MISMATCH_CHARS] + "... [truncated]"
    return text


def artifact_equal(left, right):
    left_lines = _read_lines(left)
    right_lines = _read_lines(right)
    if left_lines is None:
        return False, f"missing artifact: {left}"
    if right_lines is None:
        return False, f"missing artifact: {right}"
    diff = _first_difference(left_lines, right_lines, "left", "right")
    return (diff is None), _cap(diff)


def artifact_differs(left, right):
    equal, _ = artifact_equal(left, right)
    if equal:
        return False, "artifacts are identical, but a difference was expected"
    return True, None


def artifact_equals_fixture(left, expected):
    return artifact_equal(left, expected)


IMPLS = {
    "artifact_equal": artifact_equal,
    "artifact_differs": artifact_differs,
    "artifact_equals_fixture": artifact_equals_fixture,
}


def _operand(ref, artifacts, design, context):
    """A validation operand is a named run's trace, or a checked-in fixture."""
    if not isinstance(ref, dict):
        raise ManifestError(f"{context}: operand must be a mapping, got {ref!r}")
    if "fixture" in ref:
        return design.fixture(ref["fixture"], context)
    if "from" not in ref:
        raise ManifestError(f"{context}: operand needs 'from' or 'fixture', got {ref!r}")

    stage = artifacts.get(("simulation", ref["from"]))
    if stage is None:
        raise ManifestError(
            f"{context}: references simulation '{ref['from']}', which did not run")
    run_id = ref.get("run")
    run = stage["runs"].get(run_id)
    if run is None:
        raise ManifestError(
            f"{context}: simulation '{ref['from']}' has no run '{run_id}' "
            f"(runs: {sorted(stage['runs'])})")
    return Path(run["trace"])


def run_validation(op, registries, artifacts, design):
    op_id = op["id"]
    cases = op.get("_cases", [])
    record = {"kind": "validation", "phase": "validate", "cases": {}}
    results = []
    worst = "PASS"

    for case in cases:
        case_id = case["id"]
        context = f"validation operation '{op_id}', case '{case_id}'"
        validator = registries["validators"].get(case["use"])
        if validator is None:
            raise ManifestError(
                f"{context}: unknown validator '{case['use']}' "
                f"(known: {sorted(registries['validators'])})")

        impl_name = validator["impl"]
        left = _operand(case["left"], artifacts, design, context)
        right_ref = case.get("right") or case.get("expected")
        right = _operand(right_ref, artifacts, design, context)

        ok, mismatch = IMPLS[impl_name](left, right)
        status = "PASS" if ok else "FAIL"
        if status != "PASS":
            worst = "FAIL"

        entry = {
            "id": case_id, "validator": case["use"], "impl": impl_name,
            "status": status, "mismatch": mismatch,
            "left": str(left), "right": str(right),
            "fault_selection": case.get("_fault_selection"),
            "resolved_fault_id": case.get("_resolved_fault_id"),
        }
        record["cases"][case_id] = entry
        results.append(entry)

    record["status"] = worst
    return worst, record, results
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 38 tests PASS

- [ ] **Step 6: Commit**

```bash
git add manifests/validators.yaml scripts/validators.py tests/test_validators.py
git commit -m "feat: validator registry with generic artifact comparators"
```

---

### Task 7: Design discovery for fixtures and behavior.yaml

**Files:**
- Modify: `scripts/run_regression.py:40-101` (`Design`, `discover_designs`, `run_design`)
- Test: `tests/test_discovery.py`

**Interfaces:**
- Consumes: `validate_behavior`.
- Produces: `Design` dataclass gaining `fixtures: dict`, `behavior: dict`, `root: Path`, and method `fixture(name, context) -> Path`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_discovery.py
import json, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from placeholders import ManifestError
from run_regression import discover_designs


class TestDiscovery(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _behavioral_design(self):
        d = self.root / "combinational" / "and2"
        d.mkdir(parents=True)
        (d / "and2.v").write_text("module and2(input a, input b, output y);\nassign y=a&b;\nendmodule\n")
        (d / "and2_tb.v").write_text("module and2_tb; endmodule\n")
        (d / "design.json").write_text(json.dumps({
            "top": "and2", "pipeline": "muffin_behavioral",
            "sources": ["and2.v"], "fixtures": {"testbench": "and2_tb.v"}}))
        (d / "behavior.yaml").write_text(
            "runs:\n  - {id: golden, params: {mut: 0}}\nexpectations: []\n")
        return d

    def test_explicit_sources_exclude_the_testbench(self):
        self._behavioral_design()
        designs = discover_designs(self.root, {"combinational": "plain_roundtrip"})
        self.assertEqual(len(designs), 1)
        self.assertEqual([p.name for p in designs[0].sources], ["and2.v"])

    def test_fixtures_resolve_to_paths(self):
        self._behavioral_design()
        design = discover_designs(self.root, {})[0]
        self.assertEqual(design.fixture("testbench", "ctx").name, "and2_tb.v")

    def test_unknown_fixture_names_the_available_ones(self):
        self._behavioral_design()
        design = discover_designs(self.root, {})[0]
        with self.assertRaises(ManifestError) as ctx:
            design.fixture("nope", "ctx")
        self.assertIn("testbench", str(ctx.exception))

    def test_behavior_yaml_is_loaded_and_validated(self):
        self._behavioral_design()
        design = discover_designs(self.root, {})[0]
        self.assertEqual(design.behavior["runs"][0]["id"], "golden")

    def test_single_file_design_still_discovered_without_sidecar(self):
        (self.root / "sequential").mkdir(parents=True)
        (self.root / "sequential" / "counter.v").write_text("module counter; endmodule\n")
        designs = discover_designs(self.root, {"sequential": "plain_roundtrip"})
        self.assertEqual(designs[0].name, "counter")
        self.assertEqual(designs[0].pipeline, "plain_roundtrip")
        self.assertEqual(designs[0].behavior, {})

    def test_multi_file_design_without_explicit_sources_globs_all_v(self):
        d = self.root / "hierarchical" / "h"
        d.mkdir(parents=True)
        (d / "top.v").write_text("module top; endmodule\n")
        (d / "child.v").write_text("module child; endmodule\n")
        (d / "design.json").write_text(json.dumps({"top": "top"}))
        design = discover_designs(self.root, {})[0]
        self.assertEqual(sorted(p.name for p in design.sources), ["child.v", "top.v"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_discovery -v`
Expected: FAIL — `TypeError` / missing `fixture` attribute

- [ ] **Step 3: Update `Design` and `discover_designs`**

Replace the `Design` dataclass and the directory branch of `discover_designs` in `scripts/run_regression.py`:

```python
@dataclasses.dataclass
class Design:
    name: str
    category: str
    sources: list
    top: str
    pipeline: str
    note: str = ""
    root: Path = None
    fixtures: dict = dataclasses.field(default_factory=dict)
    behavior: dict = dataclasses.field(default_factory=dict)

    def fixture(self, fixture_name, context):
        """Fixtures are per-design files a pipeline references by role
        (`testbench`, `expect_sa0_y`, ...) rather than by path, so one shared
        pipeline can serve designs whose files are named differently."""
        path = self.fixtures.get(fixture_name)
        if path is None:
            raise ManifestError(
                f"{context}: design '{self.category}/{self.name}' has no fixture "
                f"'{fixture_name}' (declared: {sorted(self.fixtures)})"
            )
        return path
```

In the directory branch, after loading `meta`:

```python
                explicit = meta.get("sources")
                if explicit:
                    sources = [entry / s for s in explicit]
                    missing = [str(p) for p in sources if not p.exists()]
                    if missing:
                        raise SystemExit(f"{entry}: design.json lists missing source(s): {missing}")
                else:
                    sources = sorted(entry.glob("*.v"))
                if not sources:
                    continue

                fixtures = {k: entry / v for k, v in (meta.get("fixtures") or {}).items()}
                missing_fixtures = {k: str(p) for k, p in fixtures.items() if not p.exists()}
                if missing_fixtures:
                    raise SystemExit(f"{entry}: design.json lists missing fixture(s): {missing_fixtures}")

                behavior_path = entry / "behavior.yaml"
                behavior = {}
                if behavior_path.exists():
                    behavior = yaml.safe_load(behavior_path.read_text()) or {}
                    validate_behavior(behavior, str(behavior_path))
```

and pass `root=entry, fixtures=fixtures, behavior=behavior` into the `Design(...)` construction. Add `root=entry` (single-file designs pass `root=category_dir`).

Add imports at the top of `run_regression.py`:

```python
import yaml
from manifest_schema import validate_behavior
from placeholders import ManifestError
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m unittest discover -s tests -v`
Expected: 44 tests PASS

- [ ] **Step 5: Verify the existing corpus still classifies identically**

```bash
source .workspace/toolchain.env
export PATH="$PREFIX/bin:$PATH"; export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --manifest-label develop --report /tmp/claude-1000/-home-enrico-repository-hif/3e305375-b44f-4cec-bf4b-c5ca4711e22e/scratchpad/after7.json
```

Expected: 12 designs, all PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/run_regression.py tests/test_discovery.py
git commit -m "feat: design fixtures and behavior.yaml discovery"
```

---

### Task 8: Wire simulation and validation into the engine, end to end

Proves the whole architecture on one real design before the corpus grows.

**Files:**
- Modify: `scripts/pipeline_engine.py` (expand `_runs`/`_cases` from spec)
- Modify: `scripts/run_regression.py` (load new registries, pass `design`)
- Modify: `manifests/pipelines.yaml` (add `muffin_behavioral`)
- Create: `designs/combinational/and2/{and2.v,and2_tb.v,design.json,behavior.yaml}`
- Delete: `designs/combinational/and2.v`, `designs/combinational/and2.json`

**Interfaces:**
- Consumes: everything from Tasks 1-7.
- Produces: working `muffin_behavioral` pipeline; `artifacts` dict additionally keyed `("simulation", op_id) -> record`.

- [ ] **Step 1: Expand `from_spec` in the engine**

Add to `scripts/pipeline_engine.py`:

```python
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
            raise ManifestError(f"operation '{op_id}': '{kind}: {{from_spec: {key}}}' "
                                f"requires a design with a behavior.yaml")
        entries = design.behavior.get(key)
        if entries is None:
            raise ManifestError(
                f"operation '{op_id}': design '{design.category}/{design.name}' "
                f"behavior.yaml has no '{key}' list (has: {sorted(design.behavior)})")
        return entries
    raise ManifestError(f"operation '{op_id}': '{kind}' must be a list or {{from_spec: <key>}}")
```

In the `simulation` branch of `run_pipeline`, before calling `run_simulation`:

```python
            op = dict(op, _runs=_from_spec(op.get("runs", []), design, "runs", op_id))
```

In the `validation` branch, before calling `run_validation`:

```python
            op = dict(op, _cases=_from_spec(op.get("cases", []), design, "cases", op_id))
```

And record simulation stages so validators can reach their runs — after the simulation branch computes `record`:

```python
            artifacts[("simulation", op_id)] = record
```

- [ ] **Step 2: Load the new registries in `run_regression.py`**

Replace the tools/pipelines loading in `main()`:

```python
    registries = {
        "tools": load_yaml_manifest(Path(args.tools).resolve()),
        "simulators": load_yaml_manifest(Path(args.simulators).resolve()),
        "validators": load_yaml_manifest(Path(args.validators).resolve()),
    }
    validate_simulators(registries["simulators"], args.simulators)
    validate_validators(registries["validators"], args.validators)
    pipelines = load_yaml_manifest(Path(args.pipelines).resolve())
    validate_pipelines(pipelines, args.pipelines)
```

Add the arguments:

```python
    parser.add_argument("--simulators", default="manifests/simulators.yaml")
    parser.add_argument("--validators", default="manifests/validators.yaml")
```

and thread `registries` and `design` through `run_design`/`run_pipeline`.

- [ ] **Step 3: Add the `muffin_behavioral` pipeline**

Append to `manifests/pipelines.yaml`:

```yaml
  muffin_behavioral:
    operations:
      - {id: frontend,   kind: tool, use: verilog2hif}
      - {id: enumerate,  kind: tool, use: muffin_list_faults, inputs: [frontend]}
      - {id: instrument, kind: tool, use: muffin_instrument,  inputs: [frontend]}
      - {id: regenerate, kind: tool, use: hif2verilog,        inputs: [instrument]}

      # Reference: the original hand-written RTL, unmodified by any HIF tool.
      - id: simulate_reference
        kind: simulation
        use: iverilog
        sources: [{design: sources}, {fixture: testbench}]
        top: "{name}_tb"
        runs: [{id: reference}]

      # One compile of the instrumented netlist; every fault selection is
      # another run of it, never a recompile.
      - id: simulate_instrumented
        kind: simulation
        use: iverilog
        sources: [{from: regenerate}, {fixture: testbench}]
        top: "{name}_tb"
        defines: [MUFFIN_MUT]
        runs: {from_spec: runs}

      - {id: validate, kind: validation, cases: {from_spec: expectations}}
```

- [ ] **Step 4: Create the behavioral `and2` design**

```bash
mkdir -p designs/combinational/and2
git mv designs/combinational/and2.v designs/combinational/and2/and2.v
git rm -q designs/combinational/and2.json
```

`designs/combinational/and2/design.json`:

```json
{
    "top": "and2",
    "pipeline": "muffin_behavioral",
    "sources": ["and2.v"],
    "fixtures": {"testbench": "and2_tb.v"},
    "note": "Ecosystem-level behavioral check: golden instrumentation must reproduce the original RTL exactly, and SA0/SA1 on y must change it in exactly the predicted way."
}
```

`designs/combinational/and2/and2_tb.v`:

```verilog
// Stimulus for and2, shared by both the reference and the instrumented
// compile. The activation port only exists in the instrumented netlist, so it
// is connected under `ifdef MUFFIN_MUT - which the simulation operation
// supplies via `defines`. Runtime fault selection and the trace path both
// arrive as plusargs, so one compiled binary serves every run.
`timescale 1ns/1ps
module and2_tb;
  reg a, b;
  wire y;
  integer mut;
  integer fd;
  integer i;
  reg [1023:0] tracefile;

  and2 dut (
    .a(a), .b(b), .y(y)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    $fdisplay(fd, "time,a,b,y");
    for (i = 0; i < 4; i = i + 1) begin
      {a, b} = i[1:0];
      #5;
      $fdisplay(fd, "%0t,%b,%b,%b", $time, a, b, y);
    end
    $fclose(fd);
    $finish;
  end
endmodule
```

`designs/combinational/and2/behavior.yaml`:

```yaml
# Three separate concerns, deliberately not mixed:
#   stimulus            -> and2_tb.v (shared by both compiles)
#   fault selection     -> runs, resolved from faults.json by attribute
#   expected result     -> expectations
#
# Fault ids are assigned in enumeration order and move when a design's
# assignments change, so no id is written here.

runs:
  - {id: golden, params: {mut: 0}}
  - id: sa0_y
    params:
      mut: {from: enumerate, array: faults, where: {signal: y, bit: 0, type: stuck-at-0}, take: id}
  - id: sa1_y
    params:
      mut: {from: enumerate, array: faults, where: {signal: y, bit: 0, type: stuck-at-1}, take: id}

expectations:
  # Mandatory: instrumentation must be behaviorally transparent when inactive.
  - id: golden_matches_rtl
    use: trace_equal
    left:  {from: simulate_reference,    run: reference}
    right: {from: simulate_instrumented, run: golden}

  # y stuck at 0: only the a=b=1 vector can reveal it.
  - id: sa0_y_expected_trace
    use: expected_trace
    left:     {from: simulate_instrumented, run: sa0_y}
    expected: {fixture: expect_sa0_y}

  # y stuck at 1: reveals at three vectors, and is NOT observable at a=b=1.
  - id: sa1_y_expected_trace
    use: expected_trace
    left:     {from: simulate_instrumented, run: sa1_y}
    expected: {fixture: expect_sa1_y}

  # Detected: SA0 genuinely changes observable behavior under this stimulus.
  - id: sa0_y_detected
    use: trace_differs
    left:  {from: simulate_instrumented, run: sa0_y}
    right: {from: simulate_reference,    run: reference}
```

Add the two oracle fixtures to `design.json`'s `fixtures` map (`expect_sa0_y`: `expect_sa0_y.csv`, `expect_sa1_y`: `expect_sa1_y.csv`) and create them:

`expect_sa0_y.csv`:
```
time,a,b,y
5000,0,0,0
10000,0,1,0
15000,1,0,0
20000,1,1,0
```

`expect_sa1_y.csv`:
```
time,a,b,y
5000,0,0,1
10000,0,1,1
15000,1,0,1
20000,1,1,1
```

- [ ] **Step 5: Run the behavioral design end to end**

```bash
source .workspace/toolchain.env
export PATH="$PREFIX/bin:$PATH"; export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --only and2 --manifest-label develop
```

Expected: `and2` PASS, with stages `frontend, enumerate, instrument, regenerate, simulate_reference, simulate_instrumented, validate` all PASS and four behavioral cases PASS.

- [ ] **Step 6: Verify no product-specific branching entered the engine**

```bash
grep -nE '"(muffin|verilog2hif|hif2verilog|iverilog|vvp)"|muffinMutPort' \
  scripts/pipeline_engine.py scripts/simulation.py scripts/validators.py \
  scripts/placeholders.py scripts/record_lookup.py scripts/manifest_schema.py
```

Expected: no output. Any hit is a plan failure and must be moved into a manifest.

- [ ] **Step 7: Commit**

```bash
git add -A scripts manifests designs/combinational
git commit -m "feat: end-to-end Muffin behavioral pipeline on and2"
```

---

### Task 9: Behavioral reporting

**Files:**
- Modify: `scripts/run_regression.py` (`build_report`, `print_summary`, exit code)
- Modify: `scripts/report.py` (add `render_behavioral`)
- Test: `tests/test_report.py`

**Interfaces:**
- Consumes: `behavioral` list from `run_pipeline`.
- Produces: report JSON gains a top-level `behavioral` list of `{design, category, pipeline, case, validator, impl, status, fault_selection, resolved_fault_id, mismatch}`; `render_behavioral(report) -> str`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_report.py
import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from report import render_behavioral

REPORT = {"behavioral": [
    {"design": "and2", "category": "combinational", "pipeline": "muffin_behavioral",
     "case": "golden_matches_rtl", "validator": "trace_equal", "status": "PASS",
     "fault_selection": None, "resolved_fault_id": None, "mismatch": None},
    {"design": "and2", "category": "combinational", "pipeline": "muffin_behavioral",
     "case": "sa0_y_expected_trace", "validator": "expected_trace", "status": "FAIL",
     "fault_selection": {"signal": "y", "bit": 0, "type": "stuck-at-0"},
     "resolved_fault_id": 1, "mismatch": "line 5: left='20000,1,1,1' right='20000,1,1,0'"},
]}


class TestRenderBehavioral(unittest.TestCase):
    def test_counts_pass_and_fail(self):
        out = render_behavioral(REPORT)
        self.assertIn("1 passed", out)
        self.assertIn("1 failed", out)

    def test_failing_case_shows_debug_context(self):
        out = render_behavioral(REPORT)
        self.assertIn("sa0_y_expected_trace", out)
        self.assertIn("expected_trace", out)
        self.assertIn("stuck-at-0", out)
        self.assertIn("fault 1", out)

    def test_passing_case_is_not_listed_individually(self):
        self.assertNotIn("golden_matches_rtl", render_behavioral(REPORT))

    def test_absent_section_renders_nothing(self):
        self.assertEqual(render_behavioral({}), "")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_report -v`
Expected: FAIL — `ImportError: cannot import name 'render_behavioral'`

- [ ] **Step 3: Implement `render_behavioral` in `scripts/report.py`**

```python
def render_behavioral(report):
    """Behavioral results, summarised. Detail deliberately stays in the JSON
    artifact: a CI summary that dumps whole traces stops being readable exactly
    when it matters most."""
    cases = report.get("behavioral") or []
    if not cases:
        return ""

    passed = [c for c in cases if c["status"] == "PASS"]
    failed = [c for c in cases if c["status"] != "PASS"]

    lines = ["", "## Muffin behavioral acceptance", "",
             f"{len(passed)} passed, {len(failed)} failed "
             f"across {len({c['design'] for c in cases})} design(s)."]

    if failed:
        lines += ["", "| Design | Case | Validator | Fault | Status | Mismatch |", "|---|---|---|---|---|---|"]
        for c in failed:
            selection = c.get("fault_selection")
            fault = "-" if not selection else (
                f"{selection.get('type')} {selection.get('signal')}[{selection.get('bit')}]"
                + (f" (fault {c['resolved_fault_id']})" if c.get("resolved_fault_id") is not None else "")
            )
            mismatch = (c.get("mismatch") or "").replace("|", "\\|")[:120]
            lines.append(f"| `{c['category']}/{c['design']}` | `{c['case']}` | "
                         f"`{c['validator']}` | {fault} | **{c['status']}** | {mismatch} |")
    return "\n".join(lines)
```

Call it from `main()` after the curated section:

```python
    if curated_path.exists():
        curated = json.loads(curated_path.read_text())
        sections.append(render_curated(curated))
        behavioral = render_behavioral(curated)
        if behavioral:
            sections.append(behavioral)
```

- [ ] **Step 4: Record fault selection alongside each case**

`scripts/simulation.py` already stores a `selections` map on each run (Task 5). Surface it on the validation case, so a failing behavioral result shows both the stable selector and the numeric id it resolved to.

In `scripts/validators.py`'s `run_validation`, populate `_fault_selection`/`_resolved_fault_id` from the left operand's run selections (first selection, if any):

```python
def _selection_of(ref, artifacts):
    if not isinstance(ref, dict) or "from" not in ref:
        return None, None
    stage = artifacts.get(("simulation", ref["from"]))
    if stage is None:
        return None, None
    run = stage["runs"].get(ref.get("run"))
    if not run or not run.get("selections"):
        return None, None
    first = next(iter(run["selections"].values()))
    return first["where"], first["resolved"]
```

and in the case loop:

```python
        selection, resolved = _selection_of(case["left"], artifacts)
        entry["fault_selection"] = selection
        entry["resolved_fault_id"] = resolved
```

- [ ] **Step 5: Add the `behavioral` section to the curated report**

In `build_report` in `run_regression.py`, accumulate:

```python
    behavioral_out = []
    for res in results:
        design = res["design"]
        for case in res.get("behavioral", []):
            behavioral_out.append({
                "design": design.name, "category": design.category,
                "pipeline": design.pipeline, "case": case["id"],
                "validator": case["validator"], "impl": case["impl"],
                "status": case["status"], "mismatch": case["mismatch"],
                "fault_selection": case.get("fault_selection"),
                "resolved_fault_id": case.get("resolved_fault_id"),
                "left": case["left"], "right": case["right"],
            })
```

and include `"behavioral": behavioral_out` in the returned dict. Extend the exit condition:

```python
    any_failure = any(
        d["overall_status"] in ("CRASH", "TIMEOUT", "FAIL") for d in report["designs"]
    )
    sys.exit(1 if any_failure else 0)
```

Add a behavioral line to `print_summary`:

```python
    behavioral = report.get("behavioral") or []
    if behavioral:
        failed = [c for c in behavioral if c["status"] != "PASS"]
        print(f"\nBehavioral: {len(behavioral) - len(failed)} passed, {len(failed)} failed")
        for c in failed:
            print(f"  - {c['category']}/{c['design']} :: {c['case']} "
                  f"[{c['validator']}] {c['status']}")
            if c["mismatch"]:
                print(f"      {c['mismatch']}")
```

- [ ] **Step 6: Run tests and the behavioral design**

Run: `python3 -m unittest discover -s tests -v`
Expected: 48 tests PASS

Run: `python3 scripts/run_regression.py --only and2 --manifest-label develop && python3 scripts/report.py`
Expected: behavioral section shows `4 passed, 0 failed across 1 design(s)`

- [ ] **Step 7: Commit**

```bash
git add scripts/report.py scripts/run_regression.py scripts/simulation.py scripts/validators.py tests/test_report.py
git commit -m "feat: structured behavioral reporting with failure-phase attribution"
```

---

### Task 10: Corpus — combinational (16 designs, 4 behavioral)

**Files:** `designs/combinational/`

Existing: `and2/` (behavioral, Task 8), `decoder.v`, `full_adder.v`, `mux2.v`, `small_alu.v`.

- [ ] **Step 1: Add the 11 new combinational designs**

Each is a single `.v` file with no sidecar (inheriting `plain_roundtrip`) unless noted:

| File | Covers |
|---|---|
| `or_nand_nor.v` | basic boolean operators, multi-output |
| `mux4.v` | 4:1 mux via nested conditionals |
| `mux4_case.v` | same function via `case` — case-statement coverage |
| `encoder_8to3.v` | encoder |
| `priority_encoder.v` | priority logic, `casez`-free if/else chain |
| `comparator.v` | `==`, `<`, `>` multi-output |
| `adder_sub.v` | add/sub selected by a control bit |
| `carry_ripple.v` | explicit carry chain, carry-out behavior |
| `shifter.v` | logical left/right shifts by a variable amount |
| `reduction_ops.v` | `&`, `|`, `^` reductions |
| `concat_slice.v` | concatenation and part-select |

Example (`designs/combinational/priority_encoder.v`):

```verilog
// Highest set bit wins; valid low when no input is set.
module priority_encoder(input [3:0] req, output reg [1:0] grant, output reg valid);
  always @(*) begin
    valid = 1'b1;
    if      (req[3]) grant = 2'd3;
    else if (req[2]) grant = 2'd2;
    else if (req[1]) grant = 2'd1;
    else if (req[0]) grant = 2'd0;
    else begin grant = 2'd0; valid = 1'b0; end
  end
endmodule
```

Example (`designs/combinational/reduction_ops.v`):

```verilog
// All three reduction operators on one vector, as separate outputs, so a
// fault on any single output is independently observable.
module reduction_ops(input [7:0] d, output all_ones, output any_one, output parity);
  assign all_ones = &d;
  assign any_one  = |d;
  assign parity   = ^d;
endmodule
```

Example (`designs/combinational/concat_slice.v`):

```verilog
// Concatenation and part-select, kept separate so each has its own assign
// (and therefore its own fault location).
module concat_slice(input [3:0] a, input [3:0] b, output [7:0] joined, output [3:0] mixed);
  assign joined = {a, b};
  assign mixed  = {a[1:0], b[3:2]};
endmodule
```

- [ ] **Step 2: Promote 3 more to behavioral (directory form)**

`mux4_case`, `priority_encoder`, `reduction_ops` each become directories with `design.json` (`pipeline: muffin_behavioral`, explicit `sources`/`fixtures`), a `_tb.v` following the `and2_tb.v` pattern (conditional `.muffinMutPort(mut)` under `` `ifdef MUFFIN_MUT ``, plusargs `mut`/`trace`, CSV via `$fdisplay`), a `behavior.yaml`, and oracle CSVs.

For `reduction_ops`, select a fault on a **multi-bit** intermediate to satisfy Phase E.5 — `concat_slice`'s `joined` is the wider alternative if `reduction_ops` proves to have only 1-bit locations. Generate each oracle CSV by *reasoning from the instrumentation semantics* (`rhs | (1<<bit)` for SA1, `rhs & ~(1<<bit)` for SA0), then confirm against the actual run. If they disagree, that is a finding — stop and report, do not adjust the oracle to match.

- [ ] **Step 3: Run the category**

```bash
source .workspace/toolchain.env
export PATH="$PREFIX/bin:$PATH"; export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --manifest-label develop
```

Expected: all combinational designs PASS. Fix any fixture that fails; never relax an expectation.

- [ ] **Step 4: Commit**

```bash
git add designs/combinational
git commit -m "test: expand combinational corpus to 16 designs, 4 behavioral"
```

---

### Task 11: Corpus — sequential (13 designs, 4 behavioral)

**Files:** `designs/sequential/`

Existing: `counter.v`, `shift_register.v`, `simple_fsm.v`.

- [ ] **Step 1: Add the 10 new sequential designs**

| File | Covers |
|---|---|
| `dff.v` | plain DFF |
| `dff_sync_reset.v` | synchronous reset |
| `dff_async_reset.v` | asynchronous reset (`posedge clk or posedge rst`) |
| `dff_enable.v` | clock enable |
| `up_down_counter.v` | direction control, wraparound |
| `counter_load.v` | parallel load vs increment priority |
| `shift_lfsr.v` | feedback/state-dependent behavior |
| `pipeline3.v` | three-stage register pipeline |
| `multi_reg.v` | several independent registers in one module |
| `fsm_moore_mealy.v` | state/output interaction, both output styles |

Example (`designs/sequential/dff_async_reset.v`):

```verilog
// Asynchronous reset - the reset edge is in the sensitivity list, so q clears
// without waiting for a clock edge.
module dff_async_reset(input clk, input rst_n, input d, output reg q);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= 1'b0;
    else        q <= d;
  end
endmodule
```

Example (`designs/sequential/pipeline3.v`):

```verilog
// Three-stage pipeline: a fault in any stage takes a predictable number of
// cycles to reach the output, which is what makes it useful behaviorally.
module pipeline3(input clk, input rst, input [3:0] din, output reg [3:0] dout);
  reg [3:0] s1, s2;
  always @(posedge clk) begin
    if (rst) begin s1 <= 4'd0; s2 <= 4'd0; dout <= 4'd0; end
    else     begin s1 <= din;  s2 <= s1;   dout <= s2;   end
  end
endmodule
```

- [ ] **Step 2: Promote 4 to behavioral**

`counter`, `dff_enable`, `pipeline3`, `simple_fsm`. Their testbenches must drive a real clock, assert reset first, then run enough cycles to show state propagation. Pattern:

```verilog
`timescale 1ns/1ps
module counter_tb;
  reg clk, rst;
  wire [3:0] q;
  integer mut, fd, i;
  reg [1023:0] tracefile;

  counter dut (.clk(clk), .rst(rst), .q(q)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    $fdisplay(fd, "cycle,rst,q");
    rst = 1'b1;
    @(posedge clk); #1;
    $fdisplay(fd, "%0d,%b,%b", 0, rst, q);
    rst = 1'b0;
    for (i = 1; i <= 12; i = i + 1) begin
      @(posedge clk); #1;
      $fdisplay(fd, "%0d,%b,%b", i, rst, q);
    end
    $fclose(fd);
    $finish;
  end
endmodule
```

`counter`'s `behavior.yaml` must include at least one fault whose effect appears only after several cycles (satisfying Phase E.6), and `pipeline3` at least one multi-bit selection on `s1`/`s2` (Phase E.5).

- [ ] **Step 3: Run the category and commit**

```bash
python3 scripts/run_regression.py --manifest-label develop
git add designs/sequential
git commit -m "test: expand sequential corpus to 13 designs, 4 behavioral"
```

Expected: all sequential designs PASS.

---

### Task 12: Corpus — parameterized, hierarchical, structural

**Files:** `designs/parameterized/`, `designs/hierarchical/`, `designs/structural/`

- [ ] **Step 1: parameterized — 7 total (1 behavioral)**

Existing: `parameterized_default.v`, `parameterized_width.v`. Add:

| File | Covers |
|---|---|
| `param_counter.v` | parameterized-width counter |
| `param_mux.v` | parameterized datapath width |
| `param_adder.v` | parameterized arithmetic with carry-out |
| `param_shift.v` | parameterized shift register depth |
| `param_clog2.v` | `$clog2`-derived address width |

`param_clog2.v` is included **only if `$clog2` currently parses cleanly**. Verify first:

```bash
source .workspace/toolchain.env; export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_regression.py --only param_clog2 --manifest-label develop
```

If it does not PASS, delete the file and add `param_bitmask.v` (a parameterized mask built with a shift) instead. Do not keep an unsupported construct in the corpus, and do not add a `CLEAN_REJECT` expectation for it — this corpus is for constructs we support.

Promote `param_counter` to behavioral.

- [ ] **Step 2: hierarchical — 6 total (1 behavioral)**

Existing: `small_hierarchy/`. Add directories, each with `design.json` naming `top`:

| Directory | Covers |
|---|---|
| `nested_instances/` | three levels of instantiation |
| `repeated_instances/` | the same child instantiated several times |
| `cross_hierarchy_signals/` | a signal threaded through two levels |
| `param_child/` | a parameterized child instantiated at two widths |
| `hier_adder/` | full adder built from two half adders — behavioral |

`hier_adder` is the behavioral one: it also proves Muffin's activation port is wired through instances (`MutPortInjector::visitInstance`), which a flat design cannot show. Its `behavior.yaml` should select a fault inside a **child** module.

- [ ] **Step 3: structural — 6 total (1 behavioral)**

Existing: `gate_chain.v`. Add:

| File | Covers |
|---|---|
| `gate_primitives.v` | `and`/`or`/`nand`/`nor`/`xor`/`not` primitives |
| `buf_not_chain.v` | `buf`/`not` chains |
| `mixed_structural_rtl.v` | primitives and `assign` in one module |
| `continuous_assigns.v` | several continuous assignments with intermediate wires |
| `struct_mux/` | structural 2:1 mux — behavioral |

Example (`designs/structural/mixed_structural_rtl.v`):

```verilog
// Primitive gates and continuous assignment in the same module - the mixture
// is the point, since the two reach HIF by different paths.
module mixed_structural_rtl(input a, input b, input c, output y, output z);
  wire ab;
  and g1(ab, a, b);
  assign y = ab ^ c;
  assign z = ~ab;
endmodule
```

- [ ] **Step 4: Run the full corpus**

```bash
python3 scripts/run_regression.py --manifest-label develop
```

Expected: 48 designs, all PASS, zero CRASH/TIMEOUT/FAIL.

- [ ] **Step 5: Commit**

```bash
git add designs/parameterized designs/hierarchical designs/structural
git commit -m "test: expand parameterized, hierarchical and structural corpora"
```

---

### Task 13: faults.json correspondence and detected/undetected coverage

Closes Phase E.4 and E.7 explicitly rather than incidentally.

**Files:** `designs/**/behavior.yaml`, `tests/test_correspondence.py`

- [ ] **Step 1: Write a test proving a resolved id selects the expected behavior**

```python
# tests/test_correspondence.py
"""Phase E.4: the declaratively-selected fault must be the one that actually
fires. Guards against a resolver that returns a plausible-but-wrong id."""
import json, sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from record_lookup import resolve_record

REPORT = Path("reports/curated-report.json")


class TestFaultCorrespondence(unittest.TestCase):
    @unittest.skipUnless(REPORT.exists(), "needs a curated run first")
    def test_every_resolved_id_matches_its_declared_attributes(self):
        report = json.loads(REPORT.read_text())
        checked = 0
        for case in report.get("behavioral", []):
            selection = case.get("fault_selection")
            if not selection or case.get("resolved_fault_id") is None:
                continue
            faults_path = Path(case["left"]).parents[2] / "enumerate"
            candidates = list(faults_path.glob("*.faults.json"))
            self.assertEqual(len(candidates), 1, f"{case['design']}: faults.json not found")
            document = json.loads(candidates[0].read_text())
            expected = resolve_record(document, "faults", selection, "id", "correspondence")
            self.assertEqual(expected, case["resolved_fault_id"],
                             f"{case['design']}/{case['case']}: id drifted from its attributes")
            checked += 1
        self.assertGreater(checked, 0, "no fault selections were checked")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it against a fresh curated run**

```bash
python3 scripts/run_regression.py --manifest-label develop
python3 -m unittest tests.test_correspondence -v
```

Expected: PASS, with `checked > 0`.

- [ ] **Step 3: Audit detected/undetected coverage**

```bash
python3 - <<'PY'
import json
r = json.load(open("reports/curated-report.json"))
kinds = {}
for c in r.get("behavioral", []):
    kinds.setdefault(c["validator"], []).append(f"{c['design']}/{c['case']}")
for k in sorted(kinds):
    print(f"{k:16} {len(kinds[k])}  e.g. {kinds[k][0]}")
PY
```

Expected: at least one `trace_differs` case (a detected fault) and at least one `trace_equal` case comparing an *active fault* run against the reference (an undetected fault). If the undetected case is missing, add one — `and2`'s SA1 at the `a=b=1` vector is the canonical example, and `reduction_ops`' `any_one` output is another.

- [ ] **Step 4: Commit**

```bash
git add tests/test_correspondence.py designs
git commit -m "test: fault-id correspondence and explicit detected/undetected coverage"
```

---

### Task 14: Documentation and CI provisioning

**Files:**
- Create: `docs/adding-things.md`
- Modify: `README.md`
- Modify: `.github/workflows/nightly.yml`

- [ ] **Step 1: Write `docs/adding-things.md`**

Five short how-to sections, each ending in a runnable command:

1. **A new transformation tool** — add to `tools.yaml` (`command` + `artifact`), reference from a pipeline. No code.
2. **A new simulator** — add to `simulators.yaml` (`compile`/`run`, artifact templates, `param_template`). No code unless the invocation model itself is new.
3. **A new validator** — add to `validators.yaml` picking an existing `impl`; write a new `impl` in `validators.py` only for genuinely new comparison logic, and register it in `IMPLS` and `manifest_schema.KNOWN_IMPLS`.
4. **A new pipeline** — add to `pipelines.yaml` as an ordered `operations` list; set `suite_defaults` or a per-design `pipeline` override.
5. **A new curated behavioral test** — promote the design to directory form, add `design.json` (`sources`/`fixtures`), a testbench following the `` `ifdef MUFFIN_MUT `` + plusargs + CSV convention, and `behavior.yaml` (`runs` / `expectations`).

Include the **placeholder reference table** (scalar vs list) and the worked, non-wired future-flow example:

```yaml
# Illustrative only - not wired into any pipeline. Shows that the future
# `Verilog -> FE -> DDT -> A2Tool -> C++ backend -> run C++ -> compare against
# RTL` flow needs manifest entries, not engine changes.
#
# tools.yaml:
#   ddt:      {consumes: hif, produces: hif,  command: [...], artifact: "..."}
#   a2tool:   {consumes: hif, produces: hif,  command: [...], artifact: "..."}
#   hif2cpp:  {consumes: hif, produces: cpp,  command: [...], artifact: "..."}
#
# simulators.yaml:
#   cxx_binary:
#     language: cpp
#     compile: {command: ["g++", "{options}", "-o", "{workdir}/model", "{sources}"],
#               artifact: "{workdir}/model"}
#     run:     {command: ["{compiled}", "{params}", "--trace={trace}"],
#               artifact: "{rundir}/trace.csv", param_template: "--{key}={value}"}
#
# pipelines.yaml:
#   rtl_vs_cpp:
#     operations:
#       - {id: frontend,  kind: tool, use: verilog2hif}
#       - {id: ddt,       kind: tool, use: ddt}
#       - {id: a2tool,    kind: tool, use: a2tool}
#       - {id: cpp,       kind: tool, use: hif2cpp}
#       - {id: sim_rtl,   kind: simulation, use: iverilog,
#          sources: [{design: sources}, {fixture: testbench}], runs: [{id: reference}]}
#       - {id: sim_cpp,   kind: simulation, use: cxx_binary,
#          sources: [{from: cpp}, {fixture: harness}], runs: [{id: reference}]}
#       - {id: equivalent, kind: validation, cases: [
#           {id: rtl_matches_cpp, use: trace_equal,
#            left: {from: sim_rtl, run: reference}, right: {from: sim_cpp, run: reference}}]}
```

- [ ] **Step 2: Update `README.md`**

Replace the "To add a new tool" paragraph in the curated-corpus section with a pointer to `docs/adding-things.md`, describe the three operation kinds, note that behavioral coverage is an orthogonal capability (directory form inside the existing category, never a separate category), and state that `iverilog`/`vvp` must be on PATH for behavioral pipelines and are provisioned by the environment, not by this repo.

- [ ] **Step 3: Provision iverilog and run engine tests in CI**

In `.github/workflows/nightly.yml`, change the dependency line to:

```yaml
          sudo apt-get install -y g++ libpoco-dev flex bison iverilog
```

and add a step before the build:

```yaml
      - name: Engine unit tests
        run: python3 -m unittest discover -s tests -v
```

- [ ] **Step 4: Commit**

```bash
git add docs/adding-things.md README.md .github/workflows/nightly.yml
git commit -m "docs: how to add tools, simulators, validators, pipelines and behavioral tests"
```

---

### Task 15: Full validation sequence

Phase H, run in order. Nothing here is optional.

- [ ] **Step 1: Engine unit tests**

Run: `python3 -m unittest discover -s tests -v`
Expected: all PASS.

- [ ] **Step 2: Per-repo CTest**

```bash
source .workspace/toolchain.env
export PATH="$PREFIX/bin:$PATH"; export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
python3 scripts/run_ctest_suites.py --workspace "$WORKSPACE"
```

Expected: all four repos' suites PASS.

- [ ] **Step 3: Original-fixture equivalence**

Confirm each of the 12 original designs still appears and still PASSes:

```bash
python3 scripts/run_regression.py --manifest-label develop
python3 - <<'PY'
import json
original = ["combinational/and2", "combinational/decoder", "combinational/full_adder",
            "combinational/mux2", "combinational/small_alu", "hierarchical/small_hierarchy",
            "parameterized/parameterized_default", "parameterized/parameterized_width",
            "sequential/counter", "sequential/shift_register", "sequential/simple_fsm",
            "structural/gate_chain"]
r = json.load(open("reports/curated-report.json"))
got = {d["category"] + "/" + d["name"]: d["overall_status"] for d in r["designs"]}
missing = [k for k in original if k not in got]
bad = {k: got[k] for k in original if got.get(k) not in (None, "PASS")}
print("missing:", missing or "none")
print("not PASS:", bad or "none")
raise SystemExit(1 if (missing or bad) else 0)
PY
```

Expected: `missing: none`, `not PASS: none`.

- [ ] **Step 4: Full expanded corpus**

Expected from the same run: 48 designs, all PASS, zero CRASH/TIMEOUT/FAIL.

- [ ] **Step 5: Behavioral subset**

Expected: every behavioral case PASS, including at least one detected and one undetected fault, at least one multi-bit selection, and at least one sequential design.

- [ ] **Step 6: No product-specific branching**

```bash
grep -rnE 'muffin|verilog2hif|hif2verilog|iverilog|vvp|MutPort' \
  scripts/pipeline_engine.py scripts/simulation.py scripts/validators.py \
  scripts/placeholders.py scripts/record_lookup.py scripts/manifest_schema.py \
  | grep -v '^\s*#' | grep -vE '^\S+:[0-9]+:\s*(\*|-|"""|\')'
```

Expected: no output outside comments/docstrings. A hit in executable code is a failure to fix, not to explain.

- [ ] **Step 7: External regression smoke check**

External code and manifests are untouched, so a full rerun proves nothing and costs hours. A targeted smoke check is sufficient:

```bash
python3 scripts/run_external_regression.py --help >/dev/null && echo "external runner intact"
git diff --stat main -- scripts/run_external_regression.py manifests/external-benchmarks.yml manifests/expectations/
```

Expected: `external runner intact`, and an empty diff.

- [ ] **Step 8: Record the behavioral summary**

```bash
python3 scripts/report.py | tee /tmp/claude-1000/-home-enrico-repository-hif/3e305375-b44f-4cec-bf4b-c5ca4711e22e/scratchpad/final-summary.md
```

- [ ] **Step 9: Commit any fixes, then open the PR**

```bash
git push -u origin feat/simulation-validation-architecture
gh pr create --title "Simulation and validation as first-class regression concepts" --body "..."
```

Use `superpowers:finishing-a-development-branch` for the merge decision. Do not merge until CI is green.

---

## Notes for the implementer

- **The engine must stay ignorant.** If you find yourself wanting `if op["use"] == "muffin_list_faults"`, the information belongs in a manifest or in `behavior.yaml`. This is the single most important constraint in the plan.
- **Oracles are derived, then confirmed — never copied from output.** Writing an expected CSV by running the simulator and pasting the result proves nothing. Derive it from the instrumentation semantics (`rhs | (1<<bit)` / `rhs & ~(1<<bit)`, or a literal `0`/`1` when the location is 1 bit wide), then check it matches.
- **A failing new fixture is usually a wrong fixture.** But if the generated Verilog or the fault behavior genuinely disagrees with the documented semantics, stop and report per the spec's constraints section rather than adjusting the expectation.
