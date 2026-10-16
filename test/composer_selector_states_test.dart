import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:provider/provider.dart';

import 'support/fake_attachment_source.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

import 'package:hermes_app/src/share/shared_item.dart';

const _readyModels = {
  'model': 'local-model',
  'provider': 'custom',
  'providers': [
    {
      'slug': 'custom',
      'name': 'Local endpoint',
      'authenticated': true,
      'models': ['local-model'],
    },
  ],
};

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', displayName: 'Personal', isDefault: true),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/model/options', _readyModels);
  });

  Future<void> pump(WidgetTester tester, {FakeAttachmentSource? files}) =>
      pumpChatScreen(
        tester,
        server: server,
        transport: transport,
        withProfiles: true,
        attachmentSource: files,
        providers: [
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(server.client()),
          ),
        ],
      );

  bool sendEnabled(WidgetTester tester) =>
      tester
          .widget<IconButton>(
            find
                .descendant(
                  of: find.byTooltip('Send'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed !=
      null;

  testWidgets(
    'empty model configuration offers setup and refreshes without losing draft',
    (tester) async {
      server.on('GET', '/api/model/options', {
        'providers': [],
        'model': '',
        'provider': '',
      });
      await pump(tester);
      await tester.enterText(composerField, 'Keep this draft');
      await tester.pump();
      expect(find.text('Set up a model'), findsOneWidget);
      expect(find.text('To: Personal'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      await tester.tap(find.text('Set up a model'));
      await tester.pumpAndSettle();
      expect(find.textContaining('hermes'), findsWidgets);
      server.on('GET', '/api/model/options', _readyModels);
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('local-model'), findsOneWidget);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Keep this draft',
      );
      expect(sendEnabled(tester), isTrue);
      expect(transport.sends, isEmpty);
    },
  );

  testWidgets(
    'recipient failure recovers independently and preserves text and attachments',
    (tester) async {
      server.on('GET', '/api/profiles', {}, status: 503);
      final files = FakeAttachmentSource();
      await pump(tester, files: files);
      await tester.enterText(composerField, 'Draft survives retry');
      files.drop([
        const SharedFile(
          path: '/synthetic/draft.txt',
          name: 'draft.txt',
          mimeType: 'text/plain',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Could not load recipients'), findsOneWidget);
      expect(find.text('local-model'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      server.on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', displayName: 'Personal', isDefault: true),
        ]),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('To: Personal'), findsOneWidget);
      expect(find.text('draft.txt'), findsOneWidget);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Draft survives retry',
      );
      expect(sendEnabled(tester), isTrue);
      expect(transport.sends, isEmpty);
    },
  );

  testWidgets(
    'empty recipient list exposes profile setup instead of hiding the selector',
    (tester) async {
      server.on('GET', '/api/profiles', profileListBody([]));
      await pump(tester);
      await tester.enterText(composerField, 'Waiting for a recipient');
      await tester.pump();
      expect(find.text('No profiles available'), findsOneWidget);
      expect(find.text('Set up profiles'), findsOneWidget);
      expect(find.text('local-model'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      await tester.tap(find.text('Set up profiles'));
      await tester.pumpAndSettle();
      expect(find.text('Profiles'), findsWidgets);
      expect(transport.sends, isEmpty);
    },
  );

  testWidgets('model failure offers Retry beside the ready recipient', (
    tester,
  ) async {
    server.on('GET', '/api/model/options', {}, status: 503);
    await pump(tester);
    await tester.enterText(
      composerField,
      'Do not send under unknown configuration',
    );
    await tester.pump();
    expect(find.text('Could not load models'), findsOneWidget);
    expect(find.text('To: Personal'), findsOneWidget);
    expect(sendEnabled(tester), isFalse);
    server.on('GET', '/api/model/options', _readyModels);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('local-model'), findsOneWidget);
    final recipient = tester.getRect(find.byType(ProfileRecipientChip));
    final model = tester.getRect(find.byKey(const Key('composer-model-pill')));
    expect((recipient.center.dy - model.center.dy).abs(), lessThan(1));
    expect(recipient.right, lessThan(model.left));
    expect(sendEnabled(tester), isTrue);
    expect(transport.sends, isEmpty);
  });
  testWidgets('a newer recipient read wins over a held initial response', (
    tester,
  ) async {
    final held = Completer<FakeResponse>();
    server.onRequest('GET', '/api/profiles', (_) => held.future);
    await pump(tester);
    expect(find.text('Loading recipients'), findsOneWidget);
    expect(find.text('local-model'), findsOneWidget);
    server.on(
      'GET',
      '/api/profiles',
      profileListBody([
        profileRow(name: 'default', displayName: 'Personal', isDefault: true),
      ]),
    );
    await tester.tap(find.text('New chat').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(RecipientPicker),
        matching: find.text('Personal'),
      ),
    );
    await tester.pumpAndSettle();
    held.complete((
      status: 200,
      body: profileListBody([
        profileRow(name: 'work', displayName: 'Stale work'),
      ]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('To: Personal'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(transport.sends, isEmpty);
  });

  testWidgets(
    'an unavailable recipient stays identified until its retry recovers',
    (tester) async {
      server.on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work', displayName: 'Work')]),
      );
      await pump(tester);
      await tester.enterText(composerField, 'Keep the intended owner');
      await tester.pump();
      expect(find.text('default unavailable'), findsOneWidget);
      expect(find.text('local-model'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      server.on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', displayName: 'Personal', isDefault: true),
        ]),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('To: Personal'), findsOneWidget);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Keep the intended owner',
      );
      expect(sendEnabled(tester), isTrue);
      expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    },
  );
}
