import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';

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

  test('the generated locales are exactly the ARB files', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.toLanguageTag()).toSet(),
      {template.locale, for (final arb in translations) arb.locale},
      reason: 'run `flutter gen-l10n` (or `flutter pub get`) after an ARB edit',
    );
  });

  test('every released locale has an ARB file', () {
    expect(AppLocalizations.supportedLocales, containsAll(kReleasedLocales));
    expect(kReleasedLocales, contains(const Locale('en')));
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
          final prefix = areaPrefix(area);
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

  test('every template message has a description', () {
    for (final key in template.messages) {
      final meta = template.json['@$key'];
      expect(
        meta is Map && meta['description'] is String,
        isTrue,
        reason: '"@$key" needs a description for translators',
      );
    }
  });

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

    test('${arb.path} uses the same placeholders as the template', () {
      for (final key in template.messages.intersection(arb.messages)) {
        final declared = template.placeholders(key);
        expect(
          _used(arb.json[key]! as String, declared),
          _used(template.json[key]! as String, declared),
          reason:
              '"$key" in ${arb.locale} must use the placeholders the '
              'English text uses',
        );
      }
    });
  }

  test('areaPrefix turns an anchor into the key prefix', () {
    expect(areaPrefix('settings'), 'settings');
    expect(areaPrefix('bot_mode'), 'botMode');
    expect(areaPrefix('chat/queue_storage'), 'chatQueueStorage');
  });
}

/// The key prefix of an area: `bot_mode` is `botMode`, `chat/widgets` is
/// `chatWidgets`.
String areaPrefix(String area) {
  final parts = area.split(RegExp('[_/]'));
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// Which of [declared] appear as `{name}` or `{name, …}` in [message].
Set<String> _used(String message, Set<String> declared) => {
  for (final name in declared)
    if (RegExp('\\{$name[,}\\s]').hasMatch(message)) name,
};

class _Arb {
  _Arb(this.path, this.json, this.duplicates);

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
    return _Arb(path, json, duplicates);
  }

  final String path;
  final Map<String, Object?> json;
  final Set<String> duplicates;

  List<String> get keys => json.keys.toList();
  String get locale => json['@@locale']! as String;

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

  /// The placeholders declared in [key]'s metadata.
  Set<String> placeholders(String key) => switch (json['@$key']) {
    {'placeholders': final Map<String, Object?> p} => p.keys.toSet(),
    _ => const {},
  };
}
