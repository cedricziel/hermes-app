import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

void main() {
  test('a trail-backed recorder adds a breadcrumb with its attributes', () {
    final trail = BreadcrumbTrail();
    Breadcrumbs.of(trail)('nav.destination', {'destination': 'chat'});

    expect(trail.recent.single.name, 'nav.destination');
    expect(trail.recent.single.attributes, {'destination': 'chat'});
  });

  test('the recorder for a disabled telemetry records nothing', () {
    expect(() => Breadcrumbs.none('nav.destination'), returnsNormally);
  });

  test('a failing trail never breaks the caller', () {
    final breadcrumbs = Breadcrumbs.of(_ThrowingTrail());

    expect(() => breadcrumbs('nav.destination'), returnsNormally);
  });
}

class _ThrowingTrail extends BreadcrumbTrail {
  @override
  void record(String name, [Map<String, Object> attributes = const {}]) =>
      throw StateError('full');
}
