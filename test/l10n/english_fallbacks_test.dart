import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/group_rooms_panel.dart';
import 'package:hermes_app/src/bot_mode/groups/widgets/group_widgets.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_creation_fields.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_edit_fields.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_header.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/bot_screen/widgets/sudo_password_prompt.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_controller.dart';
import 'package:hermes_app/src/mcp/mcp_sign_in_screen.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/messaging_screen.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/hermes_status.dart';
import 'package:hermes_app/src/plugins/hermes_plugin_manager_repository.dart';
import 'package:hermes_app/src/plugins/plugins_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profile_switcher.dart';
import 'package:hermes_app/src/quick_panel/widgets/quick_panel_view.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_actions.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/screens/widgets/connection_summary.dart';
import 'package:hermes_app/src/settings/widgets/mac_account_footer.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../bot_mode/group_protocol/groups_repository_test.dart' as fixtures;
import '../hermes_plugin_manager_repository_test.dart'
    show memoryOption, providersHub;
import '../support/cron_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';
import '../support/tooltip_finder.dart';

/// Every text a widget falls back to when its value is missing is read from
/// the ARB files, so a German user does not see English there. Each test
/// builds the widget with the value missing, in German, and finds the German
/// text (and no English one).
Widget _de(Widget home, {TargetPlatform platform = TargetPlatform.android}) =>
    MaterialApp(
      builder: (_, child) => AppThemeScopes(child: child!),
      theme: buildHermesLightTheme(platform: platform),
      locale: const Locale('de'),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// A controller whose sign-in start is declined with no note, which is the
/// state the sign-in screen falls back from.
class _DecliningController extends McpServersController {
  _DecliningController(HermesMcpRepository repository)
    : super(repository: repository);

  @override
  Future<McpSignInStart> startSignIn(HermesMcpServer server) async =>
      const McpSignInDeclined();

  @override
  String? signInNoteOf(String name) => null;
}

Widget _scaffold(Widget child) =>
    Scaffold(body: SingleChildScrollView(child: child));

void main() {
  group('bot mode', () {
    testWidgets('the new bot form: name footer and model row', (tester) async {
      final controllers = List.generate(4, (_) => TextEditingController());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });
      await tester.pumpWidget(
        _de(
          _scaffold(
            BotCreationFields(
              name: controllers[0],
              title: controllers[1],
              description: controllers[2],
              soul: controllers[3],
              copyKeys: false,
              onCopyKeysChanged: (_) {},
              onChooseModel: () {},
              initiallyExpanded: true,
            ),
          ),
        ),
      );
      expect(
        find.text('Der Name ist die dauerhafte Kennung des Profils.'),
        findsOneWidget,
      );
      expect(find.text('Server-Standard verwenden'), findsOneWidget);
      expect(find.text('Use server default'), findsNothing);
      expect(
        find.text('Name is the permanent profile identifier.'),
        findsNothing,
      );
    });

    testWidgets('the bot edit form: model row', (tester) async {
      final controllers = List.generate(4, (_) => TextEditingController());
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });
      await tester.pumpWidget(
        _de(
          _scaffold(
            BotEditFields(
              profile: 'writer',
              title: controllers[0],
              summary: controllers[1],
              description: controllers[2],
              soul: controllers[3],
              onChooseModel: () {},
            ),
          ),
        ),
      );
      expect(find.text('Standardmodell wählen'), findsOneWidget);
      expect(find.text('Choose default model'), findsNothing);
    });

    testWidgets('a discussion thread without a name', (tester) async {
      final event = GroupEvent.fromJson({
        'room_id': 'room',
        'seq': 1,
        'event_id': 'e1',
        'kind': 'message.user',
        'actor': {'kind': 'user', 'id': 'user'},
        'payload': {'text': 'hello', 'thread_id': 'thread-1'},
        'created_at': 1.0,
      });
      await tester.pumpWidget(
        _de(_scaffold(GroupEventRow(event: event, members: const []))),
      );
      expect(find.text('Diskussionsthread'), findsOneWidget);
      expect(find.text('Discussion thread'), findsNothing);
    });

    testWidgets('a pending request without a description or a reason', (
      tester,
    ) async {
      final approval = GroupPendingAction.fromJson({
        'kind': 'approval',
        'task_id': 'task',
        'member_id': 'member',
        'request_id': 'request',
        'execution_generation': 1,
      });
      final other = GroupPendingAction.fromJson({
        'kind': 'clarify',
        'task_id': 'task',
      });
      await tester.pumpWidget(
        _de(
          _scaffold(
            GroupActivity(
              working: false,
              blocked: true,
              counts: const {},
              members: const [],
              actions: [approval, other],
              pending: false,
              onStop: () {},
              onApprove: (_, _) async {},
              onRetry: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.text('Dieses Mitglied wartet auf deine Zustimmung.'),
        findsOneWidget,
      );
      expect(find.text('Ausstehend: clarify'), findsOneWidget);
      expect(
        find.text('This member is waiting for your approval.'),
        findsNothing,
      );
      expect(find.text('Pending clarify'), findsNothing);
    });

    testWidgets('the Groups footer when the server gives no reason', (
      tester,
    ) async {
      final repo = HermesGroupsRepository((method, params) async {
        switch (method) {
          case 'groups.capabilities':
            return fixtures.capabilities();
          case 'groups.list':
            return {'rooms': [], 'next_offset': null};
          default:
            throw StateError(method);
        }
      });
      await tester.pumpWidget(
        _de(
          Scaffold(
            body: ListView(
              children: [
                GroupRoomsPanel(
                  repository: repo,
                  bots: const [
                    BotModeBot(serverId: 'server', name: 'one', revision: 1),
                    BotModeBot(serverId: 'server', name: 'two', revision: 1),
                  ],
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bots in einer Gruppe bearbeiten gemeinsam'),
        findsOneWidget,
      );
      expect(find.textContaining('Bots in a group work'), findsNothing);
    });

    testWidgets('the model change confirmation when the server words none', (
      tester,
    ) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/model/options', {
          'providers': [
            {
              'slug': 'test-provider',
              'models': ['test-model'],
              'authenticated': true,
            },
          ],
        });
      final repository = BotModeRosterRepository((method, params) async {
        switch (method) {
          case 'profiles.describe':
            return {
              'name': 'writer',
              'description': '',
              'soul': '',
              'model': {'default': 'old-model', 'provider': 'test-provider'},
            };
          case 'profiles.configure':
            return {
              'applied': {'ui_meta': true, 'model': true},
              'confirm_required': true,
            };
          default:
            return {
              'bot_mode_protocol': true,
              'profiles': [
                {
                  'name': 'writer',
                  'model': 'old-model',
                  'ui_meta_revisions': {'hermes-bots': 1},
                  'ui_meta': {
                    'hermes-bots': {'title': 'Editor'},
                  },
                },
              ],
            };
        }
      }, serverId: 'local');
      await tester.pumpWidget(
        _de(
          BotModeRosterScreen(
            repository: repository,
            models: HermesModelsRepository(server.client().raw),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.tooltip('Edit bot'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('old-model'));
      await tester.tap(find.text('old-model'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('test-model'));
      await tester.tap(find.text('test-model'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Dieses Modell kann mehr kosten. Als Standard verwenden?'),
        findsOneWidget,
      );
      expect(find.textContaining('This model may cost more'), findsNothing);
    });
  });

  group('bot screen', () {
    testWidgets('the viewer header names the screen when no state is known', (
      tester,
    ) async {
      await tester.pumpWidget(
        _de(
          Material(
            child: BotScreenViewerHeader(
              profile: 'research',
              control: null,
              inControl: false,
              action: null,
              presentation: BotScreenViewerPresentation.page,
              onClose: () {},
            ),
          ),
        ),
      );
      expect(find.text('Bot-Bildschirm'), findsOneWidget);
      expect(find.text('Bot screen'), findsNothing);
    });

    testWidgets('the sudo question names a host it cannot read', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _de(
          Scaffold(
            body: SudoPasswordPrompt(
              host: null,
              profile: 'work',
              controller: controller,
              onInstall: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Your Hermes server (dein Server)'),
        findsOneWidget,
      );
      expect(find.textContaining('your server'), findsNothing);
    });
  });

  group('chat', () {
    testWidgets('the memory card names its review when there is no recall', (
      tester,
    ) async {
      await tester.pumpWidget(
        _de(
          const Scaffold(
            body: MemoryActivityCard(
              recalls: [],
              reviewNotes: ['saved a note'],
            ),
          ),
        ),
      );
      expect(find.text('Hintergrundprüfung'), findsOneWidget);
      expect(find.text('Background review'), findsNothing);
    });

    testWidgets('an approval answered with a choice the app does not know', (
      tester,
    ) async {
      await tester.pumpWidget(
        _de(
          Scaffold(
            body: ApprovalCard(
              request: const ApprovalRequest(
                requestId: 'r1',
                command: 'ls',
                description: 'list',
                choices: ['once', 'deny'],
                status: InputRequestStatus.answered,
                choice: 'later',
              ),
              onAnswer: (_) async {},
            ),
          ),
        ),
      );
      expect(find.text('Beantwortet'), findsOneWidget);
      expect(find.text('Answered'), findsNothing);
    });

    testWidgets('the reasoning block before the agent names its activity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _de(
          const Scaffold(body: ReasoningBlock(text: 'because', active: true)),
        ),
      );
      expect(find.textContaining('Denkt nach…'), findsOneWidget);
      expect(find.textContaining('Thinking…'), findsNothing);
    });

    testWidgets('the session status when the server reports no status', (
      tester,
    ) async {
      final state = ChatSessionState()
        ..control = const SessionControlSnapshot(
          revision: 'r',
          goal: {'turns_used': 1},
          loop: {'turns_used': 1},
          heartbeat: {'fire_count': 1},
        );
      await tester.pumpWidget(
        _de(Scaffold(body: SessionStatusCard(state: state))),
      );
      expect(find.textContaining('Goal: Nicht verfügbar'), findsOneWidget);
      expect(find.textContaining('Loop: Nicht verfügbar'), findsOneWidget);
      expect(find.textContaining('Heartbeat: Nicht verfügbar'), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsNothing);
    });

    testWidgets('the account tile with no server', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthController(),
          child: _de(
            const Scaffold(body: SizedBox(width: 300, child: AccountFooter())),
          ),
        ),
      );
      expect(find.text('Nicht verbunden'), findsOneWidget);
      expect(find.text('Not connected'), findsNothing);
    });

    testWidgets('the Mac account footer with no server', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthController(),
          child: _de(
            const Scaffold(body: SizedBox(width: 300, child: AccountFooter())),
            platform: TargetPlatform.macOS,
          ),
        ),
      );
      expect(find.byType(MacAccountFooter), findsOneWidget);
      expect(find.text('Nicht verbunden'), findsOneWidget);
      expect(find.text('Not connected'), findsNothing);
    });
  });

  group('profiles, quick panel and connection', () {
    testWidgets('the Mac profile switcher before the profile is known', (
      tester,
    ) async {
      await tester.pumpWidget(
        _de(
          Scaffold(
            body: MacProfileSwitcher(
              profiles: const [],
              current: null,
              onSwitch: (_) {},
              onNewProfile: () {},
              onManage: () {},
            ),
          ),
          platform: TargetPlatform.macOS,
        ),
      );
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('the quick panel before the first send', (tester) async {
      await tester.pumpWidget(
        _de(const Scaffold(body: QuickPanelView(child: SizedBox()))),
      );
      expect(find.text('Hermes fragen'), findsOneWidget);
      expect(find.text('Ask Hermes'), findsNothing);
    });

    testWidgets('the connection page when the server reports no version', (
      tester,
    ) async {
      await tester.pumpWidget(
        _de(
          _scaffold(
            ConnectionSummary(
              serverUrl: 'https://hermes.example.com',
              status: HermesStatus(
                authRequired: false,
                authProviders: const [],
                authFlows: const [],
              ),
            ),
          ),
        ),
      );
      expect(find.text('unbekannt'), findsOneWidget);
      expect(find.text('unknown'), findsNothing);
    });
  });

  group('schedules', () {
    late FakeHermesServer server;
    late ValueNotifier<bool> activity;
    late SchedulesController controller;

    setUp(() {
      activity = ValueNotifier(true);
      server = FakeHermesServer()
        ..on('GET', '/api/profiles/active', {'active': 'work'})
        ..on('GET', '/api/cron/jobs', [cronJobRow()])
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []})
        ..on('POST', '/api/cron/jobs/job1/trigger', {'ok': true});
      controller = SchedulesController(
        activity: activity,
        repository: HermesCronRepository(server.client().raw),
        profiles: HermesProfilesRepository(server.client().raw),
      );
    });

    tearDown(() {
      controller.dispose();
      activity.dispose();
    });

    testWidgets('Run now on the detail says it was requested', (tester) async {
      await tester.runAsync(controller.refresh);
      await tester.pumpWidget(
        _de(
          Scaffold(
            body: ScheduleDetail(
              controller: controller,
              job: controller.jobs.single,
              onOpenRun: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run now'));
      await tester.pumpAndSettle();
      expect(find.text('Ausführung angefordert'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Run requested'), findsNothing);
    });

    testWidgets('Run now on a row says it was requested', (tester) async {
      await tester.runAsync(controller.refresh);
      late List<RowAction> actions;
      await tester.pumpWidget(
        _de(
          Scaffold(
            body: Builder(
              builder: (context) {
                actions = scheduleRowActions(
                  context,
                  controller,
                  controller.jobs.single,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      actions.first.onPressed();
      await tester.pumpAndSettle();
      expect(find.text('Ausführung angefordert'), findsOneWidget);
      expect(find.text('Run requested'), findsNothing);
    });
  });

  group('skills and widgets', () {
    testWidgets('a failed skill job with no error text', (tester) async {
      final job = SkillJob(
        title: 'Updating',
        start: () async => const StartedJob(name: 'fixture'),
        status: (_) async => const JobStatus(running: false, exitCode: 1),
      );
      await job.run();
      addTearDown(job.dispose);
      await tester.pumpWidget(_de(Scaffold(body: SkillJobSheet(job: job))));
      expect(find.text('Es ist fehlgeschlagen.'), findsOneWidget);
      expect(find.text('It failed.'), findsNothing);
    });

    testWidgets('the copy button of a code block, before and after a tap', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _de(
          _scaffold(
            const HermesCodeBlock(
              name: 'dart',
              codes: 'print(1);\n',
              style: CodeBlockStyle(),
            ),
          ),
        ),
      );
      expect(find.tooltip('Code kopieren'), findsOneWidget);
      expect(find.tooltip('Copy code'), findsNothing);
      await tester.tap(find.tooltip('Code kopieren'));
      await tester.pump();
      expect(find.tooltip('Kopiert!'), findsOneWidget);
      expect(find.tooltip('Copied!'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('mcp, messaging and plugins', () {
    testWidgets('the MCP sign-in when Hermes declines with no reason', (
      tester,
    ) async {
      final server = FakeHermesServer();
      final controller = _DecliningController(
        HermesMcpRepository(server.client().raw),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _de(
          McpSignInScreen(
            controller: controller,
            server: const HermesMcpServer(
              name: 'asana',
              transport: McpTransport.remote,
              url: 'https://mcp.asana.com/sse',
              auth: 'oauth',
            ),
            flow: const HermesMcpFlow(
              flowId: 'flow-1',
              status: McpFlowStatus.error,
              error: 'Authorization failed',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text('Anmeldung bei asana konnte nicht gestartet werden'),
        findsOneWidget,
      );
      expect(find.textContaining('Could not start signing in'), findsNothing);
    });

    testWidgets('a messaging field that is set but whose value is hidden', (
      tester,
    ) async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/messaging/platforms',
          platformListBody([
            platformRow(
              id: 'discord',
              name: 'Discord',
              envVars: [
                {
                  ...envVarRow(
                    key: 'DISCORD_ALLOWED_USERS',
                    prompt: 'Allowed Discord users',
                    isSet: true,
                  ),
                  'redacted_value': null,
                },
              ],
            ),
          ]),
        );
      await tester.pumpWidget(
        _de(
          MessagingScreen(
            repository: HermesMessagingRepository(server.client().raw),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MessagingPlatformRow, 'Discord'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Gesetzt (verborgen). Leer lassen'),
        findsOneWidget,
      );
      expect(find.textContaining('Leave blank to keep it'), findsNothing);
    });

    testWidgets('saving provider settings fails without a reason', (
      tester,
    ) async {
      const hubPath = '/api/dashboard/plugins/hub';
      const savePath = '/api/dashboard/plugin-providers';
      final server = FakeHermesServer()
        ..on(
          'GET',
          hubPath,
          providersHub(
            memory: 'honcho',
            memoryOptions: [
              memoryOption('honcho', description: 'Honcho memory'),
              memoryOption('holographic'),
            ],
            engine: 'compressor',
            engines: [
              {'name': 'compressor', 'description': 'Default engine'},
            ],
          ),
        )
        ..onRequest(
          'PUT',
          savePath,
          (_) => throw const SocketException('no route to host'),
        );
      tester.view
        ..physicalSize = const Size(400, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _de(
          PluginsScreen(
            repository: HermesPluginManagerRepository(server.client().raw),
            events: (name, [attributes = const {}]) {},
            initialTab: PluginsTab.providers,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-holographic')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('providers-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Anbieter-Einstellungen konnten nicht gespeichert werden'),
        findsOneWidget,
      );
      expect(find.text('Could not save provider settings'), findsNothing);
    });
  });
}
