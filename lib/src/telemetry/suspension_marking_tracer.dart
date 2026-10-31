import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart';

/// Counts how often the app was paused (sent to the background, where the
/// system may suspend the process and Dart timers stop).
///
/// A span that started before a pause and ended after it measures the time
/// the app was away as well: a request in flight when the phone locked ends
/// only when the app comes back, so its span can last hours.
class AppSuspensions with WidgetsBindingObserver {
  AppSuspensions._();

  /// Starts counting. Needs the binding, so it is called once the app runs.
  static AppSuspensions install() {
    final suspensions = AppSuspensions._();
    WidgetsBinding.instance.addObserver(suspensions);
    return suspensions;
  }

  /// For tests: a counter moved by [pause] only.
  @visibleForTesting
  AppSuspensions.manual();

  int _count = 0;

  /// Pauses so far.
  int get count => _count;

  @visibleForTesting
  void pause() => _count++;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _count++;
  }
}

/// Starts spans on [_inner] and marks each one that outlived a pause of the
/// app with `app.suspended: true`, so long spans that only measure the time
/// the app was away can be told from slow requests.
class SuspensionMarkingTracer implements Tracer {
  SuspensionMarkingTracer(this._inner, this._suspensions);

  final Tracer _inner;
  final AppSuspensions _suspensions;

  @override
  String get name => _inner.name;

  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) => _MarkingSpan(
    _inner.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    ),
    _suspensions,
  );

  @override
  Future<T> startActiveSpan<T>(
    String name,
    Future<T> Function(Span span) body, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    List<SpanLink> links = const [],
  }) => _inner.startActiveSpan(
    name,
    (span) => body(_MarkingSpan(span, _suspensions)),
    kind: kind,
    attributes: attributes,
    links: links,
  );
}

class _MarkingSpan implements Span {
  _MarkingSpan(this._inner, this._suspensions)
    : _startedAt = _suspensions.count;

  final Span _inner;
  final AppSuspensions _suspensions;
  final int _startedAt;

  @override
  SpanContext get spanContext => _inner.spanContext;

  @override
  String get name => _inner.name;

  @override
  bool get isRecording => _inner.isRecording;

  @override
  void setAttribute(String key, Object? value) =>
      _inner.setAttribute(key, value);

  @override
  void setAttributes(Map<String, Object?> attributes) =>
      _inner.setAttributes(attributes);

  @override
  void addEvent(
    String name, {
    Map<String, Object?>? attributes,
    DateTime? timestamp,
  }) => _inner.addEvent(name, attributes: attributes, timestamp: timestamp);

  @override
  void setStatus(StatusCode code, {String? description}) =>
      _inner.setStatus(code, description: description);

  @override
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, Object?>? attributes,
  }) => _inner.recordException(
    exception,
    stackTrace: stackTrace,
    attributes: attributes,
  );

  @override
  void end([DateTime? endTime]) {
    if (_suspensions.count != _startedAt) {
      _inner.setAttribute('app.suspended', true);
    }
    _inner.end(endTime);
  }
}
