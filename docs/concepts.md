# How the runner works

The model behind `designs/` and `manifests/`. You need this to add a *pipeline*
or a *tool*; you can add a design without it.

- [Designs, pipelines, operations](#designs-pipelines-operations)
- [The three operation kinds](#the-three-operation-kinds)
- [Placeholders](#placeholders)
- [Why there is no scheduler](#why-there-is-no-scheduler)

## Designs, pipelines, operations

A **design** is a source file (or a directory, for multi-file and behavioral
designs) under `designs/<category>/`. It is run through a **pipeline**: an
ordered list of **operations**, named in `manifests/pipelines.yaml`.

Every category has a default pipeline (`suite_defaults` in `pipelines.yaml`). A
design only needs to say anything when it deviates, via a `"pipeline"` key in
its sidecar.

The runner has no tool-, simulator- or validator-specific knowledge. Adding any
of those is a manifest change, not a code change — that is the property to
preserve when extending it.

## The three operation kinds

Each operation has an `id` (independent of whatever implements it), a `kind`,
and a `use` naming an entry in that kind's registry.

| kind | registry | consumes | produces | asserts |
|---|---|---|---|---|
| `tool` | `manifests/tools.yaml` | artifacts | artifacts | nothing |
| `simulation` | `manifests/simulators.yaml` | sources + stimulus | traces | nothing |
| `validation` | `manifests/validators.yaml` | results | a verdict | yes |

These stay distinct on purpose. A simulation that also decided pass/fail would
hide *why* a behavioral test failed; a validator that also ran a simulator could
not be reused across simulators.

The `id` doubles as the stage key in the JSON report, which is why a failure is
attributable to a step rather than to "the pipeline".

## Placeholders

Fixed, and the only substitution that exists — this is argv construction, not a
scripting language.

**Scalar**, substituted inside a token:

| | meaning |
|---|---|
| `{input}` | first input path |
| `{workdir}` | this operation's working directory |
| `{name}` | the design's top-level name |
| `{top}` | simulation top (default `{name}_tb`) |
| `{compiled}` | artifact produced by the compile phase |
| `{rundir}` | this run's directory |
| `{trace}` | this run's result artifact |

**List**, which must be the *entire* token and expands to zero or more argv
entries:

`{inputs}` `{sources}` `{defines}` `{params}` `{options}`

A list placeholder inside a larger token is an error, not a silent
`str(list)`. An unknown placeholder is an error naming the operation and the
token.

## Why there is no scheduler

Operations execute strictly top to bottom and stop at the first non-`PASS`.
There is no DAG and no dependency resolution: an operation with no explicit
`inputs` consumes its predecessor's artifact, and an explicit `inputs: [<id>]`
names an earlier operation.

This is a deliberate ceiling. The flows this repo validates are chains, a chain
is fully described by an ordered list, and stopping at the first failure is what
keeps a report readable — a design that crashed in the frontend has nothing
useful to say about its backend stage.
