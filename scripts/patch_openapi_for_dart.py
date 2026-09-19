#!/usr/bin/env python3
"""Applies small, targeted fixes to the Hermes Agent OpenAPI spec that the
`dart-dio` OpenAPI Generator template cannot render correctly, then writes
the result to a new file. The checked-in `openapi/hermes-agent.openapi.json`
(pulled straight from the backend) is left untouched — only the copy used
for code generation is patched.

Known generator limitations worked around here:

1. `ValidationError.loc.items` is `anyOf: [string, integer]` (FastAPI's
   standard validation-error location path). The dart-dio template turns a
   multi-type `anyOf` with no shared properties into a wrapper model whose
   generated `==`/`hashCode` reference an empty field list, producing
   invalid Dart. Dropping the `anyOf` maps it to a plain `List<Object>`
   instead, which round-trips the same values without the broken wrapper.
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
"""

import json
import sys


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

    loc_items = schemas["ValidationError"]["properties"]["loc"]["items"]
    loc_items.pop("anyOf", None)

    for model_name in ("MoaConfigPayload", "MoaPresetPayload"):
        schemas[model_name]["properties"]["aggregator"].pop("default", None)

    _drop_composed_any(schemas)

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
