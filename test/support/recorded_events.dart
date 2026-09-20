/// Collects the events an `AuthController` reports.
class RecordedEvents {
  final List<(String, Map<String, Object>)> _all = [];

  void call(String name, [Map<String, Object> attributes = const {}]) =>
      _all.add((name, attributes));

  /// Attributes of every event called [name], in order.
  List<Map<String, Object>> named(String name) => [
    for (final (eventName, attributes) in _all)
      if (eventName == name) attributes,
  ];

  /// Names of the events starting with [prefix], in order.
  List<String> namesStartingWith(String prefix) => [
    for (final (name, _) in _all)
      if (name.startsWith(prefix)) name,
  ];
}
