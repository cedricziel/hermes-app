import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/bots/bots_screen.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';

import 'support/fake_hermes_server.dart';

/// Setting a bot up from its row on the bots screen, against a fake
/// dashboard through the real generated client.
void main() {
  late FakeHermesServer server;

  const token = 'Discord bot token';
  const users = 'Allowed Discord users';

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'discord',
            name: 'Discord',
            envVars: [
              envVarRow(
                key: 'DISCORD_BOT_TOKEN',
                prompt: token,
                required: true,
                isPassword: true,
                help: 'Create it in the developer portal',
              ),
              envVarRow(
                key: 'DISCORD_ALLOWED_USERS',
                prompt: users,
                isSet: true,
                redactedValue: '1234...9999',
              ),
              envVarRow(
                key: 'DISCORD_PROXY',
                prompt: 'Discord proxy',
                advanced: true,
              ),
            ],
          ),
          platformRow(id: 'yuanbao', name: 'Yuanbao'),
        ]),
      )
      ..on('PUT', '/api/messaging/platforms/discord', {'ok': true});
  });

  Future<void> openSetup(WidgetTester tester, [String name = 'Discord']) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BotsScreen(repository: HermesBotsRepository(server.client().raw)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  TextField textField(WidgetTester tester, String label) => tester.widget(
    find.descendant(of: field(label), matching: find.byType(TextField)),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  Iterable<RequestOptions> puts() =>
      server.requestsTo('PUT', '/api/messaging/platforms/discord');

  testWidgets('opens a form with a field per setup variable', (tester) async {
    await openSetup(tester);

    expect(find.text('Set up Discord'), findsOneWidget);
    expect(field(token), findsOneWidget);
    expect(field(users), findsOneWidget);
    expect(find.text('Create it in the developer portal'), findsOneWidget);
  });

  testWidgets('hides passwords and shows nothing secret for a value already '
      'set', (tester) async {
    await openSetup(tester);

    expect(textField(tester, token).obscureText, isTrue);
    expect(textField(tester, users).obscureText, isFalse);
    expect(textField(tester, users).controller!.text, isEmpty);
    expect(find.textContaining('1234...9999'), findsOneWidget);
  });

  testWidgets('keeps advanced settings out of the way until asked', (
    tester,
  ) async {
    await openSetup(tester);
    expect(find.text('Discord proxy'), findsNothing);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(field('Discord proxy'), findsOneWidget);
  });

  testWidgets('a platform with nothing to set up says so', (tester) async {
    await openSetup(tester, 'Yuanbao');

    expect(find.text('Nothing to set up for this bot.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
  });

  testWidgets('a missing required value blocks the save', (tester) async {
    await openSetup(tester);
    await tester.enterText(field(users), '42');

    await save(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(puts(), isEmpty);
  });

  testWidgets('a required value that is already set need not be entered '
      'again', (tester) async {
    server.on(
      'GET',
      '/api/messaging/platforms',
      platformListBody([
        platformRow(
          id: 'discord',
          name: 'Discord',
          envVars: [
            envVarRow(
              key: 'DISCORD_BOT_TOKEN',
              prompt: token,
              required: true,
              isSet: true,
              isPassword: true,
            ),
            envVarRow(key: 'DISCORD_ALLOWED_USERS', prompt: users),
          ],
        ),
      ]),
    );
    await openSetup(tester);
    await tester.enterText(field(users), '42');

    await save(tester);

    expect(find.text('Required'), findsNothing);
    expect(jsonBody(puts().single), {
      'env': {'DISCORD_ALLOWED_USERS': '42'},
      'clear_env': <String>[],
    });
  });

  testWidgets('saving sends exactly the values that were entered', (
    tester,
  ) async {
    await openSetup(tester);
    await tester.enterText(field(token), '  secret-token  ');

    await save(tester);

    expect(jsonBody(puts().single), {
      'env': {'DISCORD_BOT_TOKEN': 'secret-token'},
      'clear_env': <String>[],
    });
  });

  testWidgets('clearing a value that is set sends its key in clear_env', (
    tester,
  ) async {
    await openSetup(tester);
    await tester.enterText(field(token), 'secret-token');

    await tester.tap(find.byTooltip('Clear $users'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(jsonBody(puts().single), {
      'env': {'DISCORD_BOT_TOKEN': 'secret-token'},
      'clear_env': ['DISCORD_ALLOWED_USERS'],
    });
  });

  testWidgets('a cleared value can be kept after all', (tester) async {
    await openSetup(tester);
    await tester.enterText(field(token), 'secret-token');
    await tester.tap(find.byTooltip('Clear $users'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Keep $users'));
    await tester.pumpAndSettle();
    await save(tester);

    expect((jsonBody(puts().single) as Map)['clear_env'], isEmpty);
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    server.on('PUT', '/api/messaging/platforms/discord', {
      'detail': 'boom',
    }, status: 500);
    await openSetup(tester);
    await tester.enterText(field(token), 'secret-token');

    await save(tester);

    expect(find.text('Could not save the setup'), findsOneWidget);
    expect(find.text('Set up Discord'), findsOneWidget);
    expect(textField(tester, token).controller!.text, 'secret-token');
  });

  testWidgets('a value the dashboard refuses shows the reason', (tester) async {
    server.on('PUT', '/api/messaging/platforms/discord', {
      'detail': 'Discord bot token looks wrong',
    }, status: 400);
    await openSetup(tester);
    await tester.enterText(field(token), 'nope');

    await save(tester);

    expect(find.text('Discord bot token looks wrong'), findsOneWidget);
    expect(textField(tester, token).controller!.text, 'nope');
  });

  testWidgets('a successful save returns to the list, where the bot no '
      'longer needs setup', (tester) async {
    await openSetup(tester);
    server.on(
      'GET',
      '/api/messaging/platforms',
      platformListBody([
        platformRow(id: 'discord', name: 'Discord', configured: true),
        platformRow(id: 'yuanbao', name: 'Yuanbao'),
      ]),
    );
    await tester.enterText(field(token), 'secret-token');

    await save(tester);

    expect(find.text('Set up Discord'), findsNothing);
    expect(find.text('Needs setup'), findsOneWidget);
  });
}
