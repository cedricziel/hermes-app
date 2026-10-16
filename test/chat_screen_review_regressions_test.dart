import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/chat/chat_open_requests.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_attachment_source.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_gateway.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_session_auth.dart';
import 'support/fake_share_inbox.dart';
import 'support/find_app_icon.dart';
import 'support/pump_chat.dart';

FakeHermesServer _server({String personalName = 'Personal assistant'}) =>
    FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(
            name: 'default',
            displayName: personalName,
            isDefault: true,
          ),
          profileRow(name: 'work', displayName: 'Work assistant'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/sessions', sessionListBody([]));

String _draft(WidgetTester tester) =>
    tester.widget<EditableText>(composerField).controller.text;

void main() {
  testWidgets('a later navigation request supersedes the held startup quote', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    final server = _server()
      ..onRequest('GET', '/api/sessions', (_) async {
        await release.future;
        return (status: 200, body: sessionListBody([]));
      });
    final share = ShareController(
      FakeShareInbox([const SharedQuote('held selection')]),
    );
    addTearDown(share.dispose);
    await share.start();
    final requests = ChatOpenRequests()..requestNew(prompt: 'Initial request');
    addTearDown(requests.dispose);
    final transport = FakeChatTransport();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>.value(value: share),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            transport: transport,
            openRequests: requests,
          ),
        ),
      ),
    );
    requests.requestNew(prompt: 'Later request');
    await tester.pump();

    release.complete();
    await tester.pumpAndSettle();

    expect(_draft(tester), 'Later request');
    expect(transport.sends, isEmpty);
  });

  testWidgets(
    'moving a draft does not leave text or files at its old recipient',
    (tester) async {
      final server = _server();
      final transport = FakeChatTransport();
      final profiles = ChatProfiles(
        HermesProfilesRepository(server.client().raw),
      );
      addTearDown(profiles.dispose);
      final directory = Directory.systemTemp.createTempSync(
        'hermes-draft-move-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/private-notes.txt')
        ..writeAsStringSync('Only for the chosen recipient');
      final source = FakeAttachmentSource();
      await pumpChatScreen(
        tester,
        server: server,
        withProfiles: true,
        transport: transport,
        chatProfiles: profiles,
        attachmentSource: source,
      );
      await tester.enterText(composerField, 'Move this draft');
      source.drop([
        SharedFile(
          path: file.path,
          name: 'private-notes.txt',
          mimeType: 'text/plain',
        ),
      ]);
      await tester.pump();

      await tester.tap(find.byType(ProfileRecipientChip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work assistant'));
      await tester.pumpAndSettle();

      expect(_draft(tester), 'Move this draft');
      expect(find.text('private-notes.txt'), findsOneWidget);
      await tester.tap(findAppIcon(AppIcons.sendArrow));
      await tester.pump();
      expect(transport.sends.single.profile, 'work');
      expect(
        transport.sends.single.attachments.single.name,
        'private-notes.txt',
      );
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await tester.pumpAndSettle();

      final switched = profiles.switchTo('default');
      await tester.pumpAndSettle();
      expect(await switched, isTrue);

      expect(_draft(tester), isEmpty);
      expect(find.text('private-notes.txt'), findsNothing);
    },
  );

  testWidgets(
    'a retired chat clears identity and a fresh mount reads the new owner',
    (tester) async {
      final auth = FakeSessionAuth();
      addTearDown(auth.dispose);
      final oldServer = _server();
      final oldGateway = FakeGateway()..activeSessions = {};
      oldGateway.handlers['profiles.get_asset'] = (_) => {
        'found': true,
        'mime': 'image/png',
        'data':
            'data:image/png;base64,'
            'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAMElEQVR4nGNwylj7Hx9mwCc5+dhF3ApAkjgVwCSxKkCWxFCALomiAJskXAEuSRAGAMJVrJXCULtNAAAAAElFTkSuQmCC',
      };
      final oldTransport = HermesGatewayTransport(connect: oldGateway.connect);
      addTearDown(oldTransport.close);
      Future<void> mount(FakeHermesServer server, ChatTransport transport) =>
          pumpChatScreen(
            tester,
            server: server,
            withProfiles: true,
            transport: transport,
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: auth),
            ],
          );
      await mount(oldServer, oldTransport);
      expect(find.text('To: Personal assistant'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.byType(Image),
        ),
        findsWidgets,
      );
      await tester.enterText(composerField, 'Old account draft');
      final oldProfileReads = oldServer
          .requestsTo('GET', '/api/profiles')
          .length;
      final oldAssetReads = oldGateway.requests
          .where((request) => request['method'] == 'profiles.get_asset')
          .length;

      auth.depart();
      await tester.pumpAndSettle();
      auth.recover(
        const VerifiedSessionOwner(
          server: 'https://queue.test',
          user: 'another-owner',
          organization: '',
          provider: 'oidc',
        ),
      );
      await tester.pumpAndSettle();

      expect(_draft(tester), isEmpty);
      expect(
        find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      expect(
        oldServer.requestsTo('GET', '/api/profiles'),
        hasLength(oldProfileReads),
      );
      expect(
        oldGateway.requests.where(
          (request) => request['method'] == 'profiles.get_asset',
        ),
        hasLength(oldAssetReads),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      final newServer = _server(personalName: 'New account assistant');
      final newGateway = FakeGateway()..activeSessions = {};
      newGateway.handlers['profiles.get_asset'] =
          oldGateway.handlers['profiles.get_asset']!;
      final newTransport = HermesGatewayTransport(connect: newGateway.connect);
      addTearDown(newTransport.close);
      await mount(newServer, newTransport);

      expect(find.text('To: New account assistant'), findsOneWidget);
      expect(find.text('To: Personal assistant'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.byType(Image),
        ),
        findsWidgets,
      );
      expect(newServer.requestsTo('GET', '/api/profiles'), isNotEmpty);
      expect(
        newGateway.requests.where(
          (request) => request['method'] == 'profiles.get_asset',
        ),
        isNotEmpty,
      );
      expect(_draft(tester), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
