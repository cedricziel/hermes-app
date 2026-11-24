import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/navigation/widgets/keyboard_shortcuts_view.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/memory_token_store.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// The whole [HermesApp] on Linux: the wiring from `app.dart`'s
/// `ModalRouteObserver` through `MacMenuBar` to `DesktopCommandShortcuts`,
/// which the widget tests of the pieces do not cover. F1 is the root command
/// `MacMenuBar` registers itself, so no signed-in screen is needed.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('F1 opens nothing behind a dialog, and opens it after', (
    tester,
  ) async {
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      login: (baseUrl, {provider, httpClient, cancelled}) =>
          Completer<Never>().future,
    );
    await pumpWorkflowApp(
      tester,
      ScreenshotRecorder('desktop-chords-in-app'),
      auth: auth,
      platform: TargetPlatform.linux,
      size: desktopSize,
    );
    await tester.runAsync(auth.bootstrap);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('Sure?')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sure?'), findsOneWidget);

    // With the focus inside the dialog, its route says so; with the focus
    // back on the screen behind it (a click there, a window focus change), only
    // the app's observer does.
    for (final focusBehind in [false, true]) {
      if (focusBehind) {
        Focus.of(context, scopeOk: true).requestFocus();
        await tester.pump();
        expect(
          ModalRoute.of(FocusManager.instance.primaryFocus!.context!),
          isNot(isA<PopupRoute<void>>()),
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardShortcutsPage), findsNothing);
    }

    Navigator.of(context).pop();
    await dialog;
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.byType(KeyboardShortcutsPage), findsOneWidget);

    await letSocketsIdle(tester);
  });
}
