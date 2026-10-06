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
    if (profile == _current) return;
    _current = profile;
    notifyListeners();
  }

  /// Makes [name] the active profile and moves the chat to it. Returns false
  /// when the dashboard refused.
  Future<bool> switchTo(String name) async {
    try {
      await repository.setActive(name);
    } on Object {
      return false;
    }
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
