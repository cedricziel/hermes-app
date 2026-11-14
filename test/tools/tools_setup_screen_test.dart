import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';
import 'package:hermes_app/src/tools/widgets/tools_switch.dart';

import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

/// The setup area of a toolset's details, through the real screen, the real
/// generated client and the fake server: providers, keys, the model.
void main() {
  late SetupWorld world;
  late SetupHarness h;

  const web = '/api/tools/toolsets/web';

  Future<void> start(
    WidgetTester tester, {
    Size size = phone,
    void Function(SetupWorld world)? prepare,
  }) async {
    world = SetupWorld();
    prepare?.call(world);
    h = SetupHarness(tester, world);
    await h.pump(size: size);
  }

  group('the provider choice', () {
    testWidgets('a toolset that needs setup shows the area open, with the '
        'providers and what each needs', (tester) async {
      await start(tester);
      await h.openWeb();

      expect(find.text('Set up'), findsOneWidget);
      expect(find.text('Change setup'), findsNothing);
      expect(h.provider('Search Co'), findsOneWidget);
      expect(h.provider('Local Driver'), findsOneWidget);
      expect(h.provider('Nous Web'), findsOneWidget);
      expect(find.text('Needs a key'), findsOneWidget);
      expect(find.text('Needs install'), findsOneWidget);
      expect(find.text('Needs a sign-in on the server'), findsOneWidget);
      expect(
        find.text(
          'Hermes uses the one you choose. Applies from your next chat.',
        ),
        findsOneWidget,
      );
      // One read of the matrix, for the profile.
      final reads = world.server.requestsTo('GET', '$web/config');
      expect(reads, isNotEmpty);
      expect(reads.first.queryParameters['profile'], 'work');
      await h.close();
    });

    testWidgets('picking a provider sends it with the profile, then reads '
        'the setup and the list again', (tester) async {
      await start(tester);
      await h.openWeb();
      final listReads = world.server
          .requestsTo('GET', '/api/tools/toolsets')
          .length;
      final configReads = world.server.requestsTo('GET', '$web/config').length;

      await h.pick('Local Driver');

      final bodies = world.bodies('PUT', '$web/provider');
      expect(bodies, hasLength(1));
      expect(bodies.single['provider'], 'Local Driver');
      expect(bodies.single['profile'], 'work');
      expect(bodies.single['capability'], isNull);
      expect(world.webActive, 'Local Driver');
      expect(
        world.server.requestsTo('GET', '$web/config').length,
        greaterThan(configReads),
      );
      expect(
        world.server.requestsTo('GET', '/api/tools/toolsets').length,
        greaterThan(listReads),
      );
      await h.close();
    });

    testWidgets('a managed provider that needs a sign-in shows the note and '
        'no key field', (tester) async {
      await start(tester);
      await h.openWeb();

      expect(find.byType(TextField), findsOneWidget);
      await h.pick('Nous Web');

      expect(
        find.text(
          'This needs a sign-in to Nous Portal on your server. The app can\'t do that for you.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      await h.close();
    });

    testWidgets('Advanced sends the capability and leaves the other as it '
        'was', (tester) async {
      await start(tester);
      await h.openWeb();

      await h.tapText('Use different providers for search and extract');
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Extract'), findsOneWidget);
      expect(
        find.text('Most people use one provider for both.'),
        findsOneWidget,
      );

      // The Local Driver row of the Extract group is the second on screen:
      // the providers, then Search (which does not list it), then Extract.
      expect(h.provider('Local Driver'), findsNWidgets(2));
      await h.pick('Local Driver', index: 1);

      final bodies = world.bodies('PUT', '$web/provider');
      expect(bodies, hasLength(1));
      expect(bodies.single['capability'], 'extract');
      expect(bodies.single['provider'], 'Local Driver');
      expect(world.webExtract, 'localdriver');
      expect(world.webSearch, 'searchco');
      await h.close();
    });

    testWidgets('a refused pick leaves the old provider and shows Hermes\' '
        'sentence', (tester) async {
      await start(tester);
      await h.openWeb();
      world.server.on('PUT', '$web/provider', {
        'detail': 'That provider is not available.',
      }, status: 400);

      await h.pick('Local Driver');

      expect(world.webActive, 'Search Co');
      expect(find.text('That provider is not available.'), findsOneWidget);
      await h.close();
    });

    testWidgets('a lost answer says it may have changed, then that it could '
        'not be confirmed, and sends the pick once', (tester) async {
      await start(tester);
      await h.openWeb();
      world.loseAnswer('PUT', '$web/provider');
      world.server.onRequest('GET', '$web/config', (_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return (status: 200, body: world.webConfig());
      });

      await tester.ensureVisible(h.provider('Local Driver'));
      await tester.pump();
      await tester.tap(h.provider('Local Driver'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('May have changed. Checking…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      expect(find.textContaining("Couldn't confirm."), findsOneWidget);
      expect(world.bodies('PUT', '$web/provider'), hasLength(1));
      await tester.pump(const Duration(seconds: 30));
      await h.close();
    });

    testWidgets('a toolset with nothing to set up says so', (tester) async {
      await start(tester);
      await h.open('Keep a to-do list while working.');

      expect(find.text('Nothing to set up.'), findsOneWidget);
      await h.close();
    });

    testWidgets('loading, then a failed read with Try again that works', (
      tester,
    ) async {
      await start(tester);
      world.server.on('GET', '$web/config', {'detail': 'x'}, status: 500);
      await h.openWeb();

      expect(find.text("Couldn't load setup."), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
      // The switch still works.
      final header = find.descendant(
        of: find.byType(ToolsetHeader),
        matching: find.byType(ToolsSwitch),
      );
      expect(tester.widget<ToolsSwitch>(header).onChanged, isNotNull);

      world.server.onRequest(
        'GET',
        '$web/config',
        (_) => (status: 200, body: world.webConfig()),
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(h.provider('Search Co'), findsOneWidget);
      await h.close();
    });

    testWidgets('a set-up toolset shows a collapsed Change setup row with the '
        'active provider', (tester) async {
      await start(tester, prepare: (w) => w.webKeySet = true);
      await h.openWeb();

      expect(find.text('Change setup'), findsOneWidget);
      expect(find.text('Search Co'), findsOneWidget);
      expect(h.provider('Local Driver'), findsNothing);

      await h.tapText('Change setup');
      expect(h.provider('Local Driver'), findsOneWidget);
      await h.close();
    });
  });

  group('keys', () {
    testWidgets('the field is hidden, counts what was typed, and Get a key '
        'opens the page outside the app', (tester) async {
      await start(tester);
      await h.openWeb();

      expect(find.text('Key for Search Co'), findsOneWidget);
      expect(find.text('Search Co API key'), findsOneWidget);
      expect(h.fieldObscured, isTrue);
      await h.type('abcdefghijklmno');
      expect(find.text('15 characters entered'), findsOneWidget);
      expect(h.fieldObscured, isTrue);

      await h.tapText('Get a key');
      expect(h.links, [Uri.parse('https://searchco.example/keys')]);
      await h.close();
    });

    testWidgets('Save sends only the typed field, clears it and shows '
        'Already set', (tester) async {
      await start(tester);
      await h.openWeb();
      await h.type(typedKey);

      await h.tapText('Save');

      final bodies = world.bodies('PUT', '$web/env');
      expect(bodies, hasLength(1));
      expect(bodies.single['env'], {'SEARCHCO_API_KEY': typedKey});
      expect(bodies.single['profile'], 'work');
      expect(find.text('Saved.'), findsOneWidget);
      expect(find.text('Already set'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      // The list was read again: Web no longer needs setup.
      expect(find.text('Change setup'), findsOneWidget);
      await h.close();
    });

    testWidgets('Replace brings the field back, empty', (tester) async {
      await start(tester, prepare: (w) => w.webKeySet = true);
      await h.openWeb();
      await h.tapText('Change setup');

      expect(find.text('Already set'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await h.tapText('Replace');
      expect(find.byType(TextField), findsOneWidget);
      expect(h.fieldText, isEmpty);
      await h.close();
    });

    testWidgets('a blank field is never sent', (tester) async {
      await start(tester);
      await h.openWeb();
      await h.type('   ');

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(save.onPressed, isNull);
      expect(world.server.requestsTo('PUT', '$web/env'), isEmpty);
      await h.close();
    });

    testWidgets('a failed save keeps the value, hidden, and sends nothing '
        'again', (tester) async {
      await start(tester);
      await h.openWeb();
      world.server.on('PUT', '$web/env', {'detail': 'boom'}, status: 500);
      await h.type(typedKey);

      await h.tapText('Save');

      expect(find.text("Couldn't save the key. Try again."), findsOneWidget);
      expect(h.fieldText, typedKey);
      expect(h.fieldObscured, isTrue);
      expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      await tester.pump(const Duration(seconds: 30));
      expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      await h.close();
    });

    testWidgets('a failed save hides a key that was shown', (tester) async {
      await start(tester);
      await h.openWeb();
      world.server.on('PUT', '$web/env', {'detail': 'boom'}, status: 500);
      await h.type(typedKey);
      await h.showKey();
      expect(h.fieldObscured, isFalse);

      await h.tapText('Save');

      expect(h.fieldObscured, isTrue);
      await h.close();
    });

    testWidgets('a lost answer clears the field, says Checking, and asks '
        'to paste it again when the key is not set', (tester) async {
      await start(tester);
      await h.openWeb();
      world.loseAnswer('PUT', '$web/env');
      await h.type(typedKey);

      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        find.text("The key wasn't saved. Paste it again."),
        findsOneWidget,
      );
      expect(h.fieldText, isEmpty);
      expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      await h.close();
    });

    testWidgets('the lost answer shows May have saved while it checks', (
      tester,
    ) async {
      await start(tester);
      await h.openWeb();
      world.loseAnswer('PUT', '$web/env');
      await h.type(typedKey);
      world.server.onRequest('GET', '$web/config', (_) async {
        await Future<void>.delayed(const Duration(seconds: 30));
        return (status: 200, body: world.webConfig());
      });

      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('May have saved. Checking…'), findsOneWidget);
      expect(h.fieldText, isEmpty);

      await tester.pump(const Duration(seconds: 11));
      expect(find.textContaining("Couldn't confirm."), findsOneWidget);
      expect(world.server.requestsTo('PUT', '$web/env'), hasLength(1));
      await tester.pump(const Duration(seconds: 30));
      await h.close();
    });

    testWidgets("typing for another provider is dropped when the pick "
        'moves', (tester) async {
      await start(tester);
      await h.openWeb();
      await h.type(typedKey);

      await h.pick('Local Driver');

      expect(find.byType(TextField), findsNothing);
      await h.pick('Search Co');
      expect(h.fieldText, isEmpty);
      await h.close();
    });
  });

  group('the model', () {
    testWidgets('Image generation shows a Model row, a pick sends the id and '
        'refused text shows', (tester) async {
      await start(tester);
      await h.openImages();

      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Fast One'), findsOneWidget);
      expect(
        find.text(
          'Prices come from the provider, Image Co, as it gives them. Applies from your next chat.',
        ),
        findsOneWidget,
      );

      await h.tapText('Model');
      expect(find.text('Fine Two'), findsOneWidget);
      await tester.tap(find.text('Fine Two'));
      await tester.pumpAndSettle();
      final bodies = world.bodies('PUT', '/api/tools/toolsets/image_gen/model');
      expect(bodies.single['model'], 'fine-2');
      expect(bodies.single['profile'], 'work');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Fine Two'), findsOneWidget);
      await h.close();
    });

    testWidgets('a toolset without a catalog has no Model row', (tester) async {
      await start(tester);
      await h.openWeb();

      expect(find.text('Model'), findsNothing);
      expect(
        world.server.requestsTo('GET', '$web/models'),
        isEmpty,
        reason: 'only image and video generation have a catalog',
      );
      await h.close();
    });
  });

  group('the switch', () {
    testWidgets('is disabled while a setup write runs and sends nothing '
        'behind it', (tester) async {
      await start(tester, size: wide);
      final held = Completer<void>();
      world.server.onRequest('PUT', '$web/provider', (request) async {
        await held.future;
        return (status: 200, body: {'ok': true, 'name': 'web'});
      });
      final header = find.descendant(
        of: find.byType(ToolsetHeader),
        matching: find.byType(ToolsSwitch),
      );
      final row = find.descendant(
        of: find.byKey(const ValueKey('tool-row-web')),
        matching: find.byType(ToolsSwitch),
      );
      expect(tester.widget<ToolsSwitch>(header).onChanged, isNotNull);

      await tester.tap(h.provider('Local Driver'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.widget<ToolsSwitch>(header).onChanged, isNull);
      expect(tester.widget<ToolsSwitch>(row).onChanged, isNull);
      expect(tester.widget<ToolsSwitch>(header).saving, isFalse);

      held.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ToolsSwitch>(header).onChanged, isNotNull);
      expect(tester.widget<ToolsSwitch>(row).onChanged, isNotNull);
      expect(
        world.server.requestsTo('PUT', web),
        isEmpty,
        reason: 'no switch was sent',
      );
      await h.close();
    });
  });
}
