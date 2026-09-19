import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/mock_chat_data.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// Rename, pin, archive and delete on the sidebar's threads, against a fake
/// dashboard through the real generated client.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
        sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        sessionRow(id: 's3', title: 'Trip plan', lastActive: 1780000050),
      ]),
    );
    for (final id in ['s1', 's2', 's3']) {
      server.on(
        'GET',
        '/api/sessions/$id/messages',
        messageListBody(id, [messageRow(id: 1, role: 'user', content: 'hi')]),
      );
    }
  });

  Finder row(String id) => find.byKey(ValueKey('thread-$id'));

  Finder inRow(String id, Finder matching) =>
      find.descendant(of: row(id), matching: matching);

  Finder titleInRow(String id, String title) => inRow(id, find.text(title));

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.tap(inRow(id, find.byTooltip('Chat actions')));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  List<String> rowOrder(WidgetTester tester) =>
      [
        for (final id in ['s1', 's2', 's3'])
          if (row(id).evaluate().isNotEmpty) id,
      ]..sort(
        (a, b) => tester
            .getTopLeft(row(a))
            .dy
            .compareTo(tester.getTopLeft(row(b)).dy),
      );

  group('opening the actions', () {
    testWidgets('the row button lists rename, pin, archive and delete', (
      tester,
    ) async {
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');

      for (final label in ['Rename', 'Pin', 'Archive', 'Delete']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a long press opens the same menu', (tester) async {
      await pumpChatScreen(tester, server: server);

      await tester.longPress(titleInRow('s2', 'Release notes'));
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
    });

    testWidgets('a secondary click opens the same menu', (tester) async {
      await pumpChatScreen(tester, server: server);

      await tester.tap(
        titleInRow('s2', 'Release notes'),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
    });

    testWidgets('a local draft has no actions', (tester) async {
      await pumpChatScreen(tester, server: server);

      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Chat actions'), findsNWidgets(3));
    });

    testWidgets('a draft gets them once the dashboard stores it', (
      tester,
    ) async {
      final transport = FakeChatTransport();
      await pumpChatScreen(tester, server: server, transport: transport);
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Fresh start');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      transport.sends.single.emit(const ThreadBound('dash-1'));
      await tester.pump();

      expect(inRow('dash-1', find.byTooltip('Chat actions')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('mock threads have no actions', (tester) async {
      await pumpChatScreen(tester);

      expect(find.byTooltip('Chat actions'), findsNothing);
    });
  });

  group('under a profile', () {
    setUp(() {
      server
        ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's2', title: 'Release notes')]),
          query: {'profile': 'work'},
        )
        ..on(
          'GET',
          '/api/sessions/s2/messages',
          messageListBody('s2', []),
          query: {'profile': 'work'},
        )
        ..on('PATCH', '/api/sessions/s2', sessionPatchBody(title: 'Renamed'))
        ..on('DELETE', '/api/sessions/s2', {'ok': true});
    });

    testWidgets('a rename reaches the session of that profile', (tester) async {
      await pumpChatScreen(tester, server: server, withProfiles: true);

      await openMenu(tester, 's2');
      await choose(tester, 'Rename');
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final request = server.requestsTo('PATCH', '/api/sessions/s2').single;
      expect(jsonBody(request), {'title': 'Renamed', 'profile': 'work'});
    });

    testWidgets('a delete reaches the session of that profile', (tester) async {
      await pumpChatScreen(tester, server: server, withProfiles: true);

      await openMenu(tester, 's2');
      await choose(tester, 'Delete');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      final request = server.requestsTo('DELETE', '/api/sessions/s2').single;
      expect(request.queryParameters['profile'], 'work');
    });
  });

  group('rename', () {
    Future<void> rename(WidgetTester tester, String id, String title) async {
      await openMenu(tester, id);
      await choose(tester, 'Rename');
      await tester.enterText(find.byType(TextField), title);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends the new title and shows it', (tester) async {
      server.on(
        'PATCH',
        '/api/sessions/s2',
        sessionPatchBody(title: 'Launch notes'),
      );
      await pumpChatScreen(tester, server: server);

      await rename(tester, 's2', '  Launch notes ');

      final request = server.requestsTo('PATCH', '/api/sessions/s2').single;
      expect(jsonBody(request), {'title': 'Launch notes'});
      expect(titleInRow('s2', 'Launch notes'), findsOneWidget);
    });

    testWidgets('offers the current title to edit', (tester) async {
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Rename');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Release notes');
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Rename');
      await tester.enterText(find.byType(TextField), 'Something else');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('PATCH', '/api/sessions/s2'), isEmpty);
      expect(titleInRow('s2', 'Release notes'), findsOneWidget);
    });

    testWidgets('does not save an empty or unchanged title', (tester) async {
      await pumpChatScreen(tester, server: server);

      await rename(tester, 's2', '   ');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await rename(tester, 's2', 'Release notes');

      expect(server.requestsTo('PATCH', '/api/sessions/s2'), isEmpty);
    });

    testWidgets('shows the title at once and keeps it once saved', (
      tester,
    ) async {
      final release = Completer<void>();
      server.onRequest('PATCH', '/api/sessions/s2', (_) async {
        await release.future;
        return (status: 200, body: sessionPatchBody(title: 'Launch notes'));
      });
      await pumpChatScreen(tester, server: server);

      await rename(tester, 's2', 'Launch notes');
      expect(titleInRow('s2', 'Launch notes'), findsOneWidget);

      release.complete();
      await tester.pumpAndSettle();
      expect(titleInRow('s2', 'Launch notes'), findsOneWidget);
    });

    testWidgets('puts the old title back and says why when it fails', (
      tester,
    ) async {
      server.on('PATCH', '/api/sessions/s2', {
        'detail': 'Title already in use',
      }, status: 400);
      await pumpChatScreen(tester, server: server);

      await rename(tester, 's2', 'Run failure');

      expect(titleInRow('s2', 'Release notes'), findsOneWidget);
      expect(
        find.text('Could not rename this chat: Title already in use'),
        findsOneWidget,
      );
    });

    testWidgets('a server error is reported without its detail', (
      tester,
    ) async {
      server.on('PATCH', '/api/sessions/s2', {'detail': 'boom'}, status: 500);
      await pumpChatScreen(tester, server: server);

      await rename(tester, 's2', 'Launch notes');

      expect(titleInRow('s2', 'Release notes'), findsOneWidget);
      expect(find.text('Could not rename this chat'), findsOneWidget);
    });
  });

  group('pin', () {
    testWidgets('sends the flag and moves the thread to the top', (
      tester,
    ) async {
      server.on(
        'PATCH',
        '/api/sessions/s3',
        sessionPatchBody(flags: {'pinned': true}),
      );
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's3');
      await choose(tester, 'Pin');

      final request = server.requestsTo('PATCH', '/api/sessions/s3').single;
      expect(jsonBody(request), {'pinned': true});
      expect(rowOrder(tester), ['s3', 's1', 's2']);
    });

    testWidgets('a pinned thread offers to unpin and drops back', (
      tester,
    ) async {
      server.on(
        'PATCH',
        '/api/sessions/s3',
        sessionPatchBody(flags: {'pinned': true}),
      );
      await pumpChatScreen(tester, server: server);
      await openMenu(tester, 's3');
      await choose(tester, 'Pin');
      server.on(
        'PATCH',
        '/api/sessions/s3',
        sessionPatchBody(flags: {'pinned': false}),
      );

      await openMenu(tester, 's3');
      await choose(tester, 'Unpin');

      expect(jsonBody(server.requestsTo('PATCH', '/api/sessions/s3').last), {
        'pinned': false,
      });
      expect(rowOrder(tester), ['s1', 's2', 's3']);
    });

    testWidgets('pinned sessions from the dashboard start at the top', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure'),
          sessionRow(id: 's2', title: 'Release notes'),
          sessionRow(id: 's3', title: 'Trip plan', pinned: true),
        ]),
      );
      await pumpChatScreen(tester, server: server);

      expect(rowOrder(tester), ['s3', 's1', 's2']);
    });

    testWidgets('moves back and says why when it fails', (tester) async {
      final refuse = Completer<void>();
      server.onRequest('PATCH', '/api/sessions/s3', (_) async {
        await refuse.future;
        return (status: 500, body: {'detail': 'x'});
      });
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's3');
      await choose(tester, 'Pin');
      expect(rowOrder(tester), ['s3', 's1', 's2']);

      refuse.complete();
      await tester.pumpAndSettle();

      expect(rowOrder(tester), ['s1', 's2', 's3']);
      expect(find.text('Could not pin this chat'), findsOneWidget);
      await openMenu(tester, 's3');
      expect(find.text('Pin'), findsOneWidget);
    });
  });

  group('archive', () {
    testWidgets('sends the flag and removes the thread', (tester) async {
      server.on(
        'PATCH',
        '/api/sessions/s2',
        sessionPatchBody(flags: {'archived': true}),
      );
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Archive');

      final request = server.requestsTo('PATCH', '/api/sessions/s2').single;
      expect(jsonBody(request), {'archived': true});
      expect(row('s2'), findsNothing);
    });

    testWidgets('moves to another thread when the open one goes', (
      tester,
    ) async {
      server.on(
        'PATCH',
        '/api/sessions/s1',
        sessionPatchBody(flags: {'archived': true}),
      );
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's1');
      await choose(tester, 'Archive');

      expect(row('s1'), findsNothing);
      expect(
        server.requestsTo('GET', '/api/sessions/s2/messages'),
        hasLength(1),
      );
    });

    testWidgets('keeps the thread and says why when it fails', (tester) async {
      server.on('PATCH', '/api/sessions/s2', {'detail': 'x'}, status: 500);
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Archive');

      expect(row('s2'), findsOneWidget);
      expect(find.text('Could not archive this chat'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('asks first, and cancelling deletes nothing', (tester) async {
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Delete');
      expect(find.text('Delete this chat?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('DELETE', '/api/sessions/s2'), isEmpty);
      expect(row('s2'), findsOneWidget);
    });

    testWidgets('deletes the session once confirmed', (tester) async {
      server.on('DELETE', '/api/sessions/s2', {'ok': true});
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Delete');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(server.requestsTo('DELETE', '/api/sessions/s2'), hasLength(1));
      expect(row('s2'), findsNothing);
      expect(row('s1'), findsOneWidget);
    });

    testWidgets('keeps the thread and says why when it fails', (tester) async {
      server.on('DELETE', '/api/sessions/s2', {'detail': 'x'}, status: 500);
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's2');
      await choose(tester, 'Delete');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(row('s2'), findsOneWidget);
      expect(find.text('Could not delete this chat'), findsOneWidget);
    });

    testWidgets('deleting the last thread lands on the welcome view', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
      );
      server.on('DELETE', '/api/sessions/s1', {'ok': true});
      await pumpChatScreen(tester, server: server);

      await openMenu(tester, 's1');
      await choose(tester, 'Delete');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(row('s1'), findsNothing);
      expect(find.text(kStarterPrompts.first), findsOneWidget);
    });
  });
}
