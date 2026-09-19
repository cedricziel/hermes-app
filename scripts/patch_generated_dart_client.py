#!/usr/bin/env python3
"""Fixes dart-dio + json_serializable template bugs in the freshly
generated `packages/hermes_api` sources (run between `openapi-generator-cli
generate` and `dart analyze` in scripts/generate_hermes_api_client.sh):

1. Optional constructor parameters default to a bare `[]`/`{}` for
   list/map-typed properties (e.g. `this.branches = [],`). Dart requires
   default parameter values to be compile-time constants, and a bare
   collection literal there is *not* implicitly const (unlike, say, an
   annotation argument) — `dart analyze` rejects it with
   `non_constant_default_value`. Rewritten to `this.branches = const [],`.
2. A string-enum property with a `default` (e.g.
   `MoaConfigPayload.degraded_reference_policy`) generates a constructor
   call to a private, non-existent `Enum._('value')` constructor instead of
   referencing the matching enum constant. Rewritten to
   `EnumType.memberName`, deriving `memberName` the same way the generator
   names enum members (lowerCamelCase of the raw value).
3. `lib/src/api/*.dart` files sometimes import a response-only model (e.g.
   `HTTPValidationError`, referenced only in a doc comment for the generic
   422 response) that the generated code never actually names, tripping
   `unused_import`. Any such import is dropped.
4. The same enum-defaulted properties from fix 2 also carry a
   `@JsonKey(defaultValue: 'value', ...)` used by the *generated* `fromJson`
   (`...g.dart`) as the fallback when the key is missing/null, alongside an
   `unknownEnumValue: EnumType.unknownDefaultOpenApi` in the same
   annotation. json_serializable treats `defaultValue` as opaque, so it
   passes the raw string straight through next to the enum decode's `??`,
   which the analyzer accepts (dynamic) but the compiler rejects (`Object`
   isn't `EnumType?`). Rewritten to `defaultValue: EnumType.memberName`.
5. The generator always writes a fresh `.gitignore` that excludes
   `pubspec.lock` (its "library package" default). This repo commits it
   deliberately, so CI's drift check (regenerate and diff) isn't at the
   mercy of an unrelated transitive dependency picking up a new version
   between two runs — see the comment left in its place.
6. Routes whose spec declares an empty response schema (`{}`, e.g. every
   `/api/sessions*` route) get `deserialize<Object, Object>(data, 'Object')`
   calls, but the generated `deserialize` has no `'Object'` case and throws
   `Cannot deserialize` on any real body. An `'Object'` case that passes the
   decoded JSON through is added.
"""

import re
import sys
from pathlib import Path

_BARE_COLLECTION_DEFAULT = re.compile(r"^(\s+this\.\w+ = )(\[\]|\{\})(,)$", re.MULTILINE)
_BROKEN_ENUM_DEFAULT = re.compile(r"const (\w+Enum)\._\('([^']*)'\)")
_ENUM_JSON_KEY_DEFAULT = re.compile(
    r"defaultValue: '([^']*)',([\s\S]*?)unknownEnumValue: (\w+Enum)\.unknownDefaultOpenApi,"
)
_MODEL_IMPORT = re.compile(
    r"^import 'package:hermes_api/src/model/([\w]+)\.dart';$", re.MULTILINE
)
_CLASS_DECL = re.compile(r"^(?:abstract )?class (\w+)", re.MULTILINE)


def _enum_member_name(value: str) -> str:
    parts = re.split(r"[^0-9a-zA-Z]+", value)
    parts = [p for p in parts if p]
    if not parts:
        return value
    head, *rest = parts
    return head.lower() + "".join(p[:1].upper() + p[1:].lower() for p in rest)


def patch_model_source(text: str) -> str:
    text = _BARE_COLLECTION_DEFAULT.sub(r"\1const \2\3", text)
    text = _BROKEN_ENUM_DEFAULT.sub(
        lambda m: f"{m.group(1)}.{_enum_member_name(m.group(2))}", text
    )
    text = _ENUM_JSON_KEY_DEFAULT.sub(
        lambda m: (
            f"defaultValue: {m.group(3)}.{_enum_member_name(m.group(1))},"
            f"{m.group(2)}unknownEnumValue: {m.group(3)}.unknownDefaultOpenApi,"
        ),
        text,
    )
    return text


def _model_class_name(model_dir: Path, module: str) -> str | None:
    path = model_dir / f"{module}.dart"
    if not path.exists():
        return None
    match = _CLASS_DECL.search(path.read_text())
    return match.group(1) if match else None


def drop_unused_model_imports(text: str, model_dir: Path) -> str:
    for match in list(_MODEL_IMPORT.finditer(text)):
        module = match.group(1)
        class_name = _model_class_name(model_dir, module)
        if class_name is None:
            continue
        rest = text[: match.start()] + text[match.end() :]
        if not re.search(rf"\b{re.escape(class_name)}\b", rest):
            text = rest
    return text


_UNTYPED_CASE = re.compile(r"case\s+'Object'\s*:")
_DESERIALIZE_DEFAULT = re.compile(
    r"^(?P<indent>[ \t]*)default:\s*RegExpMatch\? match;", re.MULTILINE
)


def accept_untyped_objects(package_dir: Path) -> None:
    path = package_dir / "lib" / "src" / "deserialize.dart"
    text = path.read_text()
    if _UNTYPED_CASE.search(text):
        return
    match = _DESERIALIZE_DEFAULT.search(text)
    if match is None:
        raise SystemExit(f"{path}: could not find the deserialize default case")
    indent = match.group("indent")
    case = f"{indent}case 'Object':\n{indent}  return value as ReturnType;\n"
    path.write_text(text[: match.start()] + case + text[match.start() :])
    print(f"patched {path}")


def keep_pubspec_lock(package_dir: Path) -> None:
    gitignore = package_dir / ".gitignore"
    text = gitignore.read_text()
    patched = text.replace(
        "# Don't commit pubspec lock file\n"
        "# (Library packages only! Remove pattern if developing an application package)\n"
        "pubspec.lock\n",
        "# pubspec.lock IS committed here, unlike the usual library-package advice:\n"
        "# CI's drift check (.github/workflows/verify-hermes-api-client.yml)\n"
        "# regenerates this package and diffs it against what's committed, and an\n"
        "# unpinned lockfile would let unrelated transitive dependency upgrades\n"
        "# (e.g. a new json_serializable patch release) fail that check.\n",
    )
    if patched != text:
        gitignore.write_text(patched)
        print(f"patched {gitignore}")


def main() -> None:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <generated-package-dir>", file=sys.stderr)
        raise SystemExit(1)

    package_dir = Path(sys.argv[1])
    model_dir = package_dir / "lib" / "src" / "model"

    for path in sorted(model_dir.glob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        original = path.read_text()
        patched = patch_model_source(original)
        if patched != original:
            path.write_text(patched)
            print(f"patched {path}")

    for path in sorted((package_dir / "lib" / "src" / "api").glob("*.dart")):
        original = path.read_text()
        patched = drop_unused_model_imports(original, model_dir)
        if patched != original:
            path.write_text(patched)
            print(f"patched {path}")

    accept_untyped_objects(package_dir)
    keep_pubspec_lock(package_dir)


if __name__ == "__main__":
    main()
