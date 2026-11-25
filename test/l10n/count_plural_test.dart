import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards translated count messages: a message with an `int` or `num`
/// placeholder must use an ICU `plural` (or `select`) over one of them in
/// every locale's ARB file, so a word that changes with the number can
/// change. The German workers count read "1 laufen" until it became
/// `{count, plural, =1{1 läuft} other{{count} laufen}}`.
///
/// Not every number is a count: an id, a percentage, a ratio, a clock value or
/// an exit code takes no inflection. Those messages are on [_noPlural], one
/// reason each. The rule reads a message as a whole: one plural over any of its
/// numbers satisfies it, so a second uninflected number next to a plural one
/// is for a review to see (`chatContextOutcomeMessages`).
void main() {
  const dir = 'lib/l10n/arb';
  final template = _read('$dir/app_en.arb');
  final locales = <String, Map<String, dynamic>>{
    for (final file in Directory(dir).listSync().whereType<File>())
      if (file.path.endsWith('.arb'))
        RegExp(r'app_(\w+)\.arb').firstMatch(file.path)!.group(1)!: _read(
          file.path,
        ),
  };

  /// Key to its count placeholders, read from the English template, which
  /// holds the `@key` metadata every locale shares.
  final counts = <String, List<String>>{
    for (final key in template.keys)
      if (!key.startsWith('@') && template['@$key'] is Map)
        if (_countPlaceholders(template['@$key'] as Map) case final names
            when names.isNotEmpty)
          key: names,
  };

  bool inflects(String message, List<String> names) => names.any(
    (name) => RegExp('\\{$name\\s*,\\s*(plural|select)\\b').hasMatch(message),
  );

  test('every count message has a plural form in each locale', () {
    final failures = <String>[];
    for (final MapEntry(key: locale, value: arb) in locales.entries) {
      for (final MapEntry(key: key, value: names) in counts.entries) {
        final message = arb[key];
        if (message is! String) continue;
        if (_noPlural[key]?.appliesTo(locale) ?? false) continue;
        if (inflects(message, names)) continue;
        failures.add(
          '$key in app_$locale.arb ("$message") has the count '
          '${names.map((n) => '{$n}').join(', ')} but no plural form: write '
          '{${names.first}, plural, =1{...} other{...}} so a word next to the '
          'number agrees with it (see kanbanWorkersRunning in app_de.arb), or, '
          'when no word in the message changes with the number, put the key '
          'on _noPlural in test/l10n/count_plural_test.dart with its reason.',
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every allowlist entry still names a message that needs it', () {
    final stale = <String>[];
    for (final MapEntry(key: key, value: entry) in _noPlural.entries) {
      final names = counts[key];
      final needed =
          names != null &&
          locales.entries.any(
            (l) =>
                entry.appliesTo(l.key) &&
                l.value[key] is String &&
                !inflects(l.value[key] as String, names),
          );
      if (!needed) {
        stale.add(
          '$key is on _noPlural but is gone, has no count placeholder or '
          'already has a plural in every locale it covers: remove the entry.',
        );
      }
    }
    expect(stale, isEmpty, reason: stale.join('\n'));
  });

  group('the rule', () {
    test('rejects the German workers count before the plural', () {
      expect(inflects('{count} laufen', ['count']), isFalse);
      expect(
        inflects('{count, plural, =1{1 läuft} other{{count} laufen}}', [
          'count',
        ]),
        isTrue,
      );
    });

    test('reads a plural over another count of the message', () {
      expect(
        inflects('{before} → {after, plural, =1{1 message} other{x}}', [
          'before',
          'after',
        ]),
        isTrue,
      );
    });
  });
}

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<String> _countPlaceholders(Map meta) {
  final placeholders = meta['placeholders'];
  if (placeholders is! Map) return const [];
  return [
    for (final MapEntry(:key, :value) in placeholders.entries)
      if (value is Map && (value['type'] == 'int' || value['type'] == 'num'))
        key as String,
  ];
}

class _Reason {
  const _Reason(this.why, {this.locales});

  final String why;

  /// The locales the entry covers; all of them when null.
  final Set<String>? locales;

  bool appliesTo(String locale) => locales?.contains(locale) ?? true;
}

/// Messages with a number that needs no plural form, with the reason.
const _noPlural = <String, _Reason>{
  'chatActivityLinePlanCounter': _Reason('a ratio, no word'),
  'chatActivityLinePlanCounterLabel': _Reason('a ratio read as "plan 2 of 5"'),
  'chatActivityLineReferencesCounter': _Reason('a ratio, no word'),
  'chatActivityNeedsYouConnectManyTitle': _Reason(
    'only built for two or more services; one has its own key '
    '(chatActivityNeedsYouConnectTitle)',
  ),
  'chatActivityNeedsYouExpires': _Reason('a unit abbreviation (min, Min.)'),
  'chatActivityNeedsYouPosition': _Reason('a position "1 of 3", no noun'),
  'chatCheckpointsChangesCountsAddedRemoved': _Reason('+n and −n, no word'),
  'chatCheckpointsFileCounts': _Reason('"n added, m removed": participles'),
  'chatCheckpointsPageRowCount': _Reason('a label, a separator and a number'),
  'chatCheckpointsPageTimeHours': _Reason('a unit abbreviation (h, Std.)'),
  'chatCheckpointsPageTimeMinutes': _Reason('a unit abbreviation (min, Min.)'),
  'chatContextBarLabel': _Reason('a percentage'),
  'chatContextBarLabelEstimated': _Reason('a percentage'),
  'chatContextPercent': _Reason('a percentage'),
  'chatSubagentsNoteCounter': _Reason('a limit "3 / 10", no word'),
  'chatWidgetsProgramStateExited': _Reason('an exit code'),
  'filesListCapFooter': _Reason(
    'shown only when the list is cut at a cap far above one; "first n of m"',
  ),
  'kanbanCardProgress': _Reason(
    'a ratio "2 of 5 done": no noun, and the participle does not change',
  ),
  'kanbanEstimateKiloTokens': _Reason(
    'thousands with a k ("13k tokens"): the noun is plural at every count, '
    'because the singular case is below a thousand tokens',
  ),
  'kanbanInspectProcess': _Reason('a process id'),
  'kanbanInspectThreads': _Reason('a label, a colon and a number'),
  'kanbanInspectTitle': _Reason('a run id'),
  'kanbanTaskComments': _Reason('a label with the count in parentheses'),
  'kanbanTaskPriorityLevel': _Reason('a priority level, "P2"'),
  'kanbanTaskRuns': _Reason('a label with the count in parentheses'),
  'kanbanWorkersRunNumber': _Reason('a run id'),
  'kanbanWorkersRunning': _Reason(
    'English "running" does not change with the number; German does and has '
    'a plural',
    locales: {'en'},
  ),
  'kanbanWorkersTerminateTitle': _Reason('a run id'),
  'memoryEntryPlace': _Reason('a position "Entry 1 of 4", no noun after it'),
  'memoryEntryWaiting': _Reason(
    '"n waiting", "n wartend": the word after the count does not change',
  ),
  'providersConnectedCount': _Reason('"n connected": a participle'),
  'providersDetailShowAll': _Reason('"Show all n": no noun after the number'),
  'serverCareChannelsConnected': _Reason('"n of m connected": participles'),
  'serverCareCheckPassedTitle': _Reason('"n passed": a participle'),
  'serverCareDiskPercentUsed': _Reason('a percentage'),
  'skillsCuratorEveryHours': _Reason(
    'curatorIntervalLabel handles one hour (skillsCuratorEveryHour) and whole '
    'days (skillsCuratorEveryDays) itself',
  ),
  'toolsInsideTitle': _Reason('a number in brackets after a heading'),
  'toolsProfilesCount': _Reason('"n of m on": a ratio'),
  'toolsSubtitle': _Reason('"n on": a participle'),
};
