import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/safe_notifier.dart';
import '../telemetry/breadcrumbs.dart';
import 'platform_hint_repository.dart';

/// One start's offer to add the app's hint to the server's profiles: which
/// profiles need it, the writes in flight and the ones that failed. The
/// user's "don't ask again" is kept per server.
class PlatformHintOffer extends ChangeNotifier with SafeNotifier {
  PlatformHintOffer({
    required this.repository,
    required String server,
    this.breadcrumbs = Breadcrumbs.none,
    SharedPreferencesAsync? prefs,
  }) : _declinedKey = 'platform-hint.declined.$server',
       _prefs = prefs ?? SharedPreferencesAsync();

  final PlatformHintRepository repository;
  final Breadcrumbs breadcrumbs;
  final String _declinedKey;
  final SharedPreferencesAsync _prefs;

  /// The profiles that need the hint.
  List<String> profiles = const [];

  /// Every one of [profiles] holds a text an earlier app wrote.
  bool update = false;

  /// The profiles the user left ticked; all of [profiles] at first.
  Set<String> selected = const {};

  bool busy = false;

  /// The profiles whose last write failed.
  List<String> failed = const [];

  final _done = <String>{};

  /// The profiles saved so far.
  Set<String> get saved => Set.unmodifiable(_done);

  /// Finds the profiles that need the hint. True when the user should be
  /// asked: some profile needs it and they have not turned the question off
  /// for this server. Never throws.
  Future<bool> check() async {
    try {
      if (await _prefs.getBool(_declinedKey) ?? false) return false;
      final names = await repository.profiles();
      final states = await Future.wait(names.map(repository.state));
      final needed = <String>[];
      var outdated = 0;
      for (final (i, name) in names.indexed) {
        switch (states[i]) {
          case PlatformHintState.missing:
            needed.add(name);
          case PlatformHintState.outdated:
            needed.add(name);
            outdated++;
          case _:
        }
      }
      profiles = needed;
      selected = needed.toSet();
      update = needed.isNotEmpty && outdated == needed.length;
      return needed.isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Ticks or unticks [profile].
  void toggle(String profile, bool on) {
    selected = {...selected}..remove(profile);
    if (on) selected.add(profile);
    notifyListeners();
  }

  /// Notes that the prompt is on screen.
  void offered() => breadcrumbs('platform_hint.offered', {
    'profiles': profiles.length,
    'update': update,
  });

  /// Writes the hint to each ticked profile not written yet. True when
  /// every one is saved; otherwise [failed] names the rest and a second call
  /// retries only those.
  Future<bool> add() async {
    if (busy) return false;
    busy = true;
    failed = const [];
    notifyListeners();
    final missed = <String>[];
    final pending = profiles.where(
      (p) => selected.contains(p) && !_done.contains(p),
    );
    for (final profile in pending.toList()) {
      try {
        await repository.write(profile);
        _done.add(profile);
      } on Object {
        missed.add(profile);
      }
    }
    busy = false;
    failed = missed;
    notifyListeners();
    _answered(missed.isEmpty ? 'added' : 'failed');
    return missed.isEmpty;
  }

  /// The user put it off; the next start asks again.
  void later() => _answered('later');

  /// The user turned the question off for this server.
  Future<void> never() async {
    _answered('never');
    try {
      await _prefs.setBool(_declinedKey, true);
    } on Object {
      // Without storage the question simply comes back next start.
    }
  }

  void _answered(String outcome) =>
      breadcrumbs('platform_hint.answered', {'outcome': outcome});
}
