import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_provider.dart';
import 'package:hermes_app/src/memory/widgets/memory_reset_dialog.dart';
import 'package:hermes_app/src/memory/widgets/memory_storage_section.dart';

void main() {
  var opened = 0, retried = 0, resets = 0;

  Future<void> pump(
    WidgetTester tester, {
    MemoryProviderStatus? provider = MemoryProviderStatus.builtin,
    bool failed = false,
    bool resetting = false,
    MemoryNotice? notice,
  }) async {
    opened = retried = resets = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MemoryStorageSection(
                provider: provider,
                providerFailed: failed,
                resetting: resetting,
                notice: notice,
                onOpenProviders: () => opened++,
                onRetry: () => retried++,
                onReset: () => resets++,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('built-in memory names its files and opens the providers', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Memory provider'), findsOneWidget);
    expect(find.text('Built-in · MEMORY.md and USER.md'), findsOneWidget);
    await tester.tap(find.text('Memory provider'));
    expect(opened, 1);
  });

  testWidgets('a named provider shows its name and description', (
    tester,
  ) async {
    await pump(
      tester,
      provider: const MemoryProviderStatus(
        MemoryProviderState.ready,
        name: 'honcho',
        description: 'Honcho memory',
      ),
    );
    expect(find.text('honcho'), findsOneWidget);
    expect(find.text('Honcho memory'), findsOneWidget);
    expect(find.textContaining('Built-in'), findsNothing);
  });

  testWidgets('a provider that is gone is an error above the row', (
    tester,
  ) async {
    await pump(
      tester,
      provider: const MemoryProviderStatus(
        MemoryProviderState.missing,
        name: 'honcho',
      ),
    );
    expect(find.text('Memory provider is missing'), findsOneWidget);
    expect(
      find.text(
        'honcho is no longer installed on the server. Hermes falls back to '
        'the built-in files until you pick another provider.',
      ),
      findsOneWidget,
    );
  });

  for (final (state, line) in [
    (MemoryProviderState.needsConfig, 'Needs setup on the server'),
    (MemoryProviderState.unavailable, 'Not available on the server'),
  ]) {
    testWidgets('${state.wire} adds a warning line', (tester) async {
      await pump(tester, provider: MemoryProviderStatus(state, name: 'mem0'));
      expect(find.text(line), findsOneWidget);
      expect(find.text('Memory provider is missing'), findsNothing);
    });
  }

  testWidgets('a failed read offers a retry and leaves Reset usable', (
    tester,
  ) async {
    await pump(tester, provider: null, failed: true);
    expect(find.text("Couldn't read the memory provider"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
    await tester.tap(find.text('Reset memory…'));
    expect(resets, 1);
  });

  testWidgets('Reset memory… says what it erases', (tester) async {
    await pump(tester);
    expect(
      find.text(
        "Erases the files on the server. Open chats keep what they started "
        "with. This can't be undone.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset memory…'));
    expect(resets, 1);
  });

  testWidgets('Reset is off while a reset runs', (tester) async {
    await pump(tester, resetting: true);
    await tester.tap(find.text('Reset memory…'), warnIfMissed: false);
    expect(resets, 0);
  });

  testWidgets('shows what the last reset came to', (tester) async {
    await pump(
      tester,
      notice: const MemoryNotice(
        'Reset about you. New chats start without it.',
        MemoryNoticeTone.success,
      ),
    );
    expect(
      find.text('Reset about you. New chats start without it.'),
      findsOneWidget,
    );
  });

  group('reset alert', () {
    Future<void> open(
      WidgetTester tester,
      ValueChanged<MemoryResetTarget?> onAnswer,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onAnswer(
                await showMemoryResetDialog(context, profile: 'work'),
              ),
              child: const Text('ask'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the profile and offers three resets and Cancel', (
      tester,
    ) async {
      await open(tester, (_) {});
      expect(find.text('Reset memory?'), findsOneWidget);
      expect(
        find.text(
          "Hermes forgets what you pick, on the server, for the work "
          "profile. This can't be undone.",
        ),
        findsOneWidget,
      );
      for (final action in [
        'Reset agent notes',
        'Reset about you',
        'Reset both',
        'Cancel',
      ]) {
        expect(find.text(action), findsOneWidget, reason: action);
      }
    });

    for (final (label, target) in [
      ('Reset agent notes', MemoryResetTarget.agentNotes),
      ('Reset about you', MemoryResetTarget.aboutYou),
      ('Reset both', MemoryResetTarget.both),
      ('Cancel', null),
    ]) {
      testWidgets('$label answers ${target?.wire ?? 'nothing'}', (
        tester,
      ) async {
        final answers = <MemoryResetTarget?>[];
        await open(tester, answers.add);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(answers, [target]);
      });
    }
  });
}
