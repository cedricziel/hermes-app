import 'json_read.dart';

/// One calendar day of usage, in the server's time zone.
class UsageDay {
  const UsageDay({
    required this.day,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.reasoningTokens = 0,
    this.estimatedCost = 0,
    this.sessions = 0,
    this.apiCalls = 0,
  });

  final DateTime day;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int reasoningTokens;
  final double estimatedCost;
  final int sessions;
  final int apiCalls;

  /// "Tokens" in the chart: input plus output.
  int get tokens => inputTokens + outputTokens;
}

class UsageModel {
  const UsageModel({
    required this.model,
    this.tokens = 0,
    this.estimatedCost = 0,
    this.sessions = 0,
    this.apiCalls = 0,
  });

  final String model;
  final int tokens;
  final double estimatedCost;
  final int sessions;
  final int apiCalls;
}

class UsageTotals {
  const UsageTotals({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.reasoningTokens = 0,
    this.estimatedCost = 0,
    this.actualCost = 0,
    this.sessions = 0,
    this.apiCalls = 0,
  });

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int reasoningTokens;

  /// The estimate every bar is drawn from.
  final double estimatedCost;

  /// What the provider billed; zero when it did not say.
  final double actualCost;
  final int sessions;
  final int apiCalls;

  int get tokens => inputTokens + outputTokens;
}

/// `GET /api/analytics/usage`, with the window filled in: one [UsageDay] for
/// each calendar day, zeros where the server sent none.
class UsageReport {
  const UsageReport({
    required this.days,
    required this.byModel,
    required this.totals,
    required this.windowDays,
  });

  /// Oldest first, exactly [windowDays] entries.
  final List<UsageDay> days;

  /// Most tokens first.
  final List<UsageModel> byModel;
  final UsageTotals totals;
  final int windowDays;

  /// Whether no day of the window has any usage.
  bool get isEmpty => days.every((d) => d.tokens == 0 && d.sessions == 0);

  static DateTime? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return null;
    final d = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    return d;
  }

  /// Reads [json] for a window of [days] days ending at [today] (the server's
  /// calendar day, as a date; its time is ignored). Rows that do not fit are
  /// skipped; null when [json] is not an object.
  static UsageReport? parse(
    Object? json, {
    required int days,
    required DateTime today,
  }) {
    final root = readMap(json);
    if (root == null || days < 1) return null;
    final end = DateTime.utc(today.year, today.month, today.day);
    final start = end.subtract(Duration(days: days - 1));

    final byDay = <DateTime, UsageDay>{};
    for (final row in readMaps(root['daily'])) {
      final day = _date(readString(row['day']));
      if (day == null) continue;
      byDay[day] = UsageDay(
        day: day,
        inputTokens: readInt(row['input_tokens']) ?? 0,
        outputTokens: readInt(row['output_tokens']) ?? 0,
        cacheReadTokens: readInt(row['cache_read_tokens']) ?? 0,
        reasoningTokens: readInt(row['reasoning_tokens']) ?? 0,
        estimatedCost: readDouble(row['estimated_cost']) ?? 0,
        sessions: readInt(row['sessions']) ?? 0,
        apiCalls: readInt(row['api_calls']) ?? 0,
      );
    }
    final window = [
      for (var i = 0; i < days; i++)
        () {
          final d = DateTime.utc(start.year, start.month, start.day + i);
          return byDay[d] ?? UsageDay(day: d);
        }(),
    ];

    final models = [
      for (final row in readMaps(root['by_model']))
        if (readString(row['model']) case final name?)
          UsageModel(
            model: name,
            tokens:
                (readInt(row['input_tokens']) ?? 0) +
                (readInt(row['output_tokens']) ?? 0),
            estimatedCost: readDouble(row['estimated_cost']) ?? 0,
            sessions: readInt(row['sessions']) ?? 0,
            apiCalls: readInt(row['api_calls']) ?? 0,
          ),
    ]..sort((a, b) => b.tokens.compareTo(a.tokens));

    final t = readMap(root['totals']);
    final totals = t == null
        ? UsageTotals(
            inputTokens: window.fold(0, (n, d) => n + d.inputTokens),
            outputTokens: window.fold(0, (n, d) => n + d.outputTokens),
            cacheReadTokens: window.fold(0, (n, d) => n + d.cacheReadTokens),
            reasoningTokens: window.fold(0, (n, d) => n + d.reasoningTokens),
            estimatedCost: window.fold(0.0, (n, d) => n + d.estimatedCost),
            sessions: window.fold(0, (n, d) => n + d.sessions),
            apiCalls: window.fold(0, (n, d) => n + d.apiCalls),
          )
        : UsageTotals(
            inputTokens: readInt(t['total_input']) ?? 0,
            outputTokens: readInt(t['total_output']) ?? 0,
            cacheReadTokens: readInt(t['total_cache_read']) ?? 0,
            reasoningTokens: readInt(t['total_reasoning']) ?? 0,
            estimatedCost: readDouble(t['total_estimated_cost']) ?? 0,
            actualCost: readDouble(t['total_actual_cost']) ?? 0,
            sessions: readInt(t['total_sessions']) ?? 0,
            apiCalls: readInt(t['total_api_calls']) ?? 0,
          );
    return UsageReport(
      days: window,
      byModel: models,
      totals: totals,
      windowDays: days,
    );
  }
}
