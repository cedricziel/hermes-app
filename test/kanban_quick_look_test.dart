import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/quick_look_target.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_kanban_files.dart';
import 'support/fake_media_actions.dart';
import 'support/fake_quick_look.dart';
import 'support/kanban_fixtures.dart';
import 'support/recorded_events.dart';

void main() {
  late FakeHermesServer server;
  late FakeKanbanFiles files;
  late FakeMediaActions actions;
  late FakeQuickLook quickLook;
  late Directory cache;
  late MediaStore store;
  late BreadcrumbTrail trail;
  late RecordedEvents events;

  // The keys no attachment took: what would reach the shortcuts and, from
  // there, the system's unhandled-key beep.
  late List<LogicalKeyboardKey> unhandledKeys;

  const route = '/api/plugins/kanban/attachments/3';
  final spec = Uint8List.fromList([37, 80, 68, 70, 1, 2, 3]);

  setUp(() {
    files = FakeKanbanFiles();
    actions = FakeMediaActions();
    quickLook = FakeQuickLook();
    cache = tempDir('kanban_quick_look');
    trail = BreadcrumbTrail();
    events = RecordedEvents();
    unhandledKeys = [];
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'ready'),
          attachments: [
            {'id': 3, 'filename': 'spec.pdf', 'size': 2048},
          ],
        ),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {'assignees': <String>[]});
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
      quickLook: quickLook,
    );
  });

  int fetches() => server.requestsTo('GET', route).length;

  // Requests and file writes need real time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
    bool withStore = true,
  }) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MediaStore?>.value(value: withStore ? store : null),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(
              server.client(),
              telemetry: events.connection(const {}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: platform),
          home: Scaffold(
            body: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent) unhandledKeys.add(event.logicalKey);
                return KeyEventResult.ignored;
              },
              child: KanbanTaskPanel(
                repository: KanbanRepository(server.client()),
                files: files,
                taskId: 't1',
                board: 'ops',
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.pumpAndSettle();
  }

  Future<void> click(
    WidgetTester tester,
    Finder finder, {
    int buttons = kPrimaryMouseButton,
  }) async {
    await tester.ensureVisible(finder);
    await tester.runAsync(
      () => tester.tap(finder, kind: PointerDeviceKind.mouse, buttons: buttons),
    );
    await tester.pump();
  }

  Future<void> doubleClick(WidgetTester tester, Finder finder) async {
    await click(tester, finder);
    await tester.pump(const Duration(milliseconds: 60));
    await click(tester, finder);
  }

  Future<void> pressSpace(WidgetTester tester) async {
    await tester.runAsync(() => tester.sendKeyEvent(LogicalKeyboardKey.space));
    await tester.pump();
  }

  final row = find.text('spec.pdf');

  bool selected(WidgetTester tester) => tester
      .widget<QuickLookSelectionFrame>(find.byType(QuickLookSelectionFrame))
      .selected;

  testWidgets('a click selects the row and fetches nothing', (tester) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);

    await click(tester, row);
    await settle(tester);

    expect(selected(tester), isTrue);
    expect(fetches(), 0);
    expect(actions.opened, isEmpty);
  });

  testWidgets('a double-click downloads with the board and opens the file', (
    tester,
  ) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);

    await doubleClick(tester, row);
    await settle(tester);

    expect(fetches(), 1);
    expect(
      server.requestsTo('GET', route).single.queryParameters['board'],
      'ops',
    );
    expect(actions.opened.single, startsWith(cache.path));
    expect(actions.opened.single, endsWith('/spec.pdf'));
    expect(File(actions.opened.single).readAsBytesSync(), spec);
  });

  testWidgets('Space previews it and again closes it without a request', (
    tester,
  ) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);
    await click(tester, row);

    await pressSpace(tester);
    await settle(tester);
    expect(fetches(), 1);
    expect(File(quickLook.shown!).readAsBytesSync(), spec);

    await pressSpace(tester);
    await settle(tester);
    expect(quickLook.shown, isNull);
    expect(fetches(), 1);
  });

  testWidgets('the menu previews, and a second preview reuses the file', (
    tester,
  ) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);

    for (var i = 0; i < 2; i++) {
      await click(tester, row, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Quick Look')));
      await settle(tester);
    }

    expect(selected(tester), isTrue);
    expect(quickLook.previewed, hasLength(2));
    expect(quickLook.shown, isNotNull);
    expect(fetches(), 1);
  });

  testWidgets('the menu opens, and Open after a preview needs no request', (
    tester,
  ) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);
    await click(tester, row);
    await pressSpace(tester);
    await settle(tester);

    await click(tester, row, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Open')));
    await settle(tester);

    expect(actions.opened.single, quickLook.shown);
    expect(fetches(), 1);
  });

  testWidgets('the menu saves through the existing dialog', (tester) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);

    await click(tester, row, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Save…')));
    await settle(tester);

    expect(files.saved.single.name, 'spec.pdf');
    expect(files.saved.single.bytes, spec);
  });

  testWidgets('a failed download says why and shows nothing', (tester) async {
    server.on('GET', route, {
      'detail': 'attachment file missing on disk',
    }, status: 404);
    await pumpPanel(tester);
    await click(tester, row);

    await pressSpace(tester);
    await settle(tester);

    expect(find.text('attachment file missing on disk'), findsOneWidget);
    expect(quickLook.previewed, isEmpty);
    expect(selected(tester), isTrue);
    expect(events.named('quick_look.failed'), [
      {'stage': 'download', 'reason': 'failed'},
    ]);
  });

  testWidgets('a panel that cannot show the file says so', (tester) async {
    server.on('GET', route, spec);
    quickLook.shows = false;
    await pumpPanel(tester);
    await click(tester, row);

    await pressSpace(tester);
    await settle(tester);

    expect(find.text("Quick Look couldn't preview this file."), findsOne);
    expect(events.named('quick_look.failed'), [
      {'stage': 'native', 'reason': 'unavailable'},
    ]);
  });

  testWidgets('the buttons are disabled and a second press ignored while it '
      'downloads', (tester) async {
    final gate = Completer<void>();
    server.onRequest('GET', route, (_) async {
      await gate.future;
      return (status: 200, body: spec);
    });
    await pumpPanel(tester);
    await click(tester, row);

    await pressSpace(tester);
    await settle(tester);
    await pressSpace(tester);
    await doubleClick(tester, row);

    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byTooltip('Save attachment'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    gate.complete();
    await settle(tester);

    expect(fetches(), 1);
    expect(quickLook.previewed, hasLength(1));
    expect(actions.opened, isEmpty);
  });

  testWidgets('Space and Enter during a transfer are taken and start nothing', (
    tester,
  ) async {
    final gate = Completer<void>();
    server.onRequest('GET', route, (_) async {
      await gate.future;
      return (status: 200, body: spec);
    });
    await pumpPanel(tester);
    await click(tester, row);
    await pressSpace(tester);
    await settle(tester);
    unhandledKeys.clear();

    await pressSpace(tester);
    await tester.runAsync(() => tester.sendKeyEvent(LogicalKeyboardKey.enter));
    await tester.pump();
    gate.complete();
    await settle(tester);

    expect(unhandledKeys, isEmpty);
    expect(fetches(), 1);
    expect(actions.opened, isEmpty);
  });

  testWidgets('a preview leaves a crumb and nothing that names the file', (
    tester,
  ) async {
    server.on('GET', route, spec);
    await pumpPanel(tester);
    await click(tester, row, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Quick Look')));
    await settle(tester);

    expect(
      [for (final c in trail.recent) '${c.name} ${c.attributes}'],
      ['quick_look.opened {source: kanban, trigger: menu}'],
    );
  });

  testWidgets('without a media store the entries are disabled', (tester) async {
    server.on('GET', route, spec);
    await pumpPanel(tester, withStore: false);
    await click(tester, row);

    await pressSpace(tester);
    await doubleClick(tester, row);
    await settle(tester);

    expect(fetches(), 0);
    expect(quickLook.previewed, isEmpty);
  });

  testWidgets('elsewhere nothing is selectable and Space does nothing', (
    tester,
  ) async {
    server.on('GET', route, spec);
    await pumpPanel(tester, platform: TargetPlatform.windows);

    await click(tester, row);
    await pressSpace(tester);
    await settle(tester);

    expect(find.byType(QuickLookSelectionFrame), findsNothing);
    expect(fetches(), 0);
  });
}
