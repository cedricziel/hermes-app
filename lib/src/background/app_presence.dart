/// Lets a background run tell whether the app is in front.
///
/// WorkManager runs a task in the same process as the app, even while the
/// app is open, and the open app announces requests itself. A suspended or
/// cached app does not: its isolate may be alive and answer, but nobody is
/// looking, so only an app whose lifecycle is `resumed` counts as in front.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;

/// The name the app's presence port is registered under.
const kAppPresencePort = 'hermes_app.presence';

bool _lifecycleResumed() =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

/// Answers pings from background runs for as long as the app's isolate runs:
/// whether the app is in front.
class AppPresence {
  AppPresence({this.name = kAppPresencePort, bool Function()? resumed})
    : _resumed = resumed ?? _lifecycleResumed;

  final String name;
  final bool Function() _resumed;
  ReceivePort? _port;

  void start() {
    if (_port != null) return;
    final port = _port = ReceivePort();
    IsolateNameServer.removePortNameMapping(name);
    IsolateNameServer.registerPortWithName(port.sendPort, name);
    port.listen((message) {
      if (message is SendPort) message.send(_resumed());
    });
  }

  void dispose() {
    final port = _port;
    if (port == null) return;
    _port = null;
    IsolateNameServer.removePortNameMapping(name);
    port.close();
  }
}

/// Whether the app's isolate answers within [timeout] that it is in front. A
/// port left behind by an isolate that is gone answers nothing, which counts
/// as not in front, like an app that is suspended or not running.
Future<bool> appInFront({
  String name = kAppPresencePort,
  Duration timeout = const Duration(milliseconds: 500),
}) async {
  final port = IsolateNameServer.lookupPortByName(name);
  if (port == null) return false;
  final reply = ReceivePort();
  try {
    port.send(reply.sendPort);
    return await reply.first.timeout(timeout, onTimeout: () => false) == true;
  } on Object {
    return false;
  } finally {
    reply.close();
  }
}
