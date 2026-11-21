import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/app_inactive_watcher.dart';

void main() {
  testWidgets('is away while the app is inactive, hidden or paused', (
    tester,
  ) async {
    final watcher = AppInactiveWatcher(appliesHere: true);
    addTearDown(watcher.dispose);
    var changes = 0;
    watcher.addListener(() => changes++);

    expect(watcher.away, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(watcher.away, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(watcher.away, isTrue);
    expect(changes, 1, reason: 'only a change is announced');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(watcher.away, isFalse);
    expect(changes, 2);
  });

  testWidgets('is never away where no snapshot is taken', (tester) async {
    final watcher = AppInactiveWatcher(appliesHere: false);
    addTearDown(watcher.dispose);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(watcher.away, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('stops listening when disposed', (tester) async {
    final watcher = AppInactiveWatcher(appliesHere: true)..dispose();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(watcher.away, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
