enum MemoryOutcomeKind { saved, staged, full }

/// One line of a proposed or saved change: [added] text is new, the rest
/// is replaced or removed.
typedef MemoryLine = ({bool added, String text});

final _pendingId = RegExp(r'^[0-9a-f]{8}$');
final _fullUsage = RegExp(r'^\s*([\d,]+)\s*/\s*([\d,]+)\s*$');
final _percent = RegExp(r'^\s*(\d+)\s*%');

/// What a `memory` tool call came to, read from its `tool.complete` result
/// and arguments. Null for a result of any other shape, which keeps the
/// generic tool body and its failed status.
class MemoryToolOutcome {
  const MemoryToolOutcome._({
    required this.kind,
    required this.tab,
    required this.blocks,
    this.percent,
    this.used,
    this.limit,
    this.pendingId,
  });

  final MemoryOutcomeKind kind;

  /// "About you" for the user profile, "Agent notes" for the agent's own.
  final String tab;

  /// One block per operation, in the order the agent wrote them.
  final List<List<MemoryLine>> blocks;

  /// How full the tab is after a save, when Hermes said so.
  final int? percent;

  /// The characters used and the limit of a full tab, as Hermes wrote them.
  final String? used;
  final String? limit;

  /// The id a staged write is approved or rejected by.
  final String? pendingId;

  static MemoryToolOutcome? parse({
    Map<String, Object?>? args,
    required Object? result,
  }) {
    if (result is! Map) return null;
    final tab = switch (args?['target'] ?? result['target']) {
      'user' => 'About you',
      _ => 'Agent notes',
    };
    MemoryToolOutcome outcome(
      MemoryOutcomeKind kind, {
      int? percent,
      String? used,
      String? limit,
      String? pendingId,
    }) => MemoryToolOutcome._(
      kind: kind,
      tab: tab,
      blocks: _blocks(args),
      percent: percent,
      used: used,
      limit: limit,
      pendingId: pendingId,
    );
    final usage = result['usage'];
    if (result['staged'] == true) {
      final id = result['pending_id'];
      return id is String && _pendingId.hasMatch(id)
          ? outcome(MemoryOutcomeKind.staged, pendingId: id)
          : null;
    }
    if (result['success'] == true) {
      final percent = usage is String ? _percent.firstMatch(usage) : null;
      return outcome(
        MemoryOutcomeKind.saved,
        percent: int.tryParse(percent?.group(1) ?? ''),
      );
    }
    final error = result['error'];
    if (result['success'] == false &&
        error is String &&
        error.startsWith('Memory at ') &&
        usage is String) {
      final match = _fullUsage.firstMatch(usage);
      if (match != null) {
        return outcome(
          MemoryOutcomeKind.full,
          used: match.group(1),
          limit: match.group(2),
        );
      }
    }
    return null;
  }

  static List<List<MemoryLine>> _blocks(Map<String, Object?>? args) {
    if (args == null) return const [];
    final operations = args['operations'];
    final sources = operations is List
        ? [
            for (final operation in operations)
              if (operation is Map)
                {
                  'action': args['action'],
                  ...operation.cast<String, Object?>(),
                },
          ]
        : [args];
    return [
      for (final source in sources)
        if (_block(source) case final block when block.isNotEmpty) block,
    ];
  }

  static List<MemoryLine> _block(Map<String, Object?> source) {
    final action = source['action'];
    final old = source['old_text'], content = source['content'];
    return [
      if (action != 'add' && old is String && old.isNotEmpty)
        (added: false, text: old),
      if (action != 'remove' && content is String && content.isNotEmpty)
        (added: true, text: content),
    ];
  }
}
