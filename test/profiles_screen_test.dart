import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/profiles_screen.dart';

import 'support/fake_hermes_server.dart';

/// The profiles screen against a fake dashboard, through the real generated
/// client.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true, model: 'hermes-4'),
          profileRow(
            name: 'work',
            displayName: 'Work assistant',
            description: 'Day job',
            skillCount: 12,
          ),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('POST', '/api/profiles/active', {'active': 'work'});
  });

  Future<void> pumpProfiles(
    WidgetTester tester, {
    String? chatProfile,
    ValueChanged<String>? onSwitched,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilesScreen(
          repository: HermesProfilesRepository(server.client().raw),
          chatProfile: chatProfile,
          onSwitched: onSwitched,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every profile with its label and description', (
    tester,
  ) async {
    await pumpProfiles(tester);

    expect(find.text('default'), findsOneWidget);
    expect(find.text('Work assistant'), findsOneWidget);
    expect(find.textContaining('Day job'), findsOneWidget);
  });

  testWidgets('shows a spinner while the profiles load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilesScreen(
          repository: HermesProfilesRepository(server.client().raw),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('marks only the active profile as active', (tester) async {
    await pumpProfiles(tester);

    expect(find.text('Active'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'default'),
        matching: find.text('Active'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing a profile makes it the active one', (tester) async {
    await pumpProfiles(tester);

    server.on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    await tester.tap(find.text('Work assistant'));
    await tester.pumpAndSettle();

    final request = server.requestsTo('POST', '/api/profiles/active').single;
    expect(jsonBody(request), {'name': 'work'});
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Work assistant'),
        matching: find.text('Active'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('choosing the already active profile sends nothing', (
    tester,
  ) async {
    await pumpProfiles(tester);

    await tester.tap(find.text('default'));
    await tester.pumpAndSettle();

    expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
  });

  testWidgets('a rejected switch keeps the old active profile and says so', (
    tester,
  ) async {
    await pumpProfiles(tester);
    server.on('POST', '/api/profiles/active', {'detail': 'x'}, status: 500);

    await tester.tap(find.text('Work assistant'));
    await tester.pumpAndSettle();

    expect(find.text('Could not switch profile'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'default'),
        matching: find.text('Active'),
      ),
      findsOneWidget,
    );
  });

  group('the profile shown in the chat', () {
    final notice = find.textContaining('CLI default');

    testWidgets('is not remarked on while it is the CLI default', (
      tester,
    ) async {
      await pumpProfiles(tester, chatProfile: 'default');

      expect(notice, findsNothing);
    });

    testWidgets('is named next to the CLI default when they differ', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work'),
      );

      await pumpProfiles(tester, chatProfile: 'default');

      expect(notice, findsOneWidget);
      expect(
        tester.widget<Text>(notice).data,
        'The chat shows default. The CLI default is work.',
      );
    });

    testWidgets('is the dashboard\'s own profile when the chat has none', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work', current: 'default'),
      );

      await pumpProfiles(tester);

      expect(
        tester.widget<Text>(notice).data,
        'The chat shows default. The CLI default is work.',
      );
    });

    testWidgets('follows a profile chosen here', (tester) async {
      final switched = <String>[];
      await pumpProfiles(
        tester,
        chatProfile: 'default',
        onSwitched: switched.add,
      );
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work'),
      );

      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(switched, ['work']);
      expect(notice, findsNothing);
    });

    testWidgets('can be switched to the profile that is already active', (
      tester,
    ) async {
      final switched = <String>[];
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work'),
      );
      await pumpProfiles(
        tester,
        chatProfile: 'default',
        onSwitched: switched.add,
      );

      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
      expect(switched, ['work']);
    });

    testWidgets('stays put when the switch is rejected', (tester) async {
      final switched = <String>[];
      await pumpProfiles(
        tester,
        chatProfile: 'default',
        onSwitched: switched.add,
      );
      server.on('POST', '/api/profiles/active', {'detail': 'x'}, status: 500);

      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(switched, isEmpty);
    });
  });

  testWidgets('a failed load shows an error with a working retry', (
    tester,
  ) async {
    server.on('GET', '/api/profiles', {'detail': 'boom'}, status: 500);
    await pumpProfiles(tester);
    expect(find.text('Could not load profiles'), findsOneWidget);

    server.on(
      'GET',
      '/api/profiles',
      profileListBody([profileRow(name: 'default', isDefault: true)]),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load profiles'), findsNothing);
    expect(find.text('default'), findsOneWidget);
  });
}
