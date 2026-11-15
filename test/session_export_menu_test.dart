import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:hermes_app/src/windows/conversation_windows_menu.dart';
import 'package:hermes_app/src/windows/widgets/conversation_window_toolbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';

const _macLabel = 'Export Chat as JSON…';
const _materialLabel = 'Export chat as JSON…';

ChatThread _thread() => ChatThread(
  id: 's1',
  title: 'Plan the release',
  updatedAt: DateTime(2026, 1, 1),
  messages: const [],
);

List<String> _labels(List<PopupMenuEntry<ThreadAction>> items) => [
  for (final item in items)
    if (item is PopupMenuItem<ThreadAction>) (item.child! as Text).data!,
];

PopupMenuItem<ThreadAction> _row(List<PopupMenuEntry<ThreadAction>> items) =>
    items.whereType<PopupMenuItem<ThreadAction>>().firstWhere(
      (item) => item.value == ThreadAction.exportJson,
    );

void main() {
  group('macThreadMenuItems', () {
    test('lists the row right after Copy Transcript', () {
      final items = macThreadMenuItems(
        pinned: false,
        manageable: true,
        exportJson: ExportJsonOffer(onSelected: () {}),
      );

      expect(_labels(items), [
        'Rename…',
        'Pin',
        'Copy Transcript',
        _macLabel,
        'Archive',
        'Delete…',
      ]);
    });

    test('has no row without an offer', () {
      expect(
        _labels(macThreadMenuItems(pinned: false, manageable: true)),
        isNot(contains(_macLabel)),
      );
    });

    test('keeps the row but disables it while an export runs', () {
      final items = macThreadMenuItems(
        pinned: false,
        manageable: true,
        exportJson: ExportJsonOffer(onSelected: () {}, enabled: false),
      );

      expect(_row(items).enabled, isFalse);
    });
  });

  group('runThreadAction', () {
    Future<void> run(
      WidgetTester tester,
      ExportJsonOffer? offer, {
      Object? housekeeping,
    }) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await runThreadAction(
        context,
        ThreadAction.exportJson,
        thread: _thread(),
        housekeeping: null,
        exportJson: offer,
      );
    }

    testWidgets('starts the export of the thread', (tester) async {
      var started = 0;
      await run(tester, ExportJsonOffer(onSelected: () => started++));
      expect(started, 1);
    });

    testWidgets('does nothing while an export runs or without an offer', (
      tester,
    ) async {
      var started = 0;
      await run(
        tester,
        ExportJsonOffer(onSelected: () => started++, enabled: false),
      );
      await run(tester, null);
      expect(started, 0);
    });
  });

  group('the chat header menu', () {
    Future<void> pumpHeader(
      WidgetTester tester, {
      ExportJsonOffer? offer,
      bool header = true,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: Scaffold(
            body: ThreadActionsButton(
              thread: _thread(),
              includeCopyTranscript: header,
              exportJson: offer,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Chat actions'));
      await tester.pumpAndSettle();
    }

    testWidgets('has the row after Copy transcript, before Rename', (
      tester,
    ) async {
      await pumpHeader(tester, offer: ExportJsonOffer(onSelected: () {}));

      expect(find.text(_materialLabel), findsOneWidget);
      final copy = tester.getTopLeft(find.text('Copy transcript')).dy;
      final export = tester.getTopLeft(find.text(_materialLabel)).dy;
      expect(export, greaterThan(copy));
    });

    testWidgets('runs the offer when picked', (tester) async {
      var started = 0;
      await pumpHeader(
        tester,
        offer: ExportJsonOffer(onSelected: () => started++),
      );

      await tester.tap(find.text(_materialLabel));
      await tester.pumpAndSettle();

      expect(started, 1);
    });

    testWidgets('is disabled while an export runs', (tester) async {
      var started = 0;
      await pumpHeader(
        tester,
        offer: ExportJsonOffer(onSelected: () => started++, enabled: false),
      );

      await tester.tap(find.text(_materialLabel), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(started, 0);
      expect(find.text(_materialLabel), findsOneWidget);
    });

    testWidgets('is absent without an offer', (tester) async {
      await pumpHeader(tester);
      expect(find.text(_materialLabel), findsNothing);
      expect(find.text('Copy transcript'), findsOneWidget);
    });

    testWidgets('is not in a row menu that has no Copy transcript', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        header: false,
        offer: ExportJsonOffer(onSelected: () {}),
      );
      expect(find.text(_materialLabel), findsNothing);
    });

    testWidgets('is the sentence case row on an iPad too', (tester) async {
      await pumpHeader(
        tester,
        platform: TargetPlatform.iOS,
        offer: ExportJsonOffer(onSelected: () {}),
      );
      expect(find.text(_materialLabel), findsOneWidget);
    });
  });

  group('the Mac toolbar … menu', () {
    Future<void> pump(WidgetTester tester, ExportJsonOffer? offer) async {
      tester.view
        ..physicalSize = const Size(680, 700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: MacChatToolbar(
                title: 'Plan the release',
                onNewChat: () {},
                onShowConnection: () {},
                onCopyTranscript: () {},
                exportJson: offer,
                searchQuery: '',
                searchActive: false,
                onSearchBegin: () {},
                onSearchChanged: (_) {},
                onSearchEnd: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('toolbar-more')));
      await tester.pumpAndSettle();
    }

    testWidgets('has the row between Copy Transcript and Connection Details', (
      tester,
    ) async {
      var started = 0;
      await pump(tester, ExportJsonOffer(onSelected: () => started++));

      final copy = tester.getTopLeft(find.text('Copy Transcript')).dy;
      final export = tester.getTopLeft(find.text(_macLabel)).dy;
      final connection = tester.getTopLeft(find.text('Connection Details')).dy;
      expect(export, inExclusiveRange(copy, connection));
      await tester.tap(find.text(_macLabel));
      await tester.pumpAndSettle();
      expect(started, 1);
    });

    testWidgets('is absent without an offer', (tester) async {
      await pump(tester, null);
      expect(find.text(_macLabel), findsNothing);
    });

    testWidgets('is disabled while an export runs', (tester) async {
      var started = 0;
      await pump(
        tester,
        ExportJsonOffer(onSelected: () => started++, enabled: false),
      );
      await tester.tap(find.text(_macLabel), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(started, 0);
    });
  });

  group('the menu bar layout', () {
    List<String> chat(MenuPlatform platform) => [
      for (final group
          in menuLayout.firstWhere((s) => s.id == 'chat').groupsOn(platform))
        for (final entry in group) entry.label,
    ];

    test('puts Export Chat as JSON… after Copy Transcript on both', () {
      for (final platform in MenuPlatform.values) {
        final labels = chat(platform);
        expect(
          labels.indexOf(_macLabel),
          labels.indexOf('Copy Transcript') + 1,
          reason: '$platform',
        );
      }
    });

    test('binds no shortcut', () {
      final entry = menuLayout
          .expand((s) => s.groups)
          .expand((g) => g)
          .firstWhere((e) => e.command == MacCommand.exportThread);
      expect(entry.label, _macLabel);
      for (final platform in MenuPlatform.values) {
        expect(entry.shortcutOn(platform), isNull);
      }
    });
  });

  group('the conversation window toolbar … menu', () {
    Future<List<String>> pump(
      WidgetTester tester,
      ExportJsonOffer? offer,
    ) async {
      final calls = <String>[];
      tester.view
        ..physicalSize = const Size(900, 400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: ConversationWindowToolbar(
              title: 'Trip plan',
              pinned: false,
              exportJson: offer,
              onAction: (action) => calls.add(action.name),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('has the row after Copy Transcript', (tester) async {
      final calls = await pump(tester, ExportJsonOffer(onSelected: () {}));

      final copy = tester.getTopLeft(find.text('Copy Transcript')).dy;
      final export = tester.getTopLeft(find.text(_macLabel)).dy;
      expect(export, greaterThan(copy));
      await tester.tap(find.text(_macLabel));
      await tester.pumpAndSettle();
      expect(calls, ['exportJson']);
    });

    testWidgets('is absent without a profile', (tester) async {
      await pump(tester, null);
      expect(find.text('Copy Transcript'), findsOneWidget);
      expect(find.text(_macLabel), findsNothing);
    });

    testWidgets('is disabled while an export runs', (tester) async {
      final calls = await pump(
        tester,
        ExportJsonOffer(onSelected: () {}, enabled: false),
      );
      await tester.tap(find.text(_macLabel), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });
  });

  group('the menu bar while a conversation window is key', () {
    late MacCommandRegistry registry;
    late FakeConversationWindowHost host;
    late ConversationWindows windows;

    Future<void> pump(WidgetTester tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      registry = MacCommandRegistry();
      host = FakeConversationWindowHost();
      windows = ConversationWindows(
        host: host,
        store: ConversationWindowStore(SharedPreferencesAsync()),
        ownerKey: () => 'test-owner',
        connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
        headers: ({rejected}) async => const {},
      );
      addTearDown(() {
        windows.dispose();
        host.dispose();
        registry.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<ConversationWindows?>.value(
          value: windows,
          child: MacCommandScope.root(
            registry: registry,
            child: MacCommandScope(
              priority: 1,
              commands: {MacCommand.exportThread: MacCommandHandler(() {})},
              child: const ConversationWindowsMenu(child: SizedBox()),
            ),
          ),
        ),
      );
    }

    testWidgets('goes to the window when it has a profile', (tester) async {
      await pump(tester);
      await windows.open('s1', profile: 'work', title: 'A');
      await host.call('focused', {'window_id': 'w0', 'focused': true});
      await tester.pump();

      expect(registry.handlerFor(MacCommand.exportThread)!.enabled, isTrue);
      expect(registry.invoke(MacCommand.exportThread), isTrue);
      expect(host.commands.map((c) => c.$2), ['exportJson']);
    });

    testWidgets('stays in the menu, disabled, without a profile', (
      tester,
    ) async {
      await pump(tester);
      await windows.open('s1', profile: null, title: 'A');
      await host.call('focused', {'window_id': 'w0', 'focused': true});
      await tester.pump();

      expect(registry.handlerFor(MacCommand.exportThread)!.enabled, isFalse);
      expect(registry.invoke(MacCommand.exportThread), isFalse);
      expect(host.commands, isEmpty);
    });
  });
}
