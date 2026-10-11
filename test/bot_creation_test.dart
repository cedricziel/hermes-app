import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    testWidgets('creation uses adaptive controls on $platform', (tester) async {
      final fixture = _CreationFixture();
      await fixture.pump(tester, platform: platform);
      final apple = platform != TargetPlatform.android;
      expect(
        find.byType(CupertinoAlertDialog),
        apple ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(CupertinoTextField),
        apple ? findsNWidgets(3) : findsNothing,
      );
      expect(
        find.byType(CupertinoDialogAction),
        apple ? findsNWidgets(2) : findsNothing,
      );
      expect(find.text('Standing instructions'), findsNothing);
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      expect(find.text('Copy provider API keys'), findsOneWidget);
      if (apple) expect(find.byType(CupertinoTextField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(EditableText).first, 'writer');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(fixture.opened.single.name, 'writer');
    });
  }

  for (final advanced in [false, true]) {
    testWidgets('creates and opens bot with advanced=$advanced', (
      tester,
    ) async {
      final fixture = _CreationFixture();
      await fixture.pump(tester);
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      expect(find.text('Standing instructions'), findsNothing);
      expect(find.text('Copy provider API keys'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'writer');
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Editor');
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'Careful editing',
      );
      if (advanced) {
        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();
        expect(find.textContaining('OAuth'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Standing instructions'),
          'Check claims.',
        );
        await tester.ensureVisible(find.text('Choose model and provider'));
        await tester.tap(find.text('Choose model and provider'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('test-model'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(fixture.creates, hasLength(1));
      expect(fixture.creates.single['mirror_credentials'], true);
      expect(fixture.creates.single['clone_channels'], false);
      expect(fixture.creates.single['model'], advanced ? 'test-model' : null);
      expect(
        fixture.creates.single['provider'],
        advanced ? 'test-provider' : null,
      );
      expect(fixture.opened.single.name, 'writer');
      expect(fixture.opened.single.title, 'Editor');
      expect(fixture.opened.single.metadata['description'], 'Careful editing');
      expect(find.text('Create bot'), findsNothing);
    });
  }

  testWidgets('validates names and retries metadata without recreating', (
    tester,
  ) async {
    final fixture = _CreationFixture()..failSave = true;
    await fixture.pump(tester);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a profile name.'), findsOneWidget);
    expect(fixture.creates, isEmpty);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'writer');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(fixture.creates, hasLength(1));
    expect(fixture.opened, isEmpty);
    fixture.failSave = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(fixture.creates, hasLength(1));
    expect(fixture.opened.single.name, 'writer');
  });

  testWidgets('prevents duplicate submissions while saving', (tester) async {
    final fixture = _CreationFixture()..createGate = Completer<void>();
    await fixture.pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'writer');
    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Creating…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    expect(fixture.creates, hasLength(1));
    fixture.createGate!.complete();
    await tester.pumpAndSettle();
    expect(fixture.opened, hasLength(1));
  });

  testWidgets('can clear a model selection and disable key copying', (
    tester,
  ) async {
    final fixture = _CreationFixture();
    await fixture.pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'writer');
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose model and provider'));
    await tester.tap(find.text('Choose model and provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('test-model'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('test-provider · test-model'));
    await tester.tap(find.text('test-provider · test-model'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('model-default')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copy provider API keys'));
    await tester.tap(find.text('Copy provider API keys'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(fixture.creates.single.containsKey('model'), false);
    expect(fixture.creates.single.containsKey('provider'), false);
    expect(fixture.creates.single['mirror_credentials'], false);
  });

  testWidgets('model loading failure keeps basic creation usable', (
    tester,
  ) async {
    final fixture = _CreationFixture()..modelFailure = true;
    await fixture.pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'writer');
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose model and provider'));
    await tester.tap(find.text('Choose model and provider'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load models. Try again.'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(fixture.opened, hasLength(1));
  });
}

class _CreationFixture {
  final creates = <Map<String, Object?>>[];
  final opened = <BotModeBot>[];
  bool failSave = false;
  bool modelFailure = false;
  Completer<void>? createGate;
  Map<String, Object?>? metadata;

  Future<void> pump(WidgetTester tester, {TargetPlatform? platform}) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/model/options', {
        'providers': [
          {
            'slug': 'test-provider',
            'models': ['test-model'],
            'authenticated': true,
          },
        ],
      }, status: modelFailure ? 500 : 200);
    final repository = BotModeRosterRepository((method, params) async {
      switch (method) {
        case 'profiles.create':
          creates.add(Map.of(params));
          await createGate?.future;
          return {'ok': true, 'name': params['name']};
        case 'profiles.configure':
          if (failSave) throw StateError('Save failed');
          metadata = Map<String, Object?>.from(params['ui_meta'] as Map);
          return {
            'applied': {'ui_meta': true},
          };
        default:
          return {
            'bot_mode_protocol': true,
            'profiles': [
              if (creates.isNotEmpty)
                {
                  'name': creates.single['name'],
                  'description': creates.single['description'],
                  'ui_meta_revisions': {
                    'hermes-bots': metadata == null ? 0 : 1,
                  },
                  if (metadata != null) 'ui_meta': metadata,
                },
            ],
          };
      }
    }, serverId: 'local');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform ?? TargetPlatform.android),
        home: BotModeRosterScreen(
          repository: repository,
          models: HermesModelsRepository(server.client().raw),
          onOpen: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create bot'));
    await tester.pumpAndSettle();
  }
}
