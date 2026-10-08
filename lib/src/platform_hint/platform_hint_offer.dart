import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/safe_notifier.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../telemetry/breadcrumbs.dart';
import 'platform_hint_repository.dart';

/// One start's offer to add the app's hint to the server's profiles: which
/// profiles need it, the writes in flight and the ones that failed. The
/// user's "don't ask again" is kept per server.
class PlatformHintOffer extends ChangeNotifier with SafeNotifier {
  PlatformHintOffer({
    required this.repository,
    required this.profileList,
    required String server,
    this.breadcrumbs = Breadcrumbs.none,
    SharedPreferencesAsync? prefs,
  }) : _declinedKey = 'platform-hint.declined.$server',
       _prefs = prefs ?? SharedPreferencesAsync();

  final PlatformHintRepository repository;
  final HermesProfilesRepository profileList;
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

  /// The profiles saved so far.
  final saved = <String>{};

  bool _answered = false;

  /// Finds the profiles that need the hint. True when the user should be
  /// asked: some profile needs it and they have not turned the question off
  /// for this server. Never throws.
  Future<bool> check() async {
    try {
      if (await _prefs.getBool(_declinedKey) ?? false) return false;
      final names = [for (final p in await profileList.list()) p.name];
      final states = await Future.wait(names.map(repository.state));
      final needed = {
        for (final (i, name) in names.indexed)
          if (states[i]
              case PlatformHintState.missing || PlatformHintState.outdated)
            name: states[i],
      };
      profiles = needed.keys.toList();
      selected = needed.keys.toSet();
      update =
          needed.isNotEmpty &&
          needed.values.every((s) => s == PlatformHintState.outdated);
      return needed.isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Ticks or unticks [profile].
  void toggle(String profile, bool on) {
    selected = on ? {...selected, profile} : ({...selected}..remove(profile));
    notifyListeners();
  }

  /// Notes that the prompt is on screen.
  void offered() => breadcrumbs('platform_hint.offered', {
    'profiles': profiles.length,
    'update': update,
  });

  /// Writes the hint to each ticked profile not saved yet, all at once.
  /// True when every one is saved; otherwise [failed] names the rest and a
  /// second call retries only those.
  Future<bool> add() async {
    if (busy) return false;
    busy = true;
    failed = const [];
    notifyListeners();
    final pending = [
      for (final p in profiles)
        if (selected.contains(p) && !saved.contains(p)) p,
    ];
    final results = await Future.wait(
      pending.map(
        (p) => repository.write(p).then((_) => true, onError: (_) => false),
      ),
    );
    final missed = [
      for (final (i, p) in pending.indexed)
        if (!results[i]) p,
    ];
    saved.addAll(pending.where((p) => !missed.contains(p)));
    busy = false;
    failed = missed;
    notifyListeners();
    if (missed.isEmpty) {
      _answer('added');
    } else {
      breadcrumbs('platform_hint.answered', {'outcome': 'failed'});
    }
    return missed.isEmpty;
  }

  /// The user put it off, or closed the prompt without answering; the next
  /// start asks again. Does nothing once the prompt was answered.
  void later() => _answer('later');

  /// The user turned the question off for this server.
  Future<void> never() async {
    _answer('never');
    try {
      await _prefs.setBool(_declinedKey, true);
    } on Object {
      // Without storage the question simply comes back next start.
    }
  }

  void _answer(String outcome) {
    if (_answered) return;
    _answered = true;
    breadcrumbs('platform_hint.answered', {'outcome': outcome});
  }
}
