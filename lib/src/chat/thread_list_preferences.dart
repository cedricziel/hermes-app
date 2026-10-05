import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/safe_notifier.dart';

enum ThreadGrouping { recent, folder }

class ThreadListPreferences extends ChangeNotifier with SafeNotifier {
  ThreadListPreferences({
    required String platform,
    SharedPreferencesAsync? prefs,
  }) : _key = 'chat.thread-list.$platform',
       _prefs = prefs ?? SharedPreferencesAsync();

  final String _key;
  final SharedPreferencesAsync _prefs;
  ThreadGrouping grouping = ThreadGrouping.recent;
  final _folded = <String>{};
  bool _touched = false;

  bool isCollapsed(String id) => _folded.contains(id);

  Future<void> load() async {
    try {
      final mode = await _prefs.getString('$_key.grouping');
      final folded = await _prefs.getStringList('$_key.folded');
      if (disposed || _touched) return;
      grouping = mode == 'folder'
          ? ThreadGrouping.folder
          : ThreadGrouping.recent;
      _folded.addAll(folded ?? []);
      notifyListeners();
    } on Object {
      // Preferences optional; chats remain usable without storage.
    }
  }

  void choose(ThreadGrouping value) {
    _touched = true;
    grouping = value;
    notifyListeners();
    _save();
  }

  void toggle(String id) {
    _touched = true;
    if (!_folded.remove(id)) _folded.add(id);
    notifyListeners();
    _save();
  }

  Future<void> _writes = Future.value();

  void _save() {
    final mode = grouping.name;
    final folded = _folded.toList();
    _writes = _writes.then((_) async {
      try {
        await _prefs.setString('$_key.grouping', mode);
        await _prefs.setStringList('$_key.folded', folded);
      } on Object {
        // Preferences optional; chats remain usable without storage.
      }
    });
  }
}
