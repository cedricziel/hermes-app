import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:provider/provider.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_attachment_source.dart';
import 'support/fake_hermes_server.dart';
import 'support/find_app_icon.dart';
import 'support/pump_chat.dart';

Map<String, Object?> _profiles() => profileListBody([
  profileRow(
    name: 'default',
    displayName: 'Personal assistant',
    isDefault: true,
  ),
  profileRow(name: 'work', displayName: 'Work assistant'),
]);

Map<String, Object?> _models(String model) => {
  'model': model,
  'provider': 'anthropic',
  'providers': [
    {
      'slug': 'anthropic',
      'name': 'Anthropic',
      'authenticated': true,
      'models': [model],
      'capabilities': {
        model: {'reasoning': true},
      },
    },
  ],
};

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles', _profiles())
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'personal', title: 'Personal notes')]),
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'work-chat', title: 'Sprint planning'),
        ]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions/personal/messages',
        messageListBody('personal', []),
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions/work-chat/messages',
        messageListBody('work-chat', []),
        query: {'profile': 'work'},
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    bool models = false,
    FakeAttachmentSource? attachmentSource,
    MacCommandRegistry? commands,
  }) => pumpChatScreen(
    tester,
    server: server,
    transport: transport,
    withProfiles: true,
    attachmentSource: attachmentSource,
    commands: commands,
    platform: TargetPlatform.android,
    size: const Size(400, 800),
    providers: [
      if (models)
        Provider<HermesRepositories?>.value(
          value: HermesRepositories(server.client()),
        ),
    ],
  );

  Future<void> newMessage(WidgetTester tester, String recipient) async {
    await tester.tap(find.byTooltip('New message'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(RecipientPicker),
        matching: find.text(recipient),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(findAppIcon(AppIcons.sendArrow));
    await tester.pump();
    transport.sends.last
      ..emit(const ReplyCompleted('Done'))
      ..finish();
    await tester.pumpAndSettle();
  }

  void expectNoProfileWrites() => expect(
    server.requests.where(
      (request) =>
          request.path.startsWith('/api/profiles') && request.method != 'GET',
    ),
    isEmpty,
  );

  testWidgets(
    'New message chooses Work locally and sends only on explicit send',
    (tester) async {
      await pump(tester);

      await newMessage(tester, 'Work assistant');

      expect(find.text('To: Work assistant'), findsOneWidget);
      expect(transport.sends, isEmpty);
      expectNoProfileWrites();
      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .last
            .queryParameters['profile'],
        'work',
      );
      await tester.enterText(composerField, 'Plan the sprint');
      await tester.pump();
      await send(tester);

      expect(transport.sends.single.profile, 'work');
      expect(transport.sends.single.text, 'Plan the sprint');
      expectNoProfileWrites();
      final active = await tester.runAsync(
        () async =>
            (await server
                    .client()
                    .raw
                    .getActiveProfileEndpointApiProfilesActiveGet())
                .data,
      );
      expect(active, activeProfileBody(active: 'default'));
    },
  );

  testWidgets(
    'conversation row, recipient picker, chip and header share profile identity',
    (tester) async {
      await pump(tester);
      final rowAvatar = tester.widget<ProfileAvatar>(
        find.descendant(
          of: find.byKey(const ValueKey('thread-personal')),
          matching: find.byType(ProfileAvatar),
        ),
      );
      expect(rowAvatar.profile.name, 'default');
      expect(rowAvatar.profile.label, 'Personal assistant');

      await tester.tap(find.byTooltip('New message'));
      await tester.pumpAndSettle();
      final pickerAvatar = tester.widget<ProfileAvatar>(
        find.descendant(
          of: find.byType(RecipientPicker),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ProfileAvatar && widget.profile.name == 'default',
          ),
        ),
      );
      expect(pickerAvatar.profile.label, rowAvatar.profile.label);
      await tester.tap(
        find.descendant(
          of: find.byType(RecipientPicker),
          matching: find.text('Personal assistant'),
        ),
      );
      await tester.pumpAndSettle();

      final headerAvatar = tester.widget<ProfileAvatar>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(ProfileAvatar),
        ),
      );
      final chipAvatar = tester.widget<ProfileAvatar>(
        find.descendant(
          of: find.byType(ProfileRecipientChip),
          matching: find.byType(ProfileAvatar),
        ),
      );
      expect(headerAvatar.profile.name, rowAvatar.profile.name);
      expect(headerAvatar.profile.label, rowAvatar.profile.label);
      expect(chipAvatar.profile.name, rowAvatar.profile.name);
      expect(chipAvatar.profile.label, rowAvatar.profile.label);
    },
  );

  testWidgets(
    'recipient listing failure offers Retry and never chooses a fallback',
    (tester) async {
      await pump(tester);
      server.on('GET', '/api/profiles', {'detail': 'Unavailable'}, status: 500);

      await tester.tap(find.byTooltip('New message'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load recipients.'), findsOneWidget);
      expect(find.byType(ProfileRecipientChip), findsNothing);
      expect(composerField, findsNothing);
      expect(transport.sends, isEmpty);
      server.on('GET', '/api/profiles', _profiles());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(find.text('To: Work assistant'), findsOneWidget);
      expect(transport.sends, isEmpty);
      expectNoProfileWrites();
    },
  );

  testWidgets(
    'unavailable selected recipient retries its own profile without sending elsewhere',
    (tester) async {
      await pump(tester);
      server.on(
        'GET',
        '/api/sessions',
        {'detail': 'Profile unavailable'},
        status: 500,
        query: {'profile': 'work'},
      );

      await newMessage(tester, 'Work assistant');

      expect(find.text('Could not load your chats'), findsOneWidget);
      expect(composerField, findsNothing);
      expect(transport.sends, isEmpty);
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'work-chat', title: 'Sprint planning'),
        ]),
        query: {'profile': 'work'},
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .map((request) => request.queryParameters['profile']),
        ['default', 'work', 'work'],
      );
      expect(find.text('Sprint planning'), findsOneWidget);
      expect(transport.sends, isEmpty);
      expectNoProfileWrites();
    },
  );

  testWidgets(
    'changing an unsent recipient preserves typed draft and clears unsupported model',
    (tester) async {
      server
        ..on(
          'GET',
          '/api/model/options',
          _models('claude-opus-4'),
          query: {'profile': 'default'},
        )
        ..on(
          'GET',
          '/api/model/options',
          _models('claude-sonnet-4-5'),
          query: {'profile': 'work'},
        );
      await pump(tester, models: true);
      await newMessage(tester, 'Personal assistant');
      await tester.tap(find.byKey(const Key('composer-model-pill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('effort-high')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text(' · High'), findsOneWidget);
      await tester.enterText(composerField, 'Keep the release checklist');

      await tester.tap(find.byType(ProfileRecipientChip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Keep the release checklist',
      );
      expect(find.text('To: Work assistant'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('composer-model-pill')),
          matching: find.text('claude-sonnet-4-5'),
        ),
        findsOneWidget,
      );
      expect(find.text(' · High'), findsNothing);
      expect(transport.sends, isEmpty);
      await send(tester);

      expect(transport.sends.single.profile, 'work');
      expect(transport.sends.single.text, 'Keep the release checklist');
      expect(transport.sends.single.model, isNull);
      expectNoProfileWrites();
    },
  );

  testWidgets(
    'changing an unsent recipient carries its attachment to the chosen profile',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'hermes-recipient-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/release-checklist.txt')
        ..writeAsStringSync('Release checklist');
      final source = FakeAttachmentSource(origins: [AttachOrigin.files])
        ..picks[AttachOrigin.files] = [
          SharedFile(
            path: file.path,
            name: 'release-checklist.txt',
            mimeType: 'text/plain',
          ),
        ];
      await pump(tester, attachmentSource: source);
      await newMessage(tester, 'Personal assistant');
      await tester.tap(find.byTooltip('Add attachment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(find.text('release-checklist.txt'), findsOneWidget);

      await tester.tap(find.byType(ProfileRecipientChip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(find.text('release-checklist.txt'), findsOneWidget);
      expect(find.text('To: Work assistant'), findsOneWidget);
      expect(transport.sends, isEmpty);
      await send(tester);

      final sent = transport.sends.single;
      expect(sent.profile, 'work');
      expect(sent.attachments, hasLength(1));
      expect(sent.attachments.single.name, 'release-checklist.txt');
      expect(sent.attachments.single.mimeType, 'text/plain');
      expect(
        await tester.runAsync(sent.attachments.single.read),
        'Release checklist'.codeUnits,
      );
      expectNoProfileWrites();
    },
  );

  testWidgets(
    'a superseded recipient picker cannot move draft files into a newer chat',
    (tester) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      final source = FakeAttachmentSource(origins: [AttachOrigin.files])
        ..picks[AttachOrigin.files] = [
          const SharedFile(
            path: '/tmp/private-planning.txt',
            name: 'private-planning.txt',
          ),
        ];
      await pump(tester, attachmentSource: source, commands: commands);
      await newMessage(tester, 'Personal assistant');
      await tester.enterText(composerField, 'Private planning draft');
      await tester.tap(find.byTooltip('Add attachment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(find.text('private-planning.txt'), findsOneWidget);
      final pending = Completer<FakeResponse>();
      server.onRequest('GET', '/api/profiles', (_) => pending.future);

      await tester.tap(find.byType(ProfileRecipientChip));
      await tester.pump();
      expect(commands.invoke(MacCommand.newChat), isTrue);
      await tester.pump();
      pending.complete((status: 200, body: _profiles()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableText>(composerField).controller.text,
        isEmpty,
      );
      expect(find.text('private-planning.txt'), findsNothing);
      expect(find.text('To: Personal assistant'), findsOneWidget);
      expect(transport.sends, isEmpty);
      await tester.enterText(composerField, 'The newer chat');
      await tester.pump();
      await send(tester);
      expect(transport.sends.single.profile, 'default');
      expect(transport.sends.single.attachments, isEmpty);
      expectNoProfileWrites();
    },
  );
}
