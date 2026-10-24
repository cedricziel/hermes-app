import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/memory/memory_settings.dart';
import 'package:hermes_app/src/memory/widgets/memory_learning_section.dart';

void main() {
  final calls = <(MemorySetting, Object)>[];
  var retried = 0;

  Future<void> pump(
    WidgetTester tester, {
    MemorySettings? settings = MemorySettings.defaults,
    bool unreadable = false,
    String? message,
  }) async {
    calls.clear();
    retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MemoryLearningSection(
                settings: settings,
                unreadable: unreadable,
                message: message,
                onChanged: (setting, value) => calls.add((setting, value)),
                onRetry: () => retried++,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('names every setting, its effect and when it applies', (
    tester,
  ) async {
    await pump(tester);
    for (final text in [
      'Learning',
      'Remember things about me',
      'Your preferences, name and habits',
      'Keep agent notes',
      'Facts about your setup, tools and conventions',
      'Ask before saving',
      'Hermes asks you before it changes memory',
      'Review chats',
      'After every 10 messages',
      'Memory updates in chat',
      'Short note',
      'Ask before saving applies right away, the rest from the next chat.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('a switch reports its setting and the new value', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(Switch).at(2));
    expect(calls, [(MemorySetting.writeApproval, true)]);
  });

  testWidgets('Review chats offers Off, 5, 10 and 20', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Review chats'));
    await tester.pumpAndSettle();
    for (final text in [
      'Off',
      'After every 5 messages',
      'After every 20 messages',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tester.tap(find.text('After every 5 messages'));
    await tester.pumpAndSettle();
    expect(calls, [(MemorySetting.reviewInterval, 5)]);
  });

  testWidgets('Off sends 0', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Review chats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(calls, [(MemorySetting.reviewInterval, 0)]);
  });

  testWidgets('an interval the app does not offer is shown and kept', (
    tester,
  ) async {
    await pump(
      tester,
      settings: MemorySettings.defaults.withValue(
        MemorySetting.reviewInterval,
        15,
      ),
    );
    expect(find.text('After every 15 messages'), findsOneWidget);
    await tester.tap(find.text('Review chats'));
    await tester.pumpAndSettle();
    expect(find.text('After every 15 messages'), findsNWidgets(2));
    expect(find.text('After every 10 messages'), findsOneWidget);
  });

  testWidgets('Memory updates in chat offers three choices', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Memory updates in chat'));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('With details'), findsOneWidget);
    await tester.tap(find.text('With details'));
    await tester.pumpAndSettle();
    expect(calls, [(MemorySetting.updatesInChat, 'verbose')]);
  });

  testWidgets('an unknown report setting is shown as it is', (tester) async {
    await pump(
      tester,
      settings: MemorySettings.defaults.withValue(
        MemorySetting.updatesInChat,
        'loud',
      ),
    );
    expect(find.text('loud'), findsOneWidget);
  });

  testWidgets('an unreadable config shows a retry instead of the controls', (
    tester,
  ) async {
    await pump(tester, settings: null, unreadable: true);
    expect(find.byType(Switch), findsNothing);
    expect(find.text("Couldn't read the memory settings"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('a refused change is told above the section', (tester) async {
    await pump(tester, message: "Couldn't change Keep agent notes. Try again.");
    expect(
      find.text("Couldn't change Keep agent notes. Try again."),
      findsOneWidget,
    );
  });
}
