import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

/// Collects the breadcrumbs a test's code records.
class RecordedBreadcrumbs implements BreadcrumbTrail {
  final List<(String, Map<String, Object>)> all = [];

  Breadcrumbs get breadcrumbs => Breadcrumbs.of(this);

  /// Attributes of every crumb called [name], in order.
  List<Map<String, Object>> named(String name) => [
    for (final (crumb, attributes) in all)
      if (crumb == name) attributes,
  ];

  /// Every string any crumb carries, for a search for what must not be there.
  String get text => [
    for (final (name, attributes) in all) ...[
      name,
      ...attributes.keys,
      ...attributes.values.map((v) => '$v'),
    ],
  ].join(' ');

  @override
  void record(String name, [Map<String, Object>? attributes]) =>
      all.add((name, attributes ?? const {}));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
