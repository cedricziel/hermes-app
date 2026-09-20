import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_share_inbox.dart';

/// A notification about a scheduled task is not about a chat: the chat hands
/// its target over instead of saying it could not open it.
void main() {
  late FakeHermesServer server;
  late FakeNotificationService service;
  late List<NotificationTarget> opened;
  late int shown;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    opened = [];
    shown = 0;
    service = FakeNotificationService();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'recent', title: 'Recent chat')]),
        query: {'profile': 'work'},
      );
  });

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          Provider<NotificationService>.value(value: service),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            transport: FakeChatTransport(),
            onShowChat: () => shown++,
            onOpenJob: opened.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a tap on a job notification is handed over', (tester) async {
    await pumpChat(tester);

    service.tapJob('job1', profile: 'work');
    await tester.pumpAndSettle();

    expect(opened.single.jobId, 'job1');
    expect(opened.single.profile, 'work');
    expect(find.text('Could not open that chat.'), findsNothing);
    expect(shown, 0);
  });

  testWidgets('a job notification that started the app is handed over', (
    tester,
  ) async {
    service
      ..launchJob = 'job1'
      ..launchProfile = 'work';

    await pumpChat(tester);

    expect(opened.single.jobId, 'job1');
    expect(find.text('Could not open that chat.'), findsNothing);
  });

  testWidgets('a chat notification is still a chat', (tester) async {
    await pumpChat(tester);

    service.tap('recent', profile: 'work');
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(shown, greaterThan(0));
  });
}
