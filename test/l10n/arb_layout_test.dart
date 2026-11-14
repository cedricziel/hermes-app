import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the ARB files in the layout docs/architecture/localization.md
/// describes, which is what lets several pull requests add strings at once
/// without merge conflicts: one `@@x-area-<directory>` anchor per area, in
/// the same order in every locale, each followed by that area's keys only.
void main() {
  const dir = 'lib/l10n/arb';
  final template = _Arb.read('$dir/app_en.arb');
  final translations = [
    for (final file in Directory(dir).listSync().whereType<File>())
      if (file.path.endsWith('.arb') && !file.path.endsWith('app_en.arb'))
        _Arb.read(file.path),
  ];

  test('there is a German translation', () {
    expect(translations.map((arb) => arb.locale), contains('de'));
  });

  for (final arb in [template, ...translations]) {
    group(arb.path, () {
      test('has no key twice', () {
        expect(arb.duplicates, isEmpty);
      });

      test('starts with @@locale and ends with @@x-end', () {
        expect(arb.keys.first, '@@locale');
        expect(arb.keys.last, '@@x-end');
      });

      test('puts each key under the anchor of its area, sorted', () {
        for (final MapEntry(key: area, value: keys) in arb.areas.entries) {
          final prefix = _camel(area);
          for (final key in keys) {
            expect(
              key.startsWith(prefix) &&
                  key.length > prefix.length &&
                  key[prefix.length] == key[prefix.length].toUpperCase(),
              isTrue,
              reason:
                  '"$key" sits under @@x-area-$area, so it must start '
                  'with "$prefix" followed by a capital letter',
            );
          }
          expect(
            keys,
            [...keys]..sort(),
            reason: 'keys under @@x-area-$area must be in alphabetical order',
          );
        }
      });

      test('follows each message with its own @metadata only', () {
        final keys = arb.keys;
        for (var i = 0; i < keys.length; i++) {
          final key = keys[i];
          if (!key.startsWith('@') || key.startsWith('@@')) continue;
          expect(
            i > 0 && keys[i - 1] == key.substring(1),
            isTrue,
            reason: '"$key" must come right after "${key.substring(1)}"',
          );
        }
      });
    });
  }

  test('the areas are in alphabetical order after common', () {
    final areas = template.areas.keys.toList();
    expect(areas.first, 'common');
    expect(areas.skip(1), [...areas.skip(1)]..sort());
  });

  for (final arb in translations) {
    test('${arb.path} has the same areas as the template', () {
      expect(arb.areas.keys, template.areas.keys);
    });

    test('${arb.path} translates every message of the template', () {
      final missing = template.messages.difference(arb.messages);
      final extra = arb.messages.difference(template.messages);
      expect(missing, isEmpty, reason: 'untranslated in ${arb.locale}');
      expect(extra, isEmpty, reason: 'not in the template');
    });
  }
}

String _camel(String area) {
  final parts = area.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

class _Arb {
  _Arb(this.path, this.keys, this.duplicates, this.locale);

  factory _Arb.read(String path) {
    final text = File(path).readAsStringSync();
    final json = jsonDecode(text) as Map<String, Object?>;
    // jsonDecode keeps the last of two equal keys, so count them in the text.
    final seen = <String>{};
    final duplicates = <String>{};
    for (final match in RegExp(
      r'^  "([^"]+)":',
      multiLine: true,
    ).allMatches(text)) {
      if (!seen.add(match.group(1)!)) duplicates.add(match.group(1)!);
    }
    return _Arb(
      path,
      json.keys.toList(),
      duplicates,
      json['@@locale']! as String,
    );
  }

  final String path;
  final List<String> keys;
  final Set<String> duplicates;
  final String locale;

  static const _anchor = '@@x-area-';

  /// Each area's message keys, by area, in file order.
  Map<String, List<String>> get areas {
    final areas = <String, List<String>>{};
    List<String>? current;
    for (final key in keys) {
      if (key.startsWith(_anchor)) {
        current = areas[key.substring(_anchor.length)] = [];
      } else if (!key.startsWith('@')) {
        expect(current, isNotNull, reason: '"$key" comes before any area');
        current!.add(key);
      }
    }
    return areas;
  }

  Set<String> get messages => {
    for (final key in keys)
      if (!key.startsWith('@')) key,
  };
}
