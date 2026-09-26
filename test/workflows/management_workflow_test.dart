import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart' show openSidebarMore;
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Everything reached from the chat sidebar besides chatting: skills,
/// profiles, bots and the account menu's dialogs.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/skills', [
        skillRow(
          name: 'apple-notes',
          description: 'Read and write Apple Notes',
          category: 'apple',
          usage: 14,
        ),
        skillRow(
          name: 'pr-review',
          description:
              'Review a pull request the way this team does it, leaving '
              'inline comments and a summary, and never approving without '
              'reading the tests',
          category: 'github',
          provenance: 'agent',
        ),
        skillRow(
          name: 'compose',
          description: 'Compose stacks',
          category: 'devops',
          provenance: 'hub',
          enabled: false,
        ),
        skillRow(name: 'a-skill-with-a-really-long-name-to-see-how-it-wraps'),
      ])
      ..on('GET', '/api/skills/content', {
        'name': 'pr-review',
        'content':
            '---\nname: pr-review\ndescription: Review a PR\n---\n\n'
            '# Review PRs\n\nBe kind, and be specific.\n\n'
            '1. Read the description\n2. Read the tests\n3. Read the diff\n\n'
            '```\ngh pr diff <number>\n```\n',
        'path': '/x',
      })
      ..on('PUT', '/api/skills/toggle', {'ok': true})
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(
            name: 'default',
            isDefault: true,
            model: 'hermes-4',
            provider: 'nous',
          ),
          profileRow(
            name: 'work',
            displayName: 'Work assistant',
            description: 'Day job: tickets, reviews and the on-call rota',
            skillCount: 12,
            gatewayRunning: true,
          ),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/model/options', {
        'model': 'hermes-4',
        'provider': 'nous',
        'providers': [
          {
            'slug': 'nous',
            'name': 'Nous Portal',
            'models': ['hermes-4', 'hermes-4-mini'],
          },
        ],
      })
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'telegram',
            name: 'Telegram',
            description: 'Run Hermes from Telegram.',
            enabled: true,
            configured: true,
            state: 'connected',
            envVars: [
              envVarRow(
                key: 'TELEGRAM_BOT_TOKEN',
                prompt: 'Telegram bot token',
                required: true,
                isPassword: true,
                isSet: true,
              ),
              envVarRow(
                key: 'TELEGRAM_ALLOWED_USERS',
                prompt: 'Allowed user ids',
                help: 'Comma separated',
              ),
            ],
          ),
          platformRow(
            id: 'discord',
            name: 'Discord',
            configured: true,
            state: 'disabled',
          ),
          platformRow(id: 'whatsapp', name: 'WhatsApp'),
          platformRow(
            id: 'slack',
            name: 'Slack',
            enabled: true,
            configured: true,
            state: 'error',
            errorMessage:
                'Invalid bot token: the workspace revoked it, create a new '
                'one in the Slack app settings and paste it here',
          ),
        ]),
      )
      ..on(
        'POST',
        '/api/messaging/telegram/onboarding/start',
        telegramPairingStartBody(),
      )
      ..on('GET', '/api/messaging/telegram/onboarding/p1', {
        'status': 'waiting',
      })
      ..on('DELETE', '/api/messaging/telegram/onboarding/p1', {'ok': true});
  });

  Future<void> pumpChat(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) async {
    final appLock = await newAppLock(tester);
    await pumpScreen(
      tester,
      shots,
      ChatScreen(
        repository: HermesChatRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
        models: HermesModelsRepository(server.client().raw),
        skills: HermesSkillsRepository(server.client().raw),
        bots: HermesBotsRepository(server.client().raw),
      ),
      size: size,
      brightness: brightness,
      providers: workflowProviders(appLock),
    );
  }

  Future<void> openFromSidebar(WidgetTester tester, String entry) async {
    await openSidebar(tester);
    await openSidebarMore(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text(entry),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: skills', (tester) async {
      final shots = ScreenshotRecorder('skills-$name');
      await pumpChat(tester, shots, size: size);
      await openFromSidebar(tester, 'Skills');
      await shots.capture(tester, 'list');

      await tester.tap(find.text('pr-review'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'detail');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'editor');
    });

    testWidgets('$name: profiles and bots', (tester) async {
      final shots = ScreenshotRecorder('bots-$name');
      await pumpChat(tester, shots, size: size);
      await openFromSidebar(tester, 'Profiles');
      await shots.capture(tester, 'profiles');
      await tester.tap(find.byKey(const Key('profile-model-default')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'default-model');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await popRoute(tester);

      await openFromSidebar(tester, 'Bots');
      await shots.capture(tester, 'list');

      await tester.tap(find.text('Telegram'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'setup');

      await tester.tap(find.text('Set up with Telegram'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await shots.capture(tester, 'pairing');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('$name: account dialogs', (tester) async {
      final shots = ScreenshotRecorder('settings-$name');
      await pumpChat(tester, shots, size: size);
      await openSidebar(tester);
      Future<void> pick(String item) async {
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
      }

      await pick('Appearance');
      await shots.capture(tester, 'appearance');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await pick('Notifications');
      await shots.capture(tester, 'notifications');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await pick('App lock');
      await shots.capture(tester, 'app-lock');
    });
  }

  testWidgets('dark theme', (tester) async {
    final shots = ScreenshotRecorder('skills-phone-dark');
    await pumpChat(tester, shots, size: phoneSize, brightness: Brightness.dark);
    await openFromSidebar(tester, 'Skills');
    await shots.capture(tester, 'list');
    await tester.tap(find.text('pr-review'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'detail');
  });
}
