import 'dart:async';

import 'package:flutter/services.dart';

import '../deep_links/deep_link_listener.dart';
import 'ask_hermes.dart';
import 'intent_shortcuts.dart';

/// The Dart end of `hermes_app/intents` for the "Ask Hermes" intent, in
/// whichever engine runs it: the app's or the background engine the Runner
/// starts for an ask.
///
/// Swift calls `ask` (answered when the intent has something to say),
/// `expire` (iOS is out of time for an ask), `unavailable` (an engine it
/// could not use; a reason, for telemetry) and `openLink` (a `hermes://` link
/// to take, answered whether it was); Dart calls `ready` once it listens,
/// `finished` when an ask has nothing left to do, which is when Swift may
/// stop keeping the process alive for it, and `closed` when it stops
/// listening. Arguments are plain maps and strings; see `IntentsBridge.swift`
/// for the Swift end.
class IntentsChannel {
  IntentsChannel(
    this._ask, {
    this.openLink,
    this.channel = const MethodChannel(kIntentsChannel),
  });

  final AskHermes _ask;
  final MethodChannel channel;

  /// Takes a link the Runner opened for the intent, as the platform would
  /// deliver it: `DeepLinks.open`, which holds a link that arrives before the
  /// shell is up. Null where the app has no deep links.
  final PendingDeepLink? Function(Uri uri)? openLink;
  final _running = <String, AskRun>{};

  /// Listens, then tells Swift it may send asks.
  Future<void> start() async {
    channel.setMethodCallHandler(_onCall);
    try {
      await channel.invokeMethod<void>('ready');
    } on Object {
      // Without Swift's end there is nothing to ask for.
    }
  }

  void dispose() {
    channel.setMethodCallHandler(null);
    unawaited(_quietly(() => channel.invokeMethod<void>('closed')));
  }

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'ask':
        return _onAsk(call.arguments);
      case 'expire':
        _onExpire(call.arguments);
        return null;
      case 'unavailable':
        if (call.arguments case final String reason) {
          _ask.recordUnavailable(reason);
        }
        return null;
      case 'openLink':
        return _onOpenLink(call.arguments);
    }
    throw MissingPluginException();
  }

  Future<Map<String, Object?>> _onAsk(Object? arguments) async {
    final id = arguments is Map ? arguments['id'] : null;
    final question = arguments is Map ? arguments['question'] : null;
    final profile = arguments is Map ? arguments['profile'] : null;
    final chatId = arguments is Map ? arguments['chatId'] : null;
    final msLeft = arguments is Map ? arguments['msLeft'] : null;
    if (id is! String ||
        question is! String ||
        profile is! String? ||
        chatId is! String? ||
        msLeft is! num) {
      // Swift holds the process for an ask until it hears this one is over.
      if (id is String) unawaited(_finished(id));
      return {'outcome': AskOutcome.failed.wire};
    }
    final run = _ask.start(
      AskRequest(
        question: question,
        profile: profile,
        chatId: chatId,
        answerWithin: Duration(milliseconds: msLeft.toInt().clamp(0, 1 << 31)),
      ),
    );
    _running[id] = run;
    unawaited(_finish(id, run));
    final result = await run.answer;
    return {'outcome': result.outcome.wire, 'text': ?result.text};
  }

  Future<void> _finish(String id, AskRun run) async {
    try {
      await run.finished;
    } on Object {
      // Nothing is left to do for it either way.
    }
    _running.remove(id);
    await _finished(id);
  }

  Future<void> _finished(String id) =>
      _quietly(() => channel.invokeMethod<void>('finished', id));

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // The process is held until iOS ends it, at worst.
    }
  }

  bool _onOpenLink(Object? link) {
    final uri = link is String ? Uri.tryParse(link) : null;
    if (uri == null) return false;
    return openLink?.call(uri) != null;
  }

  /// Ends the ask [arguments] names, or every one when it names none.
  void _onExpire(Object? arguments) {
    if (arguments is String) {
      _running[arguments]?.expire();
      return;
    }
    for (final run in _running.values.toList()) {
      run.expire();
    }
  }
}
