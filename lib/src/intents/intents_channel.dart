import 'dart:async';

import 'package:flutter/services.dart';

import 'ask_hermes.dart';
import 'intent_shortcuts.dart';

/// The Dart end of `hermes_app/intents` for the "Ask Hermes" intent, in
/// whichever engine runs it: the app's or the background engine the Runner
/// starts for an ask.
///
/// Swift calls `ask` (answered when the intent has something to say) and
/// `expire`; Dart calls `ready` once it listens, and `finished` when an ask
/// has nothing left to do, which is when Swift may stop keeping the process
/// alive for it.
class IntentsChannel {
  IntentsChannel(
    this._ask, [
    this._channel = const MethodChannel(kIntentsChannel),
  ]);

  final AskHermes _ask;
  final MethodChannel _channel;
  final _running = <String, AskRun>{};

  /// Listens, then tells Swift it may send asks.
  Future<void> start() async {
    _channel.setMethodCallHandler(_onCall);
    try {
      await _channel.invokeMethod<void>('ready');
    } on Object {
      // Without Swift's end there is nothing to ask for.
    }
  }

  void dispose() => _channel.setMethodCallHandler(null);

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'ask':
        return _onAsk(call.arguments);
      case 'expire':
        _onExpire(call.arguments);
        return null;
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
    try {
      await _channel.invokeMethod<void>('finished', id);
    } on Object {
      // The process is held until iOS ends it, at worst.
    }
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
