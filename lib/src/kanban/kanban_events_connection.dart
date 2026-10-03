import 'dart:convert';

import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:stream_channel/stream_channel.dart';

import '../api/hermes_api_client.dart';
import '../chat/gateway/gateway_connection.dart';
import 'kanban_board_controller.dart';

/// Connects to the Kanban plugin's event stream. With [telemetry], the
/// upgrade is traced and each event is recorded by its kind.
KanbanEventsConnect hermesKanbanEventsConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  MessagingConnectionTracer? telemetry,
  Future<StreamChannel<String>> Function(Uri uri) open = openWebSocket,
}) {
  final socket = hermesSocketConnect(
    baseUrl: baseUrl,
    authRequired: authRequired,
    api: api,
    path: '/api/plugins/kanban/events',
    telemetry: telemetry,
    open: open,
  );
  return ({required since, board}) async {
    final channel = await socket({'since': '$since', 'board': ?board});
    if (telemetry == null) return channel;
    return channel.changeStream(
      (frames) => frames.map((frame) {
        _recordEvents(frame, telemetry);
        return frame;
      }),
    );
  };
}

void _recordEvents(String frame, MessagingConnectionTracer telemetry) {
  try {
    final data = jsonDecode(frame);
    if (data is! Map || data['events'] is! List) return;
    for (final event in data['events'] as List) {
      if (event is Map && event['kind'] is String) {
        telemetry.event(event['kind'] as String);
      }
    }
  } on Object catch (_) {
    // Telemetry must never break the stream.
  }
}
