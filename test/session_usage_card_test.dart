import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_controller.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_card.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

import 'support/accessibility.dart';

void main() {
  testWidgets(
    'usage disclosure opens one scoped read and shows only supplied session metrics',
    (tester) async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: 'work',
      );
      var requests = 0;
      final controller = SessionUsageController()
        ..bind(owner, (_, _) async {
          requests++;
          return {
            'model': 'scripted',
            'input': 5,
            'total': 8,
            'reasoning': 2,
            'context_used': 12,
            'context_estimated': true,
          };
        });
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SessionUsageCard(controller: controller)),
        ),
      );
      expect(requests, 0);
      await tester.tap(find.text('Session usage'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Input tokens: 5'), findsOneWidget);
      expect(find.text('Reasoning tokens: 2'), findsOneWidget);
      expect(find.textContaining('Output tokens'), findsNothing);
      expect(find.textContaining('Cost (USD)'), findsNothing);
      expect(find.text('Estimated context'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Session usage · 8 tokens')),
        disclosure('Session usage · 8 tokens', open: true),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'loading and disconnected snapshots have explicit freshness labels',
    (tester) async {
      final owner = UsageScope(
        connection: Object(),
        sessionId: 'runtime',
        profile: null,
      );
      final pending = Completer<Map<String, Object?>>();
      final controller = SessionUsageController()
        ..bind(owner, (_, _) => pending.future);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SessionUsageCard(controller: controller)),
        ),
      );
      await tester.tap(find.text('Session usage'));
      await tester.pump();
      expect(find.text('Loading session usage…'), findsOneWidget);
      pending.complete({'total': 8});
      await tester.pumpAndSettle();
      controller.disconnected();
      await tester.pumpAndSettle();
      expect(find.text('Stale session usage'), findsOneWidget);
      expect(find.text('Total tokens: 8'), findsOneWidget);
    },
  );

  testWidgets('unsupported usage draws nothing, also after a disconnect', (
    tester,
  ) async {
    final owner = UsageScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: null,
    );
    final controller = SessionUsageController()
      ..bind(
        owner,
        (_, _) async => throw const GatewayRpcException(-32601, 'Unsupported'),
      );
    addTearDown(controller.dispose);
    await controller.opened();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionUsageCard(controller: controller, initiallyOpen: true),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);

    controller.disconnected();
    await tester.pump();
    expect(controller.shown, isFalse);
    expect(find.byType(Text), findsNothing);
  });
}
