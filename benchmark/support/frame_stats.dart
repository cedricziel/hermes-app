import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show debugOnRebuildDirtyWidget;
import 'package:flutter_test/flutter_test.dart';

/// The step every measured frame advances the test clock by.
const frameStep = Duration(milliseconds: 16);

/// True in the AOT profile build run by `flutter drive --profile`, where the
/// scenarios run in a real window on the real clock.
const profileMode = bool.fromEnvironment('dart.vm.profile');

final _phases =
    !profileMode && Platform.environment['CHAT_BENCH_PHASES'] == '1';

/// Every frame the engine reported since [collectFrameTimings] was called.
final _timings = <FrameTiming>[];

void collectFrameTimings() =>
    SchedulerBinding.instance.addTimingsCallback(_timings.addAll);

/// Per-frame costs of one scenario at one width.
///
/// Widget-test mode: the real wall time, in milliseconds, spent inside
/// `tester.pump` (events fed to the stream, build, layout and paint on the UI
/// thread, plus the microtasks the frame flushes). The test binding has no
/// rasteriser, so there is no raster number.
///
/// Profile mode: the engine's own [FrameTiming] of the frames produced while
/// the measured pumps ran: `buildDuration` (UI thread build, layout, paint) is
/// the primary number and `rasterDuration` is reported beside it.
class FrameLog {
  final List<double> ms = [];
  final List<double> raster = [];
  final _watch = Stopwatch();
  final _wall = Stopwatch();

  /// Real time since the first frame of this log, measured or not.
  double get wallMs => _wall.elapsedMicroseconds / 1000;

  /// Profile mode: the [start, end] of every measured pump on the timeline
  /// clock. Pumps made between them (a scroll that prepares a tap) are not
  /// part of the measurement, so their frames are not counted.
  final _spans = <(int, int)>[];
  int pumps = 0;

  /// Pumps one frame and records what it cost. [before] runs inside the
  /// measured window too (events fed to a stream, text typed), because the
  /// real UI thread pays for them just the same.
  Future<void> frame(
    WidgetTester tester, {
    Future<void> Function()? before,
  }) async {
    _wall.start();
    if (profileMode) {
      final start = Timeline.now;
      if (before != null) await before();
      await tester.pump(frameStep);
      _spans.add((start, Timeline.now));
      pumps++;
      return;
    }
    if (_phases) {
      await _framePhases(tester, before);
      pumps++;
      return;
    }
    _watch
      ..reset()
      ..start();
    if (before != null) await before();
    await tester.pump(frameStep);
    _watch.stop();
    ms.add(_watch.elapsedMicroseconds / 1000);
    pumps++;
  }

  /// Records [pump] as one measured frame, with no pump of its own after it.
  /// For a pump that already produces the frame, such as `pumpWidget` mounting
  /// the screen: [frame] would add `tester.pump(frameStep)` and count two
  /// frames as one. (`CHAT_BENCH_PHASES=1` times it whole, not split.)
  Future<void> mount(WidgetTester tester, Future<void> Function() pump) async {
    _wall.start();
    if (profileMode) {
      final start = Timeline.now;
      await pump();
      _spans.add((start, Timeline.now));
      pumps++;
      return;
    }
    _watch
      ..reset()
      ..start();
    await pump();
    _watch.stop();
    ms.add(_watch.elapsedMicroseconds / 1000);
    pumps++;
  }

  /// Diagnostic (`CHAT_BENCH_PHASES=1`, test mode): the same frame cut into
  /// event handling, build, layout and paint. Each phase is its own pump that
  /// stops after that phase, and the next one carries on from there. The
  /// elements the build phase rebuilt are counted by widget type too.
  final events = <double>[];
  final build = <double>[];
  final layout = <double>[];
  final rebuilt = <String, int>{};

  /// Elements built for the first time, by widget type: a widget that is
  /// mounted again every frame has lost its state.
  final mounted = <String, int>{};
  int rebuiltTotal = 0;

  Future<void> _framePhases(
    WidgetTester tester,
    Future<void> Function()? before,
  ) async {
    double lap() {
      final v = _watch.elapsedMicroseconds / 1000;
      _watch
        ..reset()
        ..start();
      return v;
    }

    final total = Stopwatch()..start();
    _watch
      ..reset()
      ..start();
    if (before != null) await before();
    await tester.idle();
    events.add(lap());
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final name = element.widget.runtimeType.toString();
      rebuilt[name] = (rebuilt[name] ?? 0) + 1;
      rebuiltTotal++;
      if (!builtOnce) mounted[name] = (mounted[name] ?? 0) + 1;
    };
    await tester.pump(frameStep, EnginePhase.build);
    build.add(lap());
    // The rest of the frame: layout, compositing bits and paint. A list builds
    // its items while it lays out, so the tally runs through this part too.
    // A pump does nothing when no frame is scheduled, and a build that left
    // nothing dirty schedules none; scheduling one here makes the second pump
    // run the pipeline in every recorded frame, so no frame's layout and
    // paint is left for the next frame's lap.
    tester.binding.scheduleFrame();
    await tester.pump(Duration.zero);
    layout.add(lap());
    debugOnRebuildDirtyWidget = null;
    _watch.stop();
    ms.add(total.elapsedMicroseconds / 1000);
  }

  /// What the phase split adds to a scenario's results.
  Map<String, Object?> phaseExtras() {
    if (!_phases || ms.isEmpty) return const {};
    Map<String, double> stat(List<double> v) {
      final s = Stats(v);
      return {
        'max': _round(s.max),
        'p50': _round(s.p50),
        'total': _round(s.total),
      };
    }

    final top = rebuilt.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'phase_events': stat(events),
      'phase_build': stat(build),
      'phase_layout_paint': stat(layout),
      'rebuilt_per_frame': _round(rebuiltTotal / ms.length),
      'rebuilt_top_per_frame': {
        for (final e in top.take(12)) e.key: _round(e.value / ms.length),
      },
      'mounted_top_per_frame': {
        for (final e
            in (mounted.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(40))
          e.key: _round(e.value / ms.length),
      },
    };
  }

  /// A frame that is not part of the measurement (warm-up).
  Future<void> warm(
    WidgetTester tester, {
    Future<void> Function()? before,
  }) async {
    _wall.start();
    if (before != null) await before();
    await tester.pump(frameStep);
  }

  /// In profile mode, picks the engine's timings of the frames that started
  /// inside a measured pump. `Timeline.now` and `FrameTiming` timestamps are
  /// both microseconds on the engine's monotonic clock, and a pump awaits its
  /// frame, so a frame's vsync start falls inside the span of the pump that
  /// produced it (`frameNumber` is not used: the engine's extra frames have no
  /// pump to match). The timings reach the app in batches, so this waits for
  /// the last ones.
  Future<void> resolve() async {
    if (!profileMode) return;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    for (final t in _timings) {
      final at = t.timestampInMicroseconds(FramePhase.vsyncStart);
      if (!_spans.any((s) => at >= s.$1 && at <= s.$2)) continue;
      ms.add(t.buildDuration.inMicroseconds / 1000);
      raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
  }
}

class Stats {
  Stats(List<double> frames, {this.extra = const {}})
    : count = frames.length,
      _sorted = ([...frames]..sort());

  final int count;
  final Map<String, Object?> extra;
  final List<double> _sorted;

  double get max => _sorted.isEmpty ? 0 : _sorted.last;
  double get p50 => _percentile(0.50);
  double get p95 => _percentile(0.95);
  int get over16 => _sorted.where((v) => v > 16).length;
  int get over100 => _sorted.where((v) => v > 100).length;
  double get total => _sorted.fold(0.0, (a, b) => a + b);

  /// The mean of the three slowest frames, a steadier cousin of [max].
  double get top3 {
    if (_sorted.isEmpty) return 0;
    final top = _sorted.reversed.take(3).toList();
    return top.reduce((a, b) => a + b) / top.length;
  }

  /// Nearest-rank percentile.
  double _percentile(double p) {
    if (_sorted.isEmpty) return 0;
    final rank = (p * _sorted.length).ceil().clamp(1, _sorted.length);
    return _sorted[rank - 1];
  }

  Map<String, Object?> toJson() => {
    'max': _round(max),
    'top3': _round(top3),
    'p95': _round(p95),
    'p50': _round(p50),
    'over16': over16,
    'over100': over100,
    'frames': count,
    'total': _round(total),
    ...extra,
  };
}

double _round(double v) => (v * 100).roundToDouble() / 100;

class BenchResult {
  BenchResult(this.scenario, this.width, this.stats);
  final String scenario;
  final String width;
  final Stats stats;

  Map<String, Object?> toJson() => {
    'scenario': scenario,
    'width': width,
    ...stats.toJson(),
  };
}

/// Where a run puts its JSON; `CHAT_BENCH_OUT` overrides it.
String get resultsPath =>
    Platform.environment['CHAT_BENCH_OUT'] ?? 'build/chat_bench/results.json';

/// A regular expression that scenario ids must match to run; empty runs all.
RegExp? get scenarioFilter {
  final raw = Platform.environment['CHAT_BENCH_FILTER'];
  return raw == null || raw.isEmpty ? null : RegExp(raw);
}

final _results = <BenchResult>[];

Future<void> record(
  String scenario,
  String width,
  FrameLog log, {
  Map<String, Object?> extra = const {},
}) async {
  await log.resolve();
  // Where the slowest frames fell in the run (index among the measured ones),
  // to find the step of the script that caused them.
  final order = [for (var i = 0; i < log.ms.length; i++) i]
    ..sort((a, b) => log.ms[b].compareTo(log.ms[a]));
  final extras = {
    ...extra,
    'pumps': log.pumps,
    'slowest': [
      for (final i in order.take(3)) {'frame': i, 'ms': _round(log.ms[i])},
    ],
    ...log.phaseExtras(),
  };
  if (profileMode) {
    final r = Stats(log.raster);
    extras.addAll({
      'raster_max': _round(r.max),
      'raster_p95': _round(r.p95),
      'raster_p50': _round(r.p50),
    });
  }
  final stats = Stats(log.ms, extra: extras);
  _results.add(BenchResult(scenario, width, stats));
  // ignore: avoid_print
  print(
    '  $scenario @$width: max ${stats.max.toStringAsFixed(1)} ms, '
    'p95 ${stats.p95.toStringAsFixed(1)}, p50 ${stats.p50.toStringAsFixed(1)}, '
    '${stats.count} frames',
  );
}

Map<String, Object?> resultsJson() => {
  'mode': profileMode ? 'profile' : 'test',
  'results': [for (final r in _results) r.toJson()],
};

/// Prints the table and writes the JSON (test mode; the profile runner hands
/// [resultsJson] to the driver instead).
void writeReport() {
  final lines = <String>[
    'scenario                 width    max     top3    p95     p50    >16  >100 frames',
  ];
  String f(double v) => v.toStringAsFixed(1).padLeft(7);
  for (final r in _results) {
    final s = r.stats;
    lines.add(
      '${r.scenario.padRight(24)} ${r.width.padRight(8)} ${f(s.max)} ${f(s.top3)} '
      '${f(s.p95)} ${f(s.p50)} ${s.over16.toString().padLeft(4)} '
      '${s.over100.toString().padLeft(5)} ${s.count.toString().padLeft(6)}',
    );
  }
  // ignore: avoid_print
  print(lines.join('\n'));
  if (profileMode) return;
  final file = File(resultsPath)..createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(resultsJson()),
  );
}
