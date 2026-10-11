/// Lets a background run tell whether the app's own isolate is alive.
///
/// WorkManager runs a task in the same process as the app, even while the
/// app is open, and the open app announces requests itself. A run that finds
/// the app alive leaves the announcing to it.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

/// The name the app's presence port is registered under.
const kAppPresencePort = 'hermes_app.presence';

/// Answers pings from background runs for as long as the app's isolate runs.
class AppPresence {
  AppPresence({this.name = kAppPresencePort});

  final String name;
  ReceivePort? _port;

  void start() {
    if (_port != null) return;
    final port = _port = ReceivePort();
    IsolateNameServer.removePortNameMapping(name);
    IsolateNameServer.registerPortWithName(port.sendPort, name);
    port.listen((message) {
      if (message is SendPort) message.send(true);
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

/// Whether the app's isolate answers within [timeout]. A port left behind by
/// an isolate that is gone answers nothing, so only an answer counts.
Future<bool> mainIsolateAlive({
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
