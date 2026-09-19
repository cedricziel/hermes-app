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

  Future<void> pumpProfiles(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilesScreen(
          repository: HermesProfilesRepository(server.client().raw),
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
