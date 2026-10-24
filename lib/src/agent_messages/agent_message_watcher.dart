import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../background/background_alerts.dart' show kAlertLookupBudget;
import '../chat/hermes_chat_repository.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../schedules/schedule_alerts.dart' show kSummaryAbove;
import '../shell/app_presence.dart';
import '../telemetry/breadcrumbs.dart';
import 'agent_message_record.dart';
import 'find_messages.dart';
import 'message_alerts.dart';

/// The profiles that had a message from Hermes in the latest look that found
/// one, for the chat list to reload.
class AgentMessageFinds extends ChangeNotifier {
  Set<String> _profiles = const {};

  Set<String> get profiles => _profiles;

  /// Tells the listeners, even when [profiles] is what the last look found.
  void report(Set<String> profiles) {
    _profiles = profiles;
    notifyListeners();
  }
}

/// Looks at the chats every profile delivered to the app's inbox while the
/// app runs, and posts a notification for each one the user has not seen.
/// Hermes cannot push to the app, so this only sees what happens while the
/// app runs; a background run covers the time it is away.
class AgentMessageWatcher with WidgetsBindingObserver {
  AgentMessageWatcher({
    required this.chat,
    required this.profiles,
    required this.service,
    required this.settings,
    required this.finds,
    required this.appLock,
    this.shownProfile,
    AgentMessageRecord? record,
    String Function()? account,
    this.breadcrumbs = Breadcrumbs.none,
    this.events = noopAppEventLogger,
    this.interval = const Duration(minutes: 1),
    this.lookup = kAlertLookupBudget,
    TargetPlatform? platform,
    DateTime Function()? clock,
    this._paused = false,
  }) : _record = record ?? AgentMessageRecord(),
       _account = account ?? _noAccount,
       _platform = platform,
       _clock = clock ?? DateTime.now,
       _supported =
           !kIsWeb &&
           const {
             TargetPlatform.android,
             TargetPlatform.iOS,
             TargetPlatform.macOS,
           }.contains(platform ?? defaultTargetPlatform) {
    _foreground = AppPresence.foreground(
      WidgetsBinding.instance.lifecycleState,
      platform: platform,
    );
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_settingsChanged);
    _wasOn = _switchOn;
    _sync();
  }

  final HermesChatRepository chat;
  final HermesProfilesRepository profiles;
  final NotificationService service;
  final NotificationSettings settings;
  final AgentMessageFinds finds;

  /// Whether App Lock hides message texts. True until its setting has loaded.
  final bool Function() appLock;

  /// The profile the chat screen shows, which a message of another one names.
  final String? Function()? shownProfile;
  final Breadcrumbs breadcrumbs;
  final AppEventLogger events;
  final Duration interval;

  /// How long one profile's listing, or one message's text, may take.
  final Duration lookup;

  /// What the last look, here or in a background run, saw of each profile.
  /// Read at every look: a background run may have moved it.
  final AgentMessageRecord _record;
  final String Function() _account;
  final bool _supported;
  final DateTime Function() _clock;
  final TargetPlatform? _platform;

  static String _noAccount() => '';

  /// The removal of the record last asked for. A look waits for it, so that
  /// it never compares with a record that was about to go.
  Future<void> _forgetting = Future.value();

  late bool _foreground;
  bool _wasOn = false;
  bool _paused;
  bool _disposed = false;
  Future<void>? _inflight;
  int _epoch = 0;
  Timer? _timer;

  /// The user's choice, whether or not it has loaded yet: only a change of
  /// it starts from a new record, not the load itself.
  bool get _switchOn => settings.enabled && settings.agentMessages;

  bool get _enabled => settings.loaded && _switchOn;

  /// Suspends looks (signed out, session not usable) without forgetting the
  /// record.
  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    _invalidate();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = AppPresence.foreground(state, platform: _platform);
    // A step between two states that both run the app (macOS: resumed,
    // inactive, hidden) must not restart the timer and look again.
    if (foreground == _foreground) return;
    _foreground = foreground;
    _invalidate();
    _sync();
  }

  void _settingsChanged() {
    final on = _switchOn;
    // Turning it on starts from a new record, so messages from the time it
    // was off are not announced.
    if (on && !_wasOn) {
      _invalidate();
      _forgetRecord();
    }
    _wasOn = on;
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _paused || !_supported || !_foreground || !_enabled) {
      return;
    }
    _timer = Timer.periodic(interval, (_) => check());
    check();
  }

  /// One look at the inbox of every profile. A look asked for while another
  /// runs joins it.
  Future<void> check() {
    if (!_current(_epoch)) return Future.value();
    if (_inflight case final pending?) return pending;
    late final Future<void> pending;
    pending = _look(_epoch).whenComplete(() {
      if (identical(_inflight, pending)) _inflight = null;
    });
    return _inflight = pending;
  }

  bool _current(int epoch) =>
      !_disposed &&
      !_paused &&
      _supported &&
      _foreground &&
      _enabled &&
      epoch == _epoch;

  void _invalidate() {
    _epoch++;
    _inflight = null;
  }

  Future<void> _look(int epoch) async {
    Object? failure;
    try {
      final List<String> names;
      try {
        names = [for (final profile in await profiles.list()) profile.name];
        // A server that lists no profile at all is not readable either.
        if (names.isEmpty) throw StateError('no profiles');
      } on Object catch (error) {
        failure = error;
        return;
      }
      if (!_current(epoch)) return;
      await _forgetting;
      if (!_current(epoch)) return;
      final account = _account();
      final before = await _record.read(account);
      if (!_current(epoch)) return;

      // A listing that fails or takes too long stands for a profile that
      // could not be read.
      Future<DeliveryListing?> list(String name) async {
        try {
          return await listDeliveries(
            (offset) => chat.loadDeliveries(profile: name, offset: offset),
            since: before?[name],
          ).timeout(lookup);
        } on Object catch (error) {
          failure ??= error;
          return null;
        }
      }

      final listings = await Future.wait([
        for (final name in names) list(name),
      ]);
      if (!_current(epoch)) return;
      final found = findMessages(
        record: before,
        listings: {
          for (var i = 0; i < names.length; i++) names[i]: listings[i],
        },
        profileNames: names,
        now: _clock().millisecondsSinceEpoch / 1000,
      );
      // Before the alerts, so that a record that cannot be saved announces
      // nothing now rather than once more at every look.
      await _record.write(account, found.record);
      if (!_current(epoch) || found.messages.isEmpty) return;

      breadcrumbs('agent_messages.found', {'count': found.messages.length});
      finds.report({for (final message in found.messages) message.profile});
      final summary = found.messages.length > kSummaryAbove;
      final locked = appLock();
      final texts = summary || locked
          ? const <({String profile, String id}), String>{}
          : await _texts(found);
      if (!_current(epoch)) return;
      final alerts = messageAlertsFor(
        found,
        texts,
        shownProfile: shownProfile?.call(),
        appLock: locked,
      );
      for (final alert in alerts) {
        if (!_current(epoch)) return;
        if (service is GuardedNotificationService) {
          await (service as GuardedNotificationService).showWhile(
            alert,
            () => _current(epoch),
          );
        } else {
          await service.show(alert);
        }
      }
      if (!_current(epoch)) return;
      events('agent_messages.announced', {
        'count': found.messages.length,
        'summary': summary,
        'background': false,
      });
    } on Object {
      // A look that failed is tried again on the next tick.
    } finally {
      if (failure case final error? when _current(epoch)) {
        events('agent_messages.look_failed', {
          'error_type': '${error.runtimeType}',
          'background': false,
        });
      }
    }
  }

  /// The text of each message, by [FoundMessage.key]; one that cannot be read
  /// within [lookup] is left out.
  Future<Map<({String profile, String id}), String>> _texts(
    MessagesFound found,
  ) async {
    final texts = await Future.wait([
      for (final message in found.messages) _text(message),
    ]);
    return {
      for (var i = 0; i < texts.length; i++) found.messages[i].key: ?texts[i],
    };
  }

  Future<String?> _text(FoundMessage message) async {
    try {
      final page = await chat
          .loadMessagePage(
            message.delivery.id,
            profile: message.profile,
            limit: 1,
          )
          .timeout(lookup);
      return page.messages.firstOrNull?.content;
    } on Object {
      return null;
    }
  }

  void _forgetRecord() {
    _forgetting = _forgetting.then((_) async {
      try {
        await _record.clear();
      } on Object {
        // The next look still compares with what is stored.
      }
    });
  }

  void dispose() {
    _disposed = true;
    _invalidate();
    _timer?.cancel();
    settings.removeListener(_settingsChanged);
    WidgetsBinding.instance.removeObserver(this);
  }
}
