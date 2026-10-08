import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/starter_context_loader.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/voice_recorder.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_hermes_server.dart';
import 'find_app_icon.dart';
import 'fake_share_inbox.dart';
import 'mac_commands_builder.dart';

/// The composer's editable text; the sidebar's search field is another one.
final composerField = find.descendant(
  of: find.byKey(chatComposerFieldKey),
  matching: find.byType(EditableText),
);

/// Mounts the chat screen at desktop width. Without a [server] the screen
/// falls back to its mock data. With [commands], the screen offers its menu
/// bar commands there.
Future<void> pumpChatScreen(
  WidgetTester tester, {
  FakeHermesServer? server,
  bool withProfiles = false,
  bool withSkills = false,
  ChatTransport? transport,
  List<SingleChildWidget> providers = const [],
  bool settle = true,
  VoidCallback? onShowChat,
  AttachmentSource? attachmentSource,
  StarterContextLoader? starterContext,
  TargetPlatform? platform,
  MacCommandRegistry? commands,
  VoiceRecorder? voiceRecorder,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
        ChangeNotifierProvider<ShareController>(
          create: (_) => ShareController(FakeShareInbox()),
        ),
        ...providers,
      ],
      child: MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        builder: macCommandsBuilder(commands),
        home: ChatScreen(
          repository: server == null
              ? null
              : HermesChatRepository(server.client().raw),
          profiles: withProfiles
              ? HermesProfilesRepository(server!.client().raw)
              : null,
          skills: withSkills
              ? HermesSkillsRepository(server!.client().raw)
              : null,
          transport: transport,
          onShowChat: onShowChat,
          attachmentSource: attachmentSource,
          starterContext: starterContext,
          voiceRecorder: voiceRecorder,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Opens the sidebar row titled [title]; the screen starts on the welcome
/// view, not on a thread.
Future<void> openThread(
  WidgetTester tester,
  String title, {
  bool settle = true,
}) async {
  await tester.tap(
    find.descendant(of: find.byType(ThreadSidebar), matching: find.text(title)),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Unfolds the sidebar's "More" section, which holds Profiles, Skills, Bots,
/// Plugins and MCP servers. Does nothing when it is already open.
Future<void> openSidebarMore(WidgetTester tester) async {
  final closed = find.descendant(
    of: find.byType(ThreadSidebar),
    matching: findAppIcon(AppIcons.chevronRight),
  );
  if (closed.evaluate().isEmpty) return;
  await tester.tap(closed);
  await tester.pumpAndSettle();
}
