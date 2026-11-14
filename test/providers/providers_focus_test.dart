import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_detail_pane.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';

import 'fake_provider_backend.dart';
import 'providers_screen_rig.dart';

/// Where the screen starts when the chat opens it.
void main() {
  late ProvidersRig rig;

  setUp(() => rig = ProvidersRig());

  testWidgets('"Add a provider" is scrolled into view', (tester) async {
    await rig.pump(tester, size: const Size(390, 500));
    final before = tester.getTopLeft(find.text('Add a provider')).dy;
    await tester.pumpWidget(const SizedBox.shrink());

    rig = ProvidersRig();
    await rig.pump(
      tester,
      size: const Size(390, 500),
      focus: const ProvidersFocus.add(),
    );

    final after = tester.getTopLeft(find.text('Add a provider')).dy;
    expect(after, lessThan(before));
  });

  testWidgets('a connected provider opens as a page on a phone', (
    tester,
  ) async {
    rig.backend
      ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(
        'sk-or-v1-test-aaaa-4f2a',
      )
      ..defaultProvider = 'openrouter'
      ..defaultModel = 'example-model-a';

    await rig.pump(tester, focus: const ProvidersFocus.provider('openrouter'));

    expect(find.byType(ProviderDetailPage), findsOneWidget);
    expect(find.text('Remove key'), findsWidgets);
  });

  testWidgets('a connected provider is selected beside the list when wide', (
    tester,
  ) async {
    rig.backend
      ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(
        'sk-or-v1-test-aaaa-4f2a',
      )
      ..keys['ANTHROPIC_API_KEY'] = FakeProviderBackend.redact(
        'sk-ant-test-bbbb-9c1d',
      )
      ..defaultProvider = 'anthropic'
      ..defaultModel = 'example-model-b';

    await rig.pump(
      tester,
      size: const Size(1280, 800),
      platform: TargetPlatform.macOS,
      focus: const ProvidersFocus.provider('openrouter'),
    );

    expect(find.byType(ProviderDetailPage), findsNothing);
    expect(
      tester
          .widget<ProviderDetailPane>(find.byType(ProviderDetailPane))
          .providerId,
      'openrouter',
    );
  });

  testWidgets('a provider that lost its key opens the way to reconnect it', (
    tester,
  ) async {
    rig.backend
      ..defaultProvider = 'openrouter'
      ..defaultModel = 'example-model-a';

    await rig.pump(tester, focus: const ProvidersFocus.provider('openrouter'));

    expect(find.byType(ProviderDetailPage), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('an unknown provider falls back to "Add a provider"', (
    tester,
  ) async {
    await rig.pump(tester, focus: const ProvidersFocus.provider('nowhere'));

    expect(find.byType(ProviderDetailPage), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Add a provider'), findsOneWidget);
  });

  testWidgets('no focus leaves the list at the top', (tester) async {
    await rig.pump(tester);

    expect(find.byType(ProviderDetailPage), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
