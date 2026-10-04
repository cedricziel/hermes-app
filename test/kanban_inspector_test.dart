import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_inspector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('starts shown with no task', () {
    final inspector = KanbanInspector();
    expect(inspector.shown, isTrue);
    expect(inspector.taskId, isNull);
  });

  test('opening a task shows it, also when hidden', () {
    final inspector = KanbanInspector()..toggle();
    expect(inspector.shown, isFalse);

    inspector.open('t1');

    expect(inspector.taskId, 't1');
    expect(inspector.shown, isTrue);
  });

  test('the toggle hides and shows the panel and keeps the task', () {
    final inspector = KanbanInspector()..open('t1');
    inspector.toggle();
    expect(inspector.shown, isFalse);
    expect(inspector.taskId, 't1');
    inspector.toggle();
    expect(inspector.shown, isTrue);
  });

  test('closing forgets the task', () {
    final inspector = KanbanInspector()..open('t1');
    inspector.close();
    expect(inspector.taskId, isNull);
  });

  test('remembers whether the panel is shown', () async {
    KanbanInspector().toggle();
    await pumpEventQueue();

    final next = KanbanInspector();
    await next.load();
    expect(next.shown, isFalse);
    expect(
      await SharedPreferencesAsync().getBool(kanbanInspectorShownKey),
      false,
    );
  });

  test('a change before the saved state loads wins', () async {
    await SharedPreferencesAsync().setBool(kanbanInspectorShownKey, false);
    final inspector = KanbanInspector();
    final loading = inspector.load();
    inspector.open('t1');
    await loading;
    expect(inspector.shown, isTrue);
  });
}
