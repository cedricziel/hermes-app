import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kanbanInspectorShownKey = 'hermes.kanban.inspector_shown';

/// Which task the Mac board's inspector shows, and whether the panel is
/// shown at all. Whether it is shown outlives the app; the task does not.
class KanbanInspector extends ChangeNotifier {
  KanbanInspector({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  bool _shown = true;
  bool _touched = false;
  String? _taskId;

  bool get shown => _shown;
  String? get taskId => _taskId;

  Future<void> load() async {
    final shown = await _prefs.getBool(kanbanInspectorShownKey);
    if (_touched || shown == null || shown == _shown) return;
    _shown = shown;
    notifyListeners();
  }

  void open(String taskId) {
    _taskId = taskId;
    _show(true);
  }

  void toggle() => _show(!_shown);

  void close() {
    if (_taskId == null) return;
    _taskId = null;
    notifyListeners();
  }

  void _show(bool shown) {
    _touched = true;
    final changed = shown != _shown;
    _shown = shown;
    notifyListeners();
    if (changed) _prefs.setBool(kanbanInspectorShownKey, shown);
  }
}
