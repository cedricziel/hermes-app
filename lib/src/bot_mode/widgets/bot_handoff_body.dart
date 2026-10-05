import 'dart:convert';

import 'package:flutter/material.dart';

import '../../chat/chat_models.dart';

/// Hermes' receipt and eventual reply. A queued receipt is never delivery.
class BotHandoffBody extends StatelessWidget {
  const BotHandoffBody({super.key, required this.data});
  final Map<String, Object?> data;

  static BotHandoffBody? of(ToolCall call) {
    if (call.name != 'message_agent') return null;
    var raw = call.resultData ?? call.result;
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        return null;
      }
    }
    if (raw is! Map) return null;
    return BotHandoffBody(data: raw.cast<String, Object?>());
  }

  String get label => switch (data['status']) {
    'queued' => 'Queued · awaiting outcome',
    'claimed' => 'In progress · awaiting outcome',
    'ambiguous' => 'Delivery outcome unknown',
    'settled' => data['error'] == null ? 'Reply received' : 'Delivery failed',
    _ => data['error'] != null ? 'Delivery failed' : 'Handoff receipt',
  };
  bool get failed =>
      data['error'] != null || {'failed', 'error'}.contains(data['status']);
  bool get pending =>
      {'queued', 'claimed', 'ambiguous'}.contains(data['status']);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (data['to'] case final String target) Text('To $target'),
        for (final key in ['reply', 'error', 'detail'])
          if (data[key] case final String value when value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(value),
            ),
        if (pending)
          const Text('Receipt retained. Do not resend this handoff.'),
      ],
    ),
  );
}
