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
