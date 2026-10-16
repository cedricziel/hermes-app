import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import 'hermes_profiles_repository.dart';

/// The server's profiles and the one the chat works in, shared by the Mac
/// sidebar's profile switcher, the Profiles page and the chat.
///
/// The chat reports the profile it shows through [showing] and carries out a
/// switch through the handler it [attach]es.
class ChatProfiles extends ChangeNotifier with SafeNotifier {
  ChatProfiles(this.repository);

  final HermesProfilesRepository repository;

  List<HermesProfile> _profiles = const [];
  List<HermesProfile> get profiles => _profiles;

  bool _failed = false;

  /// Whether the last listing failed.
  bool get failed => _failed;

  String? _current;

  /// The profile the chat shows; null until it says.
  String? get current => _current;

  ValueChanged<String>? _onSwitch;
  int _selectionGeneration = 0;
  int? _pendingSelection;
  String? _reportedProfile;

  /// Lets the chat follow a switch made here; null detaches it.
  void attach(ValueChanged<String>? onSwitch) => _onSwitch = onSwitch;

  Future<void> load() async {
    try {
      _profiles = await repository.list();
      _failed = false;
    } on Object {
      _failed = true;
    }
    notifyListeners();
  }

  void showing(String? profile) {
    _reportedProfile = profile;
    if (_pendingSelection != null || profile == _current) return;
    _current = profile;
    notifyListeners();
  }

  /// Selects [name] for chatting without changing the server default. Returns
  /// false if the profile list cannot be read or [name] is no longer available.
  Future<bool> switchTo(String name) async {
    final generation = ++_selectionGeneration;
    _pendingSelection = null;
    if (name == _current) return true;
    _pendingSelection = generation;
    List<HermesProfile>? available;
    try {
      available = await repository.list();
    } on Object {
      available = null;
    }
    if (disposed || generation != _selectionGeneration) return false;
    _pendingSelection = null;
    if (available == null ||
        !available.any((profile) => profile.name == name)) {
      showing(_reportedProfile);
      return false;
    }
    _profiles = available;
    _failed = false;
    _current = name;
    notifyListeners();
    _onSwitch?.call(name);
    return true;
  }

  /// Creates [name] and lists the profiles again. Throws what the dashboard
  /// answered when it refuses.
  Future<void> create(String name, {String? description}) async {
    await repository.create(name, description: description);
    await load();
  }
}
