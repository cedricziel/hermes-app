#!/usr/bin/env python3
"""Applies small, targeted fixes to the Hermes Agent OpenAPI spec that the
`dart-dio` OpenAPI Generator template cannot render correctly, then writes
the result to a new file. The checked-in `openapi/hermes-agent.openapi.json`
(pulled straight from the backend) is left untouched — only the copy used
for code generation is patched.

Known generator limitations worked around here:

1. An `anyOf`/`oneOf` of two or more primitive types, such as
   `ValidationError.loc.items` (`[string, integer]`, FastAPI's standard
   validation-error location path) or `CronJobCreate.repeat` (`[integer,
   string, null]`). The dart-dio template turns it into a wrapper model
   whose generated `==`/`hashCode` reference an empty field list, producing
   invalid Dart. Dropping the `anyOf` maps it to a plain `Object` instead,
   which round-trips the same values without the broken wrapper.
2. `MoaConfigPayload.aggregator` / `MoaPresetPayload.aggregator` declare an
   object-typed `default` (`{"provider": "", "model": "", "enabled": true}`).
   The template can't render a Dart map literal for an object default and
   emits invalid syntax (`{provider=, model=, enabled=true}`). Dropping the
   `default` is safe: the field stays nullable and the server applies its
   own default regardless.
3. Any `anyOf`/`oneOf` with an empty (`{}`, i.e. "any type") member — e.g.
   `CronJobCreate.context_from`'s `Optional[Any]` (`anyOf: [{}, {type:
   null}]`) — makes the generator emit a synthetic `AnyOf` model that
   json_serializable can't (de)serialize. Dropping the `anyOf`/`oneOf`
   entirely leaves a schema with no declared type, which the generator maps
   straight to a nullable `Object` instead.
4. A string `enum` with an empty-string value, such as
   `CustomEndpointUpdate.api_mode` (`""` meaning "detect it"). The template
   names enum values after their text, so `""` becomes a member with no
   name (`CustomEndpointUpdateApiModeEnum.`). Dropping the `enum` leaves a
   plain `String`, which still accepts every value.
"""

import json
import sys

_PRIMITIVES = {"string", "integer", "number", "boolean"}


def _drop_mixed_primitives(node) -> None:
    """Recursively drops any anyOf/oneOf whose members are two or more
    primitive types (see module docstring, fix 1)."""
    if isinstance(node, dict):
        for key in ("anyOf", "oneOf"):
            members = node.get(key)
            if not isinstance(members, list):
                continue
            types = [m.get("type") for m in members if isinstance(m, dict)]
            if len(types) == len(members) and all(
                t in _PRIMITIVES or t == "null" for t in types
            ) and len({t for t in types if t != "null"}) >= 2:
                del node[key]
        for value in node.values():
            _drop_mixed_primitives(value)
    elif isinstance(node, list):
        for item in node:
            _drop_mixed_primitives(item)


def _drop_empty_enum_values(node) -> None:
    """Recursively drops any string enum that lists `""` (see module
    docstring, fix 4)."""
    if isinstance(node, dict):
        if node.get("type") == "string" and "" in node.get("enum", []):
            del node["enum"]
        for value in node.values():
            _drop_empty_enum_values(value)
    elif isinstance(node, list):
        for item in node:
            _drop_empty_enum_values(item)


def _drop_composed_any(node) -> None:
    """Recursively drops any anyOf/oneOf that includes an empty (`{}`)
    member, since that combination breaks dart-dio codegen (see module
    docstring, fix 3)."""
    if isinstance(node, dict):
        for key in ("anyOf", "oneOf"):
            members = node.get(key)
            if isinstance(members, list) and any(m == {} for m in members):
                del node[key]
        for value in node.values():
            _drop_composed_any(value)
    elif isinstance(node, list):
        for item in node:
            _drop_composed_any(item)


def patch(spec: dict) -> dict:
    schemas = spec["components"]["schemas"]

    for model_name in ("MoaConfigPayload", "MoaPresetPayload"):
        schemas[model_name]["properties"]["aggregator"].pop("default", None)

    _drop_composed_any(schemas)
    _drop_mixed_primitives(schemas)
    _drop_empty_enum_values(schemas)

    return spec


def main() -> None:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <input-spec> <output-spec>", file=sys.stderr)
        raise SystemExit(1)

    with open(sys.argv[1]) as f:
        spec = json.load(f)

    patch(spec)

    with open(sys.argv[2], "w") as f:
        json.dump(spec, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
