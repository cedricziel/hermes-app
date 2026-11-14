import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/tools/tools_controller.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/tools/tools_row_mapping.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';
import 'package:hermes_app/src/tools/widgets/toolset_row.dart';

Toolset _toolset(
  String name, {
  String label = '',
  String description = 'server words',
  bool enabled = false,
  bool configured = true,
  String platform = 'cli',
  String platformLabel = 'CLI',
  List<String> tools = const ['a', 'b'],
}) => Toolset(
  name: name,
  label: label.isEmpty ? name : label,
  description: description,
  platform: platform,
  platformLabel: platformLabel,
  enabled: enabled,
  configured: configured,
  tools: tools,
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));
  const idle = ToolsRowState();

  group('a built-in toolset', () {
    test('shows the app\'s own name and sentence, not the server\'s', () {
      final view = toolsetRowView(
        en,
        _toolset('terminal', label: 'Terminal & Processes'),
        idle,
      );

      expect(view.name, 'Terminal');
      expect(view.sentence, 'Run commands on the machine where Hermes runs.');
      expect(view.unknownPlugin, isFalse);
      expect(view.actionCount, 2);
    });

    test('has the risk line at both levels, and only from the table', () {
      bool risky(String name) =>
          toolsetRowView(en, _toolset(name), idle).riskLine;

      expect(risky('terminal'), isTrue, reason: 'confirm level');
      expect(risky('file'), isTrue, reason: 'explain level');
      expect(risky('web'), isFalse);
      expect(risky('acme_digest'), isFalse);
    });

    test('says "Needs setup" for a toolset that is not configured', () {
      expect(
        toolsetRowView(en, _toolset('web', configured: false), idle).needsSetup,
        isTrue,
      );
      expect(toolsetRowView(en, _toolset('web'), idle).needsSetup, isFalse);
    });

    test('is German when the locale is', () {
      expect(
        toolsetRowView(de, _toolset('terminal'), idle).sentence,
        isNot(toolsetRowView(en, _toolset('terminal'), idle).sentence),
      );
    });
  });

  group('a toolset the app does not know', () {
    test('shows the server\'s label and description and no risk line', () {
      final view = toolsetRowView(
        en,
        _toolset(
          'acme_digest',
          label: 'Acme digest',
          description: 'Summarize the team channel.',
        ),
        idle,
      );

      expect(view.name, 'Acme digest');
      expect(view.sentence, 'Summarize the team channel.');
      expect(view.unknownPlugin, isTrue);
      expect(view.riskLine, isFalse);
    });
  });

  group('the position of the switch', () {
    test('is the saved one, or the one being written while saving', () {
      final on = _toolset('web', enabled: true);

      expect(toolsetRowView(en, on, idle).enabled, isTrue);
      expect(
        toolsetRowView(
          en,
          on,
          const ToolsRowState(phase: ToolsRowPhase.saving, shownEnabled: false),
        ).enabled,
        isFalse,
      );
    });

    test('stays the saved one while the question is open', () {
      final view = toolsetRowView(
        en,
        _toolset('terminal'),
        const ToolsRowState(phase: ToolsRowPhase.awaitingConfirmation),
      );

      expect(view.enabled, isFalse);
      expect(view.phase, ToolsetRowPhase.awaitingConfirmation);
    });
  });

  group('the phases', () {
    test('map one to one', () {
      for (final (from, to) in [
        (ToolsRowPhase.idle, ToolsetRowPhase.idle),
        (ToolsRowPhase.preparing, ToolsetRowPhase.preparing),
        (ToolsRowPhase.saving, ToolsetRowPhase.saving),
        (ToolsRowPhase.checking, ToolsetRowPhase.checking),
        (ToolsRowPhase.unconfirmed, ToolsetRowPhase.unconfirmed),
        (
          ToolsRowPhase.awaitingConfirmation,
          ToolsetRowPhase.awaitingConfirmation,
        ),
      ]) {
        expect(
          toolsetRowView(en, _toolset('web'), ToolsRowState(phase: from)).phase,
          to,
        );
      }
    });

    test('offer Try again only where there is no pull to refresh', () {
      const lost = ToolsRowState(phase: ToolsRowPhase.unconfirmed);

      expect(toolsetRowView(en, _toolset('web'), lost).showTryAgain, isFalse);
      expect(
        toolsetRowView(en, _toolset('web'), lost, desktop: true).showTryAgain,
        isTrue,
      );
    });
  });

  group('the error line', () {
    String? text(ToolsRowError error) => toolsetRowView(
      en,
      _toolset('memory'),
      ToolsRowState(error: error),
    ).error;

    test('is Hermes\' own text for a refusal', () {
      expect(
        text(
          const ToolsRowError(
            ToolsRowErrorKind.refused,
            detail: 'Platform "cli" is read-only here.',
          ),
        ),
        'Platform "cli" is read-only here.',
      );
    });

    test('falls back to the plain failure when Hermes sent no text', () {
      expect(
        text(const ToolsRowError(ToolsRowErrorKind.refused, detail: ' ')),
        'Couldn\'t change Memory. Try again.',
      );
    });

    test('is fixed copy for the rest', () {
      expect(
        text(const ToolsRowError(ToolsRowErrorKind.forbidden)),
        'You can\'t change tools on this server.',
      );
      expect(
        text(const ToolsRowError(ToolsRowErrorKind.offline)),
        'You\'re offline. Couldn\'t change Memory.',
      );
      expect(
        text(const ToolsRowError(ToolsRowErrorKind.failed)),
        'Couldn\'t change Memory. Try again.',
      );
    });

    test('is none without an error', () {
      expect(toolsetRowView(en, _toolset('memory'), idle).error, isNull);
    });
  });

  group('the details', () {
    test('say where a command line toolset applies', () {
      expect(
        toolsetDetailView(en, _toolset('web'), idle).where,
        'Used in your chats in this app and in the terminal.',
      );
    });

    test('name the platform of another one', () {
      expect(
        toolsetDetailView(
          en,
          _toolset('discord', platform: 'discord', platformLabel: 'Discord'),
          idle,
        ).where,
        'Used in Discord chats only.',
      );
      expect(
        toolsetDetailView(
          en,
          _toolset('x', platform: 'slack', platformLabel: ''),
          idle,
        ).where,
        'Used in slack chats only.',
      );
    });

    test('carry the risk note for names in the table only', () {
      expect(toolsetDetailView(en, _toolset('terminal'), idle).risk, isNotNull);
      expect(toolsetDetailView(en, _toolset('web'), idle).risk, isNull);
    });

    test('keep the tool names in the server\'s order', () {
      expect(
        toolsetDetailView(
          en,
          _toolset('web', tools: ['web_search', 'web_extract']),
          idle,
        ).tools,
        ['web_search', 'web_extract'],
      );
    });

    test('show the header phases, and unconfirmed as a line', () {
      final saving = toolsetDetailView(
        en,
        _toolset('web'),
        const ToolsRowState(phase: ToolsRowPhase.saving, shownEnabled: true),
      );
      final lost = toolsetDetailView(
        en,
        _toolset('web'),
        const ToolsRowState(phase: ToolsRowPhase.unconfirmed),
      );

      expect(saving.phase, ToolsetHeaderPhase.saving);
      expect(saving.enabled, isTrue);
      expect(lost.phase, ToolsetHeaderPhase.idle);
      expect(lost.unconfirmed, isTrue);
    });
  });
}
