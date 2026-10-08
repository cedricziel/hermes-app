import 'package:hermes_app/src/telemetry/telemetry.dart';

/// Collects the events an `AuthController` reports.
class RecordedEvents {
  final List<(String, Map<String, Object>, Map<String, Object>)> _all = [];

  void call(String name, [Map<String, Object> attributes = const {}]) =>
      _all.add((name, attributes, const {}));

  /// A connection whose events are recorded here, with the server attributes
  /// it was built with kept apart (see [serverAttributes]).
  ConnectionTelemetry connection(Map<String, Object> serverAttributes) =>
      ConnectionTelemetry(
        events: (name, [attributes = const {}]) =>
            _all.add((name, attributes, serverAttributes)),
      );

  /// Attributes of every event called [name], in order.
  List<Map<String, Object>> named(String name) => [
    for (final (eventName, attributes, _) in _all)
      if (eventName == name) attributes,
  ];

  /// Server attributes of the connection every event called [name] was
  /// logged on, in order.
  List<Map<String, Object>> serverAttributes(String name) => [
    for (final (eventName, _, server) in _all)
      if (eventName == name) server,
  ];

  /// Names of the events starting with [prefix], in order.
  List<String> namesStartingWith(String prefix) => [
    for (final (name, _, _) in _all)
      if (name.startsWith(prefix)) name,
  ];
}
