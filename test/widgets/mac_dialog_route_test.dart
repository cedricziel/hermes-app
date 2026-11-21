import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';

import '../support/fake_hermes_server.dart';

/// Dialogs the app opens through `showAppDialog` close on a barrier click on
/// macOS and stay open on iOS, like the rest of the app's dialogs.
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
  };

  for (final entry in opens.entries) {
    for (final (platform, closes) in [
      (TargetPlatform.macOS, true),
      (TargetPlatform.iOS, false),
    ]) {
      testWidgets('${entry.key} on ${platform.name}: a barrier click '
          '${closes ? 'closes' : 'keeps'} it', (tester) async {
        await pump(tester, platform);
        final (marker, open) = entry.value;
        unawaited(open());
        await tester.pumpAndSettle();
        expect(find.text(marker), findsWidgets);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.text(marker), closes ? findsNothing : findsWidgets);
      });
    }
  }
}
