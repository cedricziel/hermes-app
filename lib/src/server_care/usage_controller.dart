import 'package:flutter/foundation.dart';

import '../core/safe_notifier.dart';
import 'care_result.dart';
import 'server_care_repository.dart';
import 'usage_report.dart';
import 'widgets/usage_chart.dart';
import 'widgets/usage_day_list.dart';
import 'widgets/usage_model_list.dart';

/// The usage page's state: the window and metric the person chose, and the
/// report for them.
///
/// A read always names its profile and window; an answer for a window or
/// profile that has since been replaced is dropped. Usage figures live only
/// in this object and the widgets built from it: they are not stored, logged
/// or put in a breadcrumb or a span.
class UsageController extends ChangeNotifier with SafeNotifier {
  UsageController({
    required this.repository,
    String? profile,
    DateTime Function()? today,
    this.onUnsupported,
    this.lookupFailed,
  }) : _today = today ?? DateTime.now,
       // A named parameter cannot be a private initializing formal.
       // ignore: prefer_initializing_formals
       _profile = profile,
       _window = _rememberedWindow,
       _metric = _rememberedMetric;

  final ServerCareRepository repository;
  final DateTime Function() _today;

  /// Called when the server answered that it has no usage route.
  final VoidCallback? onUnsupported;

  /// Whether looking up the profile failed.
  final bool Function()? lookupFailed;

  // The last window and metric, kept for the rest of the app run so that
  // reopening the page does not reset them. They are a view preference, not
  // data, and a plain static is enough: there is one signed-in person per
  // process, and nothing here is persisted.
  static UsageChartWindow _rememberedWindow = UsageChartWindow.days30;
  static UsageChartMetric _rememberedMetric = UsageChartMetric.tokens;

  @visibleForTesting
  static void resetRemembered() {
    _rememberedWindow = UsageChartWindow.days30;
    _rememberedMetric = UsageChartMetric.tokens;
  }

  UsageChartWindow _window;
  UsageChartMetric _metric;
  String? _profile;
  UsageReport? _report;
  CareFailureKind? _failure;
  String? _failureMessage;
  bool _unsupported = false;
  bool _loading = false;
  int _generation = 0;
  int _revision = 0;

  UsageChartWindow get window => _window;
  UsageChartMetric get metric => _metric;
  String? get profile => _profile;

  /// The report for the current window and profile; null while the first read
  /// runs or after one failed with nothing to show.
  UsageReport? get report => _report;
  bool get loading => _loading;

  /// Why the last read failed; null when it succeeded.
  CareFailureKind? get failure => _failure;

  /// Hermes' own text for a refused read.
  String? get failureMessage => _failureMessage;

  /// True once the server answered that it has no usage route.
  bool get unsupported => _unsupported;

  /// Changes with every report, so a chart can start over for new data.
  int get revision => _revision;

  /// Reads usage for the current window and profile. Nothing is read while no
  /// profile is known.
  Future<void> load() async {
    final profile = _profile;
    if (disposed) return;
    if (profile == null) {
      // Wait for a profile; if looking one up failed, say so, with a retry.
      final failed = lookupFailed?.call() ?? false;
      _loading = !failed;
      _failure = failed ? CareFailureKind.offline : null;
      notifyListeners();
      return;
    }
    final generation = ++_generation;
    final window = _window;
    _loading = true;
    notifyListeners();
    final result = await repository.usage(
      profile: profile,
      days: window.days,
      today: _today(),
    );
    if (generation != _generation || disposed) return;
    _loading = false;
    switch (result) {
      case CareOk(:final value):
        _report = value;
        _failure = null;
        _failureMessage = null;
        _unsupported = false;
        _revision++;
      case CareUnsupported():
        _report = null;
        _failure = null;
        _failureMessage = null;
        _unsupported = true;
        onUnsupported?.call();
      case CareFailed(:final kind, :final message):
        _failure = kind;
        _failureMessage = message;
        _unsupported = false;
    }
    notifyListeners();
  }

  void setWindow(UsageChartWindow window) {
    if (window == _window) return;
    _window = _rememberedWindow = window;
    _replaced();
  }

  void setMetric(UsageChartMetric metric) {
    if (metric == _metric) return;
    // The metric only changes how the loaded report is drawn.
    _metric = _rememberedMetric = metric;
    notifyListeners();
  }

  void setProfile(String? profile) {
    if (profile == _profile) return;
    _profile = profile;
    _replaced();
  }

  void _replaced() {
    _report = null;
    _failure = null;
    _failureMessage = null;
    _unsupported = false;
    // An answer still on its way belongs to what was replaced.
    _generation++;
    _loading = false;
    notifyListeners();
    load();
  }

  /// The newest day with any use, or null; the chart starts on it rather than
  /// on an empty today.
  int? get latestDataIndex {
    final days = _report?.days ?? const <UsageDay>[];
    for (var i = days.length - 1; i >= 0; i--) {
      if (days[i].tokens > 0 || days[i].sessions > 0) return i;
    }
    return null;
  }

  /// One bar per day of the window, in the chosen metric.
  List<UsageChartDay> get chartDays => [
    for (final d in _report?.days ?? const <UsageDay>[])
      UsageChartDay(
        day: d.day,
        value: _metric == UsageChartMetric.tokens
            ? d.tokens.toDouble()
            : d.estimatedCost,
        conversations: d.sessions,
      ),
  ];

  /// The days with their figures, newest first, for the table.
  List<UsageDayEntry> get dayEntries => [
    for (final d in (_report?.days ?? const <UsageDay>[]).reversed)
      UsageDayEntry(
        day: d.day,
        tokens: d.tokens,
        cost: d.estimatedCost,
        conversations: d.sessions,
      ),
  ];

  /// The models, most tokens first, each with its part of the window.
  List<UsageModelEntry> get modelEntries {
    final report = _report;
    if (report == null) return const [];
    final whole = report.totals.tokens > 0
        ? report.totals.tokens
        : report.byModel.fold<int>(0, (n, m) => n + m.tokens);
    return [
      for (final m in report.byModel)
        UsageModelEntry(
          model: m.model,
          tokens: m.tokens,
          cost: m.estimatedCost,
          conversations: m.sessions,
          share: whole <= 0 ? 0 : (m.tokens / whole).clamp(0.0, 1.0),
        ),
    ];
  }
}
