import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_dialog.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/connect_failure.dart';
import 'package:hermes_app/src/chat/attachments/attachment_surface.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/plugins/sheet_host.dart';
import 'package:provider/provider.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/chat/widgets/image_viewer.dart';
import 'package:hermes_app/src/chat/widgets/input_card_frame.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/notifications_dialog.dart';
import 'package:hermes_app/src/screens/home_screen.dart';
import 'package:hermes_app/src/screens/login_screen.dart';
import 'package:hermes_app/src/screens/server_setup_screen.dart';
import 'package:hermes_app/src/settings/appearance_dialog.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/widgets/content_column.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_device_authenticator.dart';
import '../test/support/fake_hermes_server.dart';
import '../test/support/fake_attachment_source.dart';
import 'catalog_auth.dart';
import 'fixtures.dart';
import 'frame.dart';
import 'host.dart';
import 'kanban_screen_use_cases.dart';

final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Widget _dialog(Future<void> Function(BuildContext context) open) =>
    openOnShow(open);

WidgetbookUseCase _screen(
  String name,
  CatalogAuth Function() auth,
  Widget Function() screen,
) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<CatalogAuth>(
    create: auth,
    dispose: (auth) => auth.dispose(),
    builder: (_, auth) => withAppProviders(auth, screen()),
  ),
);

WidgetbookUseCase _app(String name, CatalogAuth Function() auth) =>
    _screen(name, auth, () => const HermesApp());

/// A chat with threads the dashboard already holds.
FakeHermesServer _chatServer() {
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  return kanbanServer()
    ..on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(
          id: 's1',
          title: 'Plan the release',
          preview: 'The changelog is ready',
          startedAt: now - 3600,
          pinned: true,
        ),
        sessionRow(
          id: 's2',
          title: 'Fix the flaky login test',
          startedAt: now - 86400,
        ),
      ]),
    )
    ..on(
      'GET',
      '/api/sessions/s1/messages',
      messageListBody('s1', [
        messageRow(id: 1, role: 'user', content: 'Prepare the release notes'),
        messageRow(
          id: 2,
          role: 'assistant',
          content: 'The changelog is ready for review.',
        ),
      ]),
    );
}

WidgetbookNode appNode() => WidgetbookFolder(
  name: 'App',
  children: [
    WidgetbookComponent(
      name: 'HermesApp',
      useCases: [
        _app('Connecting on launch', CatalogAuth.new),
        _app(
          'Splash',
          () => CatalogAuth(fixedState: HermesConnectionState.initializing),
        ),
        _app(
          'Server setup',
          () => CatalogAuth(fixedState: HermesConnectionState.needsServerUrl),
        ),
        _app(
          'Sign in',
          () => CatalogAuth(
            fixedState: HermesConnectionState.needsLogin,
            gated: true,
            signInProviders: const [ssoProvider],
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ServerSetupScreen',
      useCases: [
        _screen(
          'Empty',
          () => CatalogAuth(fixedState: HermesConnectionState.needsServerUrl),
          () => const ServerSetupScreen(),
        ),
        _screen(
          'Connecting',
          () => CatalogAuth(fixedState: HermesConnectionState.connecting),
          () => const ServerSetupScreen(),
        ),
        _screen(
          'Unreachable, VPN hint',
          () => CatalogAuth(
            fixedState: HermesConnectionState.connectionError,
            message: 'Could not reach the server.',
            failure: const ConnectFailure(
              kind: ConnectFailureKind.timeout,
              hostKind: HostKind.tailnet,
              retryable: true,
            ),
          ),
          () => const ServerSetupScreen(),
        ),
        _screen(
          'Invalid address',
          () => CatalogAuth(
            fixedState: HermesConnectionState.connectionError,
            message: 'Enter a valid http(s) URL, e.g. http://192.168.1.20:9119',
          ),
          () => const ServerSetupScreen(),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'LoginScreen',
      useCases: [
        _screen(
          'Provider',
          () => CatalogAuth(
            fixedState: HermesConnectionState.needsLogin,
            gated: true,
            signInProviders: const [ssoProvider],
          ),
          () => const LoginScreen(),
        ),
        _screen(
          'Signing in',
          () => CatalogAuth(
            fixedState: HermesConnectionState.signingIn,
            gated: true,
            signInProviders: const [ssoProvider],
          ),
          () => const LoginScreen(),
        ),
        _screen(
          'Sign-in failed',
          () => CatalogAuth(
            fixedState: HermesConnectionState.needsLogin,
            gated: true,
            message: 'Sign-in was cancelled.',
            signInProviders: const [ssoProvider],
          ),
          () => const LoginScreen(),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'HomeScreen',
      useCases: [
        _screen(
          'Status',
          () => CatalogAuth(
            server: FakeHermesServer()
              ..on('GET', '/api/status', {
                'auth_required': true,
                'version': '0.20.0',
                'auth_providers': ['oidc'],
                'auth_flows': ['native_pkce'],
              }),
            gated: true,
          ),
          () => const HomeScreen(),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'AppShell',
      useCases: [
        _screen(
          'Chat with Kanban and Schedules',
          () => CatalogAuth(server: _chatServer(), gated: true),
          () => const AppShell(),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatScreen',
      useCases: [
        _screen(
          'Sample conversation',
          () => CatalogAuth(gated: true),
          () => const ChatScreen(),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ThreadSidebar',
      useCases: [
        _screen(
          'Threads',
          () => CatalogAuth(gated: true),
          () => fill(
            ThreadSidebar(
              threads: threads,
              selectedId: 'thread-1',
              onSelect: (_) {},
              onNewThread: () {},
              onOpenProfiles: () {},
              onOpenBots: () {},
              onOpenSkills: () {},
              onOpenPlugins: () {},
              onOpenMcp: () {},
            ),
            width: 300,
          ),
        ),
        _screen(
          'No threads',
          () => CatalogAuth(),
          () => fill(
            ThreadSidebar(
              threads: const [],
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
            ),
            width: 300,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'AppLockGate',
      useCases: [
        for (final (name, locked) in [('Unlocked', false), ('Locked', true)])
          WidgetbookUseCase(
            name: name,
            builder: (_) => Hosted<AppLockController>(
              create: () async {
                final lock = AppLockController(
                  authenticator: FakeDeviceAuthenticator(succeeds: false),
                );
                await lock.load();
                if (locked) await lock.setEnabled(true);
                return lock;
              },
              dispose: (lock) => lock.dispose(),
              builder: (_, lock) => withAppProviders(
                CatalogAuth(),
                const AppLockGate(child: Center(child: Text('Your chats'))),
                lock: lock,
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'Dialogs',
      useCases: [
        WidgetbookUseCase(
          name: 'Appearance',
          builder: (_) =>
              withAppProviders(CatalogAuth(), _dialog(showAppearanceDialog)),
        ),
        WidgetbookUseCase(
          name: 'Notifications',
          builder: (_) =>
              withAppProviders(CatalogAuth(), _dialog(showNotificationsDialog)),
        ),
        WidgetbookUseCase(
          name: 'App lock',
          builder: (_) =>
              withAppProviders(CatalogAuth(), _dialog(showAppLockDialog)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'InputCardFrame',
      useCases: [
        WidgetbookUseCase(
          name: 'Frame and notes',
          builder: (_) => frame(
            const InputCardFrame(
              icon: Icons.help_outline,
              title: 'Hermes has a question',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Which environment should I deploy to?'),
                  InputCardNote('You answered: Staging'),
                  InputCardNote('Could not send the answer', error: true),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ContentColumn',
      useCases: [
        WidgetbookUseCase(
          name: 'Wide window',
          builder: (_) => ContentColumn(
            child: ListView(
              children: [
                for (var i = 1; i <= 5; i++)
                  ListTile(title: Text('Row $i, kept to a readable width')),
              ],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ImageViewerPage',
      useCases: [
        WidgetbookUseCase(
          name: 'With save',
          builder: (_) => ImageViewerPage(
            image: MemoryImage(_pixel),
            name: 'chart.png',
            onSave: () async => true,
          ),
        ),
        WidgetbookUseCase(
          name: 'View only',
          builder: (_) =>
              ImageViewerPage(image: MemoryImage(_pixel), name: 'chart.png'),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'AttachmentSurface',
      useCases: [
        for (final (name, drops) in [
          ('Attach menu', false),
          ('With drop and paste', true),
        ])
          WidgetbookUseCase(
            name: name,
            builder: (_) => AttachmentSurface(
              source: FakeAttachmentSource(acceptsDropAndPaste: drops),
              onAdd: (_) {},
              builder: (context, openMenu) => Scaffold(
                body: const Center(child: Text('Drop a file on the chat')),
                floatingActionButton: FloatingActionButton(
                  onPressed: openMenu,
                  child: const Icon(Icons.attach_file),
                ),
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'AttachmentThumbnail',
      useCases: [
        WidgetbookUseCase(
          name: 'Image in the message',
          builder: (_) => Provider<MediaStore?>.value(
            value: null,
            child: frame(
              AttachmentThumbnail(
                attachment: ChatAttachment(
                  name: 'chart.png',
                  kind: AttachmentKind.image,
                  bytes: _pixel,
                ),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Cannot be drawn',
          builder: (_) => Provider<MediaStore?>.value(
            value: null,
            child: frame(
              const AttachmentThumbnail(
                attachment: ChatAttachment(
                  name: 'chart.png',
                  kind: AttachmentKind.image,
                  remotePath: 'attachments/chart.png',
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SheetHost',
      useCases: [
        WidgetbookUseCase(
          name: 'Details sheet',
          builder: (_) => Hosted<ValueNotifier<bool>>(
            create: () => ValueNotifier(false),
            dispose: (gone) => gone.dispose(),
            builder: (_, gone) => Scaffold(
              body: SheetHost(
                listenable: gone,
                isGone: () => gone.value,
                builder: (_) => const ListTile(
                  title: Text('netbox'),
                  subtitle: Text('Shown while the plugin exists'),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'FlyerMaterialScope',
      useCases: [
        WidgetbookUseCase(
          name: 'Material inside the chat',
          builder: (_) => frame(
            const FlyerMaterialScope(
              child: Card(child: ListTile(title: Text('A Material tile'))),
            ),
          ),
        ),
      ],
    ),
  ],
);
