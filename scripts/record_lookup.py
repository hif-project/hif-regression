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
