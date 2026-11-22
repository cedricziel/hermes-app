import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/settings/appearance_dialog.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

/// Every dialog that binds Esc itself (a `DismissIntent` action, because its
/// barrier is inert or its route has none) must still close on Esc after a
/// pointer click took focus out of its field. Built through the real show
/// functions, on the platforms where the binding is active, with Android as
/// the control (the route's own Esc).
void main() {
  late BuildContext context;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pump(WidgetTester tester, TargetPlatform platform) =>
      tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeController(),
          child: MaterialApp(
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHermesLightTheme().copyWith(platform: platform),
            home: Builder(
              builder: (c) {
                context = c;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

  // name, title text, whether it has a text field, how to open it.
  final dialogs = <(String, String, bool, Future<void> Function())>[
    (
      'thread rename',
      'Rename chat',
      true,
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
    (
      'kanban text',
      'Rename board',
      true,
      () => askKanbanText(context, title: 'Rename board'),
    ),
    ('appearance', 'Appearance', false, () => showAppearanceDialog(context)),
  ];

  // Platforms where each dialog binds Esc itself, and the control.
  const platformsOf = {
    'thread rename': [TargetPlatform.macOS, TargetPlatform.android],
    'kanban text': [TargetPlatform.macOS, TargetPlatform.android],
    'appearance': [TargetPlatform.iOS, TargetPlatform.android],
  };

  Future<void> click(WidgetTester tester, Offset at) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: at);
    await gesture.down(at);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
  }

  for (final (name, title, hasField, open) in dialogs) {
    for (final platform in platformsOf[name]!) {
      for (final target in const ['barrier', 'title']) {
        testWidgets('$name on ${platform.name}: a click on the $target, '
            'then Esc, closes it', (tester) async {
          await pump(tester, platform);
          unawaited(open());
          await tester.pumpAndSettle();
          expect(find.text(title), findsWidgets);
          if (hasField) {
            await tester.tap(find.byType(EditableText));
            await tester.enterText(find.byType(EditableText), 'draft');
            await tester.pump();
          }
          await click(
            tester,
            target == 'barrier'
                ? const Offset(4, 4)
                : tester.getCenter(find.text(title).first),
          );
          // A Material barrier click closes the dialog by itself: the control
          // has nothing left to test there.
          if (find.text(title).evaluate().isEmpty) return;
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.text(title), findsNothing);
          // The page under the dialog stays.
          expect(find.byType(Scaffold), findsOneWidget);
        });
      }
    }
  }

  for (final (name, _, _, open) in dialogs.where((d) => d.$3)) {
    testWidgets('$name on macOS: the field keeps the focus it autofocused', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.macOS);
      unawaited(open());
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(editable.widget.focusNode.hasPrimaryFocus, isTrue);
    });
  }
}
