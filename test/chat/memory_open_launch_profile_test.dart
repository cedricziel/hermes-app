import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart'
    show ActiveProfile;
import 'package:hermes_app/src/profiles/profile_resolver.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late AttentionNotifier attention;
  ChatController? chat;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'A chat')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', []),
      );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
  });
  tearDown(() {
    chat?.dispose();
    attention.dispose();
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    ProfileResolver? resolver,
    String? chatProfile,
  }) async {
    final c = chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      profileResolver: resolver,
      attention: attention,
      report: (_) {},
    );
    await tester.runAsync(() async {
      await c.loadThreads(chatProfile);
      c.select('stored-1');
      await pumpEventQueue();
    });
    c.selectedThread!.messages.add(
      ChatMessage(
        id: 'm1',
        role: ChatRole.assistant,
        content: 'Done',
        createdAt: DateTime(2030),
      )..reviewNotes = const ['Memory updated'],
    );
    await tester.pumpWidget(
      Provider<HermesRepositories?>.value(
        value: null,
        child: MaterialApp(
          builder: (_, child) => AppThemeScopes(child: child!),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BoundActivityPanel(chat: c, thread: c.selectedThread),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Memory & review'));
    await tester.pumpAndSettle();
  }

  Future<void> openMemory(WidgetTester tester) async {
    await tester.tap(find.text('Memory'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String? openedProfile(WidgetTester tester) =>
      tester.widget<MemoryDestination>(find.byType(MemoryDestination)).profile;

  testWidgets('a chat with no profile opens Memory on the launch profile', (
    tester,
  ) async {
    await pumpPanel(tester, resolver: ProfileResolver.known('main'));
    expect(chat!.profile, isNull);
    await openMemory(tester);
    expect(openedProfile(tester), 'main');
  });

  testWidgets('with no launch profile either there is no Open Memory', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      resolver: ProfileResolver(() async => throw Exception('none')),
    );
    expect(find.text('Memory updated'), findsOneWidget);
    expect(find.text('Memory'), findsNothing);
  });

  testWidgets("the chat's own profile wins over the launch profile", (
    tester,
  ) async {
    await pumpPanel(
      tester,
      resolver: ProfileResolver.known('main'),
      chatProfile: 'work',
    );
    await openMemory(tester);
    expect(openedProfile(tester), 'work');
  });

  testWidgets('an own profile opens Memory without a resolver', (tester) async {
    await pumpPanel(tester, chatProfile: 'work');
    await openMemory(tester);
    expect(openedProfile(tester), 'work');
  });

  testWidgets('a launch profile that arrives later shows the link', (
    tester,
  ) async {
    final answer = Completer<ActiveProfile>();
    final resolver = ProfileResolver(() => answer.future);
    await pumpPanel(tester, resolver: resolver);
    expect(find.text('Memory updated'), findsOneWidget);
    expect(find.text('Memory'), findsNothing);
    answer.complete((active: 'main', current: 'main'));
    await tester.runAsync(resolver.load);
    await tester.pump();
    await openMemory(tester);
    expect(openedProfile(tester), 'main');
  });
}
