import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/app/providers/auth_providers.dart';
import 'package:hermes_app/src/profiles/soul/open_soul.dart';
import 'package:hermes_app/src/profiles/soul/soul_availability.dart';
import 'package:provider/provider.dart';

import '../../support/fake_hermes_server.dart';

/// The real provider definition, as the Files test uses: a new API client is
/// a new connection and starts with Personality shown again.
void main() {
  Widget app(HermesRepositories? repositories) => MaterialApp(
    home: MultiProvider(
      providers: [
        Provider<HermesRepositories?>.value(value: repositories),
        soulAvailabilityProvider(),
      ],
      child: Builder(
        builder: (context) => Text(soulShown(context) ? 'shown' : 'hidden'),
      ),
    ),
  );

  SoulAvailability availabilityOf(WidgetTester tester) =>
      tester.element(find.byType(Text)).read<SoulAvailability?>()!;

  testWidgets('signed out, nothing is offered and nothing throws', (
    tester,
  ) async {
    await tester.pumpWidget(app(null));
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing route hides it for the connection only', (
    tester,
  ) async {
    final first = HermesRepositories(FakeHermesServer().client());
    await tester.pumpWidget(app(first));
    expect(find.text('shown'), findsOneWidget);

    availabilityOf(tester).markUnsupported();
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);

    // The same connection pumped again keeps the answer.
    await tester.pumpWidget(app(first));
    expect(find.text('hidden'), findsOneWidget);

    // A new API client is a new connection: shown again.
    await tester.pumpWidget(
      app(HermesRepositories(FakeHermesServer().client())),
    );
    expect(find.text('shown'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Signing out hides it again.
    await tester.pumpWidget(app(null));
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
