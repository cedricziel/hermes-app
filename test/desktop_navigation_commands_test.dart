import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_commands.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_history.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';

void main() {
  testWidgets('mouse buttons use history while scroll stays scroll', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final registry = MacCommandRegistry();
    const target = WorkersNavigationTarget(boardSlug: 'ops');
    Route<void> workers() => MaterialPageRoute<void>(
      settings: const RouteSettings(arguments: target),
      builder: (_) => const Scaffold(body: Text('workers')),
    );
    final history = DesktopNavigationHistory(
      canNavigate: () => true,
      resolve: (_) async => workers(),
    );
    addTearDown(registry.dispose);
    addTearDown(history.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [history],
        builder: (_, child) => MacCommandScope.root(
          registry: registry,
          child: DesktopNavigationCommands(history: history, child: child!),
        ),
        home: const Scaffold(body: Text('root')),
      ),
    );
    unawaited(key.currentState!.push(workers()));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.down(const Offset(100, 100));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(registry.handlerFor(MacCommand.forward)!.enabled, isTrue);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(100, 100),
        scrollDelta: Offset(300, 0),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    final forward = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kForwardMouseButton,
    );
    await forward.down(const Offset(100, 100));
    await forward.up();
    await tester.pumpAndSettle();
    expect(find.text('workers'), findsOneWidget);
    expect(history.canGoForward, isFalse);
  });
  testWidgets(
    'desktop settings toolbar Back records Forward',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final history = DesktopNavigationHistory(
        canNavigate: () => true,
        resolve: (_) async => null,
      );
      addTearDown(history.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [history],
          builder: (_, child) =>
              DesktopNavigationHistoryScope(history: history, child: child!),
          home: const Scaffold(body: Text('root')),
        ),
      );
      unawaited(
        key.currentState!.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              arguments: WorkersNavigationTarget(boardSlug: 'ops'),
            ),
            builder: (_) =>
                const SettingsScaffold(title: 'Workers', body: Text('workers')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(history.canGoForward, isTrue);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );
  testWidgets(
    'mobile settings toolbar keeps platform dismissal',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      final history = DesktopNavigationHistory(
        canNavigate: () => true,
        resolve: (_) async => null,
      );
      addTearDown(history.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [history],
          builder: (_, child) =>
              DesktopNavigationHistoryScope(history: history, child: child!),
          home: const Scaffold(body: Text('root')),
        ),
      );
      unawaited(
        key.currentState!.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              arguments: WorkersNavigationTarget(boardSlug: 'ops'),
            ),
            builder: (_) =>
                const SettingsScaffold(title: 'Workers', body: Text('workers')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AdaptiveBackButton));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(history.canGoForward, isFalse);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
