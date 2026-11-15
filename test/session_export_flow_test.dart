import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/session_export_controller.dart';
import 'package:hermes_app/src/chat/session_export_flow.dart';
import 'package:hermes_app/src/chat/widgets/session_export_alert.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';

Uint8List _session() => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'id': 's1',
      'messages': [
        {'role': 'user', 'content': 'hi'},
      ],
    }),
  ),
);

/// The alert of "Export chat as JSON" as the menus open it: one controller
/// owned by the screen, the dialog on the root navigator, the snack bar from
/// the screen's messenger.
void main() {
  late FakeHermesServer server;
  late SessionExportController controller;
  late List<String> saved;
  late Completer<bool>? saveGate;
  late Completer<FakeResponse>? answer;
  var saveResult = true;

  setUp(() {
    server = FakeHermesServer();
    saved = [];
    saveGate = null;
    answer = null;
    saveResult = true;
    server.onRequest('GET', '/api/sessions/s1/export', (_) async {
      final held = answer;
      return held == null ? (status: 200, body: _session()) : await held.future;
    });
    controller = SessionExportController(
      api: server.client(),
      save: (name, bytes) async {
        saved.add(name);
        return saveGate?.future ?? saveResult;
      },
    );
    addTearDown(controller.dispose);
  });

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    String? profile = 'work',
    String title = 'Plan the release',
  }) async {
    tester.view
      ..physicalSize = const Size(900, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSessionExport(
                context,
                controller,
                sessionId: 's1',
                profile: profile,
                title: title,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
  }

  int exportRequests() =>
      server.requests.where((r) => r.path == '/api/sessions/s1/export').length;

  /// A few frames: the bar of the progress phase never settles, so
  /// pumpAndSettle is no way to wait for a dialog to close then.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> tapOutside(WidgetTester tester) async {
    await tester.tapAt(const Offset(5, 5));
    await frames(tester);
  }

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester);
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();
  }

  group('the confirmation', () {
    testWidgets('asks first and sends nothing', (tester) async {
      await pump(tester);

      expect(find.text('Export this chat as JSON?'), findsOneWidget);
      expect(exportRequests(), 0);
    });

    testWidgets('Cancel closes it with no request', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.phase, isNull);
      expect(exportRequests(), 0);
    });

    testWidgets('Escape cancels only the confirmation', (tester) async {
      await pump(tester);
      await escape(tester);

      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.phase, isNull);
      expect(exportRequests(), 0);
      expect(saved, isEmpty);
    });

    testWidgets('a tap outside cancels it on Android', (tester) async {
      await pump(tester);
      await tapOutside(tester);

      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.phase, isNull);
      expect(exportRequests(), 0);
    });

    testWidgets('a tap outside does nothing on iOS', (tester) async {
      await pump(tester, platform: TargetPlatform.iOS);
      await tapOutside(tester);

      expect(find.byType(SessionExportAlert), findsOneWidget);
      expect(controller.phase, isA<SessionExportConfirm>());
    });

    testWidgets('a chat without a profile opens nothing', (tester) async {
      await pump(tester, profile: null);

      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.phase, isNull);
    });
  });

  group('the progress', () {
    Future<void> startHeld(WidgetTester tester) async {
      answer = Completer<FakeResponse>();
      await pump(tester);
      await confirm(tester);
      await frames(tester);
      expect(find.text('Preparing the export…'), findsOneWidget);
    }

    testWidgets('sends one request with the confirmation', (tester) async {
      await startHeld(tester);
      expect(exportRequests(), 1);
      answer!.complete((status: 200, body: _session()));
      await tester.pumpAndSettle();
    });

    testWidgets('Escape and a tap outside do nothing', (tester) async {
      await startHeld(tester);

      await escape(tester);
      await tapOutside(tester);

      expect(find.text('Preparing the export…'), findsOneWidget);
      expect(controller.busy, isTrue);
      answer!.complete((status: 200, body: _session()));
      await tester.pumpAndSettle();
    });

    testWidgets('Cancel ends the request and closes the alert', (tester) async {
      await startHeld(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.busy, isFalse);
      expect(saved, isEmpty);
      answer!.complete((status: 200, body: _session()));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });

    testWidgets('App Lock closes it and nothing shows after unlocking', (
      tester,
    ) async {
      await startHeld(tester);

      controller.locked();
      await tester.pumpAndSettle();
      expect(find.byType(SessionExportAlert), findsNothing);

      answer!.complete((status: 200, body: _session()));
      await tester.pumpAndSettle();
      expect(find.byType(SessionExportAlert), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(saved, isEmpty);
    });

    testWidgets('a sign-out closes it', (tester) async {
      await startHeld(tester);

      controller.signedOut();
      await tester.pumpAndSettle();

      expect(find.byType(SessionExportAlert), findsNothing);
      answer!.complete((status: 200, body: _session()));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });
  });

  group('a failure', () {
    Future<void> fail(WidgetTester tester, {int status = 500}) async {
      answer = Completer<FakeResponse>()
        ..complete((status: status, body: {'detail': 'boom'}));
      await pump(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('Try again returns to the confirmation, never a request', (
      tester,
    ) async {
      await fail(tester);
      expect(find.text('Couldn\'t export this chat'), findsOneWidget);
      expect(exportRequests(), 1);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Export this chat as JSON?'), findsOneWidget);
      expect(exportRequests(), 1);
    });

    testWidgets('Close and Escape close it', (tester) async {
      await fail(tester);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.phase, isNull);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await confirm(tester);
      await tester.pumpAndSettle();
      await escape(tester);
      expect(find.byType(SessionExportAlert), findsNothing);
      expect(controller.phase, isNull);
      expect(controller.busy, isFalse);
    });

    testWidgets('shows no snack bar and saves nothing', (tester) async {
      await fail(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(saved, isEmpty);
    });
  });

  group('saving', () {
    testWidgets('saves as the chat title with .json, then says so', (
      tester,
    ) async {
      await pump(tester, title: 'Release 1.2 notes');
      await confirm(tester);
      await tester.pumpAndSettle();

      expect(saved, ['Release 1.2 notes.json']);
      expect(find.byType(SessionExportAlert), findsNothing);
      expect(find.text('Chat saved'), findsOneWidget);
    });

    testWidgets('a cancelled save sheet shows nothing', (tester) async {
      saveResult = false;
      await pump(tester);
      await confirm(tester);
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SessionExportAlert), findsNothing);
    });

    testWidgets('a save that returns after a lock shows nothing', (
      tester,
    ) async {
      saveGate = Completer<bool>();
      await pump(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(saved, hasLength(1), reason: 'the sheet is open');

      controller.locked();
      saveGate!.complete(true);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SessionExportAlert), findsNothing);
    });

    testWidgets('the rows stay disabled until the sheet returns', (
      tester,
    ) async {
      saveGate = Completer<bool>();
      await pump(tester);
      await confirm(tester);
      await tester.pumpAndSettle();

      expect(controller.busy, isTrue);
      saveGate!.complete(true);
      await tester.pumpAndSettle();
      expect(controller.busy, isFalse);
    });
  });

  group('a navigation that pops everything', () {
    testWidgets('during progress ends the export with its alert', (
      tester,
    ) async {
      answer = Completer<FakeResponse>();
      await pump(tester);
      await confirm(tester);
      await frames(tester);
      expect(find.text('Preparing the export…'), findsOneWidget);

      // A notification tap or a deep link: popUntil(isFirst) ignores PopScope.
      Navigator.of(
        tester.element(find.text('Start')),
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      await frames(tester);
      expect(find.byType(SessionExportAlert), findsNothing);

      answer!.complete((status: 200, body: _session()));
      await frames(tester);
      expect(saved, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.phase, isNull);
    });
  });

  group('a second start', () {
    testWidgets('never stacks a second alert over the confirmation', (
      tester,
    ) async {
      await pump(tester);
      final context = tester.element(find.text('Start'));

      unawaited(
        showSessionExport(
          context,
          controller,
          sessionId: 's1',
          profile: 'work',
          title: 'Again',
        ),
      );
      await frames(tester);

      expect(find.byType(SessionExportAlert), findsOneWidget);
      expect(controller.begin('s2', 'work'), isFalse);
      await tester.tap(find.text('Export'));
      await frames(tester);
      expect(
        server.requests.where((r) => r.path == '/api/sessions/s1/export'),
        hasLength(1),
      );
      expect(saved, ['Plan the release.json']);
    });
  });
}
