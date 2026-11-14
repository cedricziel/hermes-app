import 'package:flutter/cupertino.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import 'fake_provider_backend.dart';
import 'providers_screen_rig.dart';

const _settle = ProvidersRig.settle;

/// The breadcrumbs the screen leaves: fixed names, flags and kinds, never a
/// provider, a profile, an address or a model.
void main() {
  late BreadcrumbTrail trail;

  setUp(() => trail = BreadcrumbTrail());

  List<Map<String, Object?>> crumbs(String name) => [
    for (final c in trail.recent)
      if (c.name == name) Map<String, Object?>.from(c.attributes),
  ];

  Future<ProvidersRig> pump(
    WidgetTester tester, {
    FakeProviderBackend? backend,
    ProvidersEntry entry = ProvidersEntry.sidebar,
  }) async {
    final rig = ProvidersRig(backend: backend);
    await rig.pump(
      tester,
      entry: entry,
      providers: [Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail))],
    );
    return rig;
  }

  for (final entry in ProvidersEntry.values) {
    testWidgets('opened from the ${entry.wire}', (tester) async {
      await pump(tester, entry: entry);
      expect(crumbs('providers.opened'), [
        {'source': entry.wire},
      ]);
    });
  }

  group('connect started', () {
    testWidgets('a key', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
      await _settle(tester);
      expect(crumbs('providers.connect.started'), [
        {'method': 'key'},
      ]);
    });

    testWidgets('an account', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await _settle(tester);
      expect(crumbs('providers.connect.started'), [
        {'method': 'account'},
      ]);
    });

    testWidgets('an endpoint', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Custom endpoint'), 200);
      await tester.tap(find.text('Custom endpoint'));
      await _settle(tester);
      expect(crumbs('providers.connect.started'), [
        {'method': 'endpoint'},
      ]);
    });

    testWidgets('an account on the server, after a key form', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('provider-row-anthropic')),
        200,
      );
      // Anthropic has a key and an account on the server: "Use an account".
      await tester.tap(find.byKey(const ValueKey('provider-row-anthropic')));
      await _settle(tester);
      await tester.tap(find.textContaining('account instead'));
      await _settle(tester);
      expect(crumbs('providers.connect.started'), [
        {'method': 'key'},
        {'method': 'server'},
      ]);
    });
  });

  group('remove confirmed', () {
    Future<void> removeFromDetail(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
      await _settle(tester);
      await tester.scrollUntilVisible(find.text(label), 200);
      await tester.tap(find.text(label));
      await _settle(tester);
    }

    testWidgets('only a confirmed removal leaves a crumb', (tester) async {
      final backend = FakeProviderBackend()
        ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(
          'sk-or-v1-test-aaaa-4f2a',
        )
        ..defaultProvider = 'openrouter'
        ..defaultModel = 'example-model-a';
      await pump(tester, backend: backend);
      await removeFromDetail(tester, 'Remove key');
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(crumbs('providers.remove.confirmed'), isEmpty);

      await tester.tap(find.text('Remove key'));
      await _settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.text('Remove key'),
        ),
      );
      await _settle(tester);

      expect(crumbs('providers.remove.confirmed'), [
        {'kind': 'key'},
      ]);
      expect(backend.keys, isEmpty);
    });
  });

  testWidgets('no crumb carries a provider, a profile or a model', (
    tester,
  ) async {
    final backend = FakeProviderBackend()
      ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(
        'sk-or-v1-test-aaaa-4f2a',
      )
      ..signedIn.add('nous')
      ..defaultProvider = 'openrouter'
      ..defaultModel = 'example-model-a';
    await pump(tester, backend: backend);
    // A key form, an account, an endpoint and a removal.
    await tester.tap(find.byKey(const ValueKey('provider-row-anthropic')));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Custom endpoint'), 200);
    await tester.tap(find.text('Custom endpoint'));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.tap(find.text('Sign out'));
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Sign out'),
      ),
    );
    await _settle(tester);

    final names = {for (final c in trail.recent) c.name};
    expect(
      names,
      containsAll([
        'providers.opened',
        'providers.connect.started',
        'providers.remove.confirmed',
      ]),
    );
    expect(crumbs('providers.remove.confirmed'), [
      {'kind': 'account'},
    ]);
    for (final c in trail.recent.where(
      (c) => c.name.startsWith('providers.'),
    )) {
      expect(
        c.attributes.keys,
        anyOf([
          equals(['source']),
          equals(['method']),
          equals(['kind']),
        ]),
        reason: c.name,
      );
      final text = c.attributes.values.join(' ').toLowerCase();
      for (final secret in [
        'openrouter',
        'anthropic',
        'nous',
        'work',
        'example',
        'sk-or',
      ]) {
        expect(text, isNot(contains(secret)), reason: c.name);
      }
    }
  });
}
