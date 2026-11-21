import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/plugins/install_report.dart';
import 'package:hermes_app/src/plugins/plugin_install_result.dart';

import '../support/fake_hermes_server.dart';

/// Dialogs the app opens through `showAppDialog` get the macOS route: a barrier
/// click closes them, except the two with a text field, which Esc and Cancel
/// close. iOS keeps its barrier inert; Android its click-to-close.
void main() {
  late BuildContext context;

  Future<void> pump(WidgetTester tester, TargetPlatform platform) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

  final opens = <String, (String, Future<void> Function())>{
    'thread rename': (
      'Plan the release',
      () => runThreadAction(
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
    'kanban text': (
      'Rename board',
      () => askKanbanText(context, title: 'Rename board'),
    ),
    'plugin install report': (
      'Set these on the server',
      () => reportInstall(
        context,
        const PluginInstallResult(ok: true, missingEnv: ['API_KEY']),
      ),
    ),
  };

  Future<void> open(WidgetTester tester, String name) async {
    unawaited(opens[name]!.$2());
    await tester.pumpAndSettle();
    expect(find.text(opens[name]!.$1), findsWidgets);
  }

  Future<void> clickBarrier(WidgetTester tester) async {
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  }

  // name, platform, whether a barrier click closes it.
  const cases = [
    ('thread rename', TargetPlatform.macOS, false),
    ('thread rename', TargetPlatform.iOS, false),
    ('thread rename', TargetPlatform.android, true),
    ('kanban text', TargetPlatform.macOS, false),
    ('kanban text', TargetPlatform.iOS, false),
    ('kanban text', TargetPlatform.android, true),
    ('plugin install report', TargetPlatform.macOS, true),
    ('plugin install report', TargetPlatform.iOS, false),
  ];
  for (final (name, platform, closes) in cases) {
    testWidgets('$name on ${platform.name}: a barrier click '
        '${closes ? 'closes' : 'keeps'} it', (tester) async {
      await pump(tester, platform);
      await open(tester, name);
      await clickBarrier(tester);
      expect(find.text(opens[name]!.$1), closes ? findsNothing : findsWidgets);
    });
  }

  for (final name in ['thread rename', 'kanban text']) {
    testWidgets('$name on macOS: Esc closes it', (tester) async {
      await pump(tester, TargetPlatform.macOS);
      await open(tester, name);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(opens[name]!.$1), findsNothing);
    });
  }
}
