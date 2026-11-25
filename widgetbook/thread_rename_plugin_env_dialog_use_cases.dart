import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_rename_dialog.dart';
import 'package:hermes_app/src/plugins/widgets/plugin_missing_env_dialog.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'frame.dart';
import 'host.dart';

/// The thread menu's rename dialog and the plugin install's missing-variables
/// dialog. Each is shown as the widget alone and through the opener the app
/// uses, so the route (barrier, Esc, motion) is the one that ships.
WidgetbookNode threadRenamePluginEnvDialogsNode() => WidgetbookFolder(
  name: 'Thread and plugin dialogs',
  children: [
    WidgetbookComponent(
      name: 'Thread rename',
      useCases: onEachPlatform(
        'Open',
        (_) => openOnShow(
          (context) => runThreadAction(
            context,
            ThreadAction.rename,
            thread: ChatThread(
              id: 's1',
              title: 'Plan the release',
              updatedAt: DateTime(2026, 1, 1),
              messages: const [],
            ),
            housekeeping: ThreadHousekeeping(
              repository: HermesChatRepository(FakeHermesServer().client().raw),
              threads: () => const [],
              profile: () => null,
              changed: () {},
              report: (_) {},
              removed: (_) {},
              history: (thread, {cancelled}) async => const [],
            ),
          ),
        ),
      ),
    ),
    WidgetbookComponent(
      name: 'ThreadRenameDialog',
      useCases: [
        ...onEachPlatform(
          'Empty, Save off',
          (_) => frame(const ThreadRenameDialog(initial: '')),
        ),
        ...onEachPlatform(
          'With a title',
          (_) => frame(const ThreadRenameDialog(initial: 'Plan the release')),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PluginMissingEnvDialog',
      useCases: [
        ...onEachPlatform(
          'One name',
          (_) => frame(const PluginMissingEnvDialog(missingEnv: ['API_KEY'])),
        ),
        ...onEachPlatform(
          'Several names',
          (_) => frame(
            const PluginMissingEnvDialog(
              missingEnv: ['BROWSER_PATH', 'BROWSER_PROFILE', 'BROWSER_TOKEN'],
            ),
          ),
        ),
      ],
    ),
  ],
);
