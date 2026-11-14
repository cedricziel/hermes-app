import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/tools/toolset_copy.dart';
import 'package:hermes_app/src/tools/toolset_risk.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test(
    'every name the risk table decided about has a sentence and a label',
    () {
      for (final name in [...kToolsetRisks.keys, ...kNoRiskToolsets]) {
        expect(toolsetSentence(en, name), isNotNull, reason: name);
        expect(toolsetSentence(de, name), isNotNull, reason: name);
        expect(toolsetLabel(en, name), isNot(name), reason: name);
      }
    },
  );

  test('sentences follow the design brief', () {
    expect(
      toolsetSentence(en, 'terminal'),
      'Run commands on the machine where Hermes runs.',
    );
    expect(
      toolsetSentence(en, 'cronjob'),
      'Create tasks that run later without you.',
    );
    expect(toolsetLabel(en, 'web'), 'Web search and scraping');
  });

  test('an unknown name has no sentence and falls back to the label', () {
    expect(toolsetSentence(en, 'weather'), isNull);
    expect(
      toolsetLabel(en, 'weather', fallback: 'Weather lookup'),
      'Weather lookup',
    );
    expect(toolsetLabel(en, 'weather'), 'weather');
  });

  test('the terminal question', () {
    final q = toolsetConfirmQuestion(en, 'terminal', 'work')!;
    expect(q.title, 'Let Hermes run commands?');
    expect(
      q.body,
      'It can run commands on the machine where Hermes runs. '
      'It applies to the profile "work". '
      "Switching it off stops new commands. It doesn't undo what they did.",
    );
  });

  test('computer use says actions, and adds the driver sentence only when '
      'an install step exists', () {
    final plain = toolsetConfirmQuestion(en, 'computer_use', 'work')!;
    final installing = toolsetConfirmQuestion(
      en,
      'computer_use',
      'work',
      installsSoftware: true,
    )!;

    expect(plain.title, 'Let Hermes control a computer?');
    expect(plain.body, isNot(contains('install a driver')));
    expect(plain.body, contains('stops new actions'));
    expect(
      installing.body,
      contains('It may also install a driver on the server.'),
    );
  });

  test('another confirm-level toolset with an install step says so', () {
    for (final name in ['terminal', 'code_execution', 'browser']) {
      expect(
        toolsetConfirmQuestion(en, name, 'work')!.body,
        isNot(contains('installer')),
        reason: name,
      );
      expect(
        toolsetConfirmQuestion(en, name, 'work', installsSoftware: true)!.body,
        contains('It may also run an installer on the server.'),
        reason: name,
      );
    }
  });

  test('every confirm-level toolset has a question, others none', () {
    for (final entry in kToolsetRisks.entries) {
      expect(
        toolsetConfirmQuestion(en, entry.key, 'p') != null,
        entry.value.asksBeforeSwitchingOn,
        reason: entry.key,
      );
    }
  });

  test('the install question', () {
    final q = toolsetInstallQuestion(en, 'Image generation');
    expect(q.title, 'Install on your server?');
    expect(
      q.body,
      'Switching Image generation on may run an installer on the server. '
      'It may download software.',
    );
  });

  test('every risk kind has a title and sentence in both languages', () {
    for (final kind in ToolsetRiskKind.values) {
      expect(toolsetRiskTitle(en, kind), isNotEmpty);
      expect(toolsetRiskSentence(de, kind), isNotEmpty);
    }
  });
}
