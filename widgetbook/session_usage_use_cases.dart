import 'dart:async';

import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_card.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_controller.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

SessionUsageController _usage(
  Map<String, Object?> payload, {
  bool stale = false,
}) {
  final scope = UsageScope(
    connection: Object(),
    sessionId: 'fixture',
    profile: null,
  );
  final controller = SessionUsageController()
    ..bind(scope, (_, _) async => payload)
    ..tick(scope, payload);
  if (stale) controller.disconnected();
  return controller;
}

WidgetbookNode sessionUsageNode() => WidgetbookComponent(
  name: 'Session usage',
  useCases: [
    WidgetbookUseCase(
      name: 'Complete snapshot',
      builder: (_) => frame(
        SessionUsageCard(
          initiallyOpen: true,
          controller: _usage({
            'model': 'scripted',
            'input': 72,
            'output': 12,
            'reasoning': 6,
            'total': 84,
            'calls': 2,
            'context_used': 1234,
            'context_max': 8192,
            'context_percent': 15,
            'compressions': 1,
            'cost_usd': 0.0152,
          }),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Partial snapshot',
      builder: (_) => frame(
        SessionUsageCard(
          initiallyOpen: true,
          controller: _usage({'input': 72, 'total': 84}),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Estimated context',
      builder: (_) => frame(
        SessionUsageCard(
          initiallyOpen: true,
          controller: _usage({
            'total': 84,
            'context_used': 1234,
            'context_estimated': true,
          }),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Disconnected stale snapshot',
      builder: (_) => frame(
        SessionUsageCard(
          initiallyOpen: true,
          controller: _usage({'model': 'scripted', 'total': 84}, stale: true),
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Loading',
      builder: (_) {
        final scope = UsageScope(
          connection: Object(),
          sessionId: 'fixture',
          profile: null,
        );
        final controller = SessionUsageController()
          ..bind(scope, (_, _) => Completer<Map<String, Object?>>().future);
        unawaited(controller.opened());
        return frame(
          SessionUsageCard(controller: controller, initiallyOpen: true),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'Unsupported backend',
      builder: (_) {
        final scope = UsageScope(
          connection: Object(),
          sessionId: 'fixture',
          profile: null,
        );
        final controller = SessionUsageController()
          ..bind(
            scope,
            (_, _) async =>
                throw const GatewayRpcException(-32601, 'Unsupported'),
          );
        unawaited(controller.opened());
        return frame(
          SessionUsageCard(controller: controller, initiallyOpen: true),
        );
      },
    ),
  ],
);
