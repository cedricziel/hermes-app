class UsageSnapshot {
  const UsageSnapshot({
    this.model,
    this.input,
    this.output,
    this.reasoning,
    this.total,
    this.calls,
    this.compressions,
    this.contextUsed,
    this.contextMax,
    this.contextPercent,
    this.contextEstimated,
    this.costUsd,
    this.costStatus,
  });

  final String? model;
  final int? input, output, reasoning, total, calls, compressions;
  final int? contextUsed, contextMax, contextPercent;
  final bool? contextEstimated;
  final num? costUsd;
  final String? costStatus;

  /// Preserves reported metrics; missing or invalid values remain unavailable.
  static UsageSnapshot? decode(Object? value) {
    if (value is! Map) return null;
    int? count(String key) => switch (value[key]) {
      final int number when number >= 0 => number,
      _ => null,
    };
    String? text(String key) => switch (value[key]) {
      final String text when text.trim().isNotEmpty => text,
      _ => null,
    };
    final cost = value['cost_usd'];
    final snapshot = UsageSnapshot(
      model: text('model'),
      input: count('input'),
      output: count('output'),
      reasoning: count('reasoning'),
      total: count('total'),
      calls: count('calls'),
      compressions: count('compressions'),
      contextUsed: count('context_used'),
      contextMax: count('context_max'),
      contextPercent: count('context_percent'),
      contextEstimated: value['context_estimated'] is bool
          ? value['context_estimated'] as bool
          : null,
      costUsd: cost is num && cost.isFinite && cost >= 0 ? cost : null,
      costStatus: text('cost_status'),
    );
    return snapshot.model != null ||
            snapshot.metrics.values.any((value) => value != null)
        ? snapshot
        : null;
  }

  Map<String, num?> get metrics => {
    'Input tokens': input,
    'Output tokens': output,
    'Reasoning tokens': reasoning,
    'Total tokens': total,
    'Calls': calls,
    'Context used': contextUsed,
    'Context capacity': contextMax,
    'Context percent': contextPercent,
    'Compressions': compressions,
    'Cost (USD)': costUsd,
  };
}
