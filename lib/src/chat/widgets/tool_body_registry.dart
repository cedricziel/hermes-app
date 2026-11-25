import 'package:flutter/widgets.dart';

import '../../telemetry/report_bug.dart';
import '../chat_models.dart';

/// Builds the view an opened tool card shows for [call], or null when the
/// call is not the shape the view expects.
typedef ToolBodyBuilder = Widget? Function(ToolCall call);

/// One tool view: the tool names it serves (any tool when empty), an optional
/// predicate on the call's arguments and result, and its [build].
class ToolBodyEntry {
  const ToolBodyEntry({
    this.names = const {},
    this.matches,
    required this.build,
  });

  final Set<String> names;
  final bool Function(ToolCall call)? matches;
  final ToolBodyBuilder build;

  bool _serves(ToolCall call) =>
      (names.isEmpty || names.contains(call.name)) &&
      (matches?.call(call) ?? true);
}

/// The tool views in the order they are tried. The first entry that serves a
/// call and builds a body wins; a call no entry serves, an entry whose
/// builder returns null and one whose predicate or builder throws all leave
/// the call to the card's generic input and result.
///
/// Only the building is guarded: a body that throws from its own `build`
/// method is not caught here.
class ToolBodyRegistry {
  const ToolBodyRegistry(this.entries);

  final List<ToolBodyEntry> entries;

  Widget? bodyFor(ToolCall call) {
    for (final entry in entries) {
      try {
        if (!entry._serves(call)) continue;
        final body = entry.build(call);
        if (body != null) return body;
      } on Object catch (e, stack) {
        reportBug(e, stack, 'a tool body');
        continue;
      }
    }
    return null;
  }
}
