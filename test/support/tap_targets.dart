import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Measures tap targets for the report in `test/tap_targets/`. It walks the
/// semantics tree the way flutter_test's tap-target guidelines do, but keeps
/// going after the first failure, so every undersized target is listed.
///
/// Limits shared with the guidelines: nodes merged into a parent are not
/// targets of their own, a node touching the edge of the window or of a
/// scrollable is skipped (it may be scrolled half out of view), links are
/// skipped, and only what is mounted counts (a list's lazy rows below the fold,
/// a closed menu or a dialog that is not open are not measured).
const tapReportVariable = 'HERMES_TAP_REPORT';

bool get tapReportEnabled => Platform.environment[tapReportVariable] == '1';

/// Where the reports go. Override with `HERMES_TAP_DIR`.
String get tapReportDir =>
    Platform.environment['HERMES_TAP_DIR'] ?? 'build/tap_targets';

/// Smallest tap target a platform accepts, in logical pixels.
const tapThresholds = {'android': 48.0, 'ios': 44.0, 'macos': 28.0};

class TapTarget {
  const TapTarget({
    required this.label,
    required this.width,
    required this.height,
    required this.labeled,
    this.left = 0,
    this.top = 0,
  });

  factory TapTarget.fromJson(Map<String, Object?> json) => TapTarget(
    label: json['label']! as String,
    width: (json['w']! as num).toDouble(),
    height: (json['h']! as num).toDouble(),
    labeled: json['labeled']! as bool,
    left: (json['x'] as num?)?.toDouble() ?? 0,
    top: (json['y'] as num?)?.toDouble() ?? 0,
  );

  /// The node's label, else its tooltip or value, else `(no label)`.
  final String label;
  final double width;
  final double height;

  /// Whether the node has a label or tooltip, as `labeledTapTargetGuideline`
  /// asks.
  final bool labeled;

  /// Where the node's top left sits in the window, in logical pixels.
  final double left;
  final double top;

  String get size => '${_fmt(width)}x${_fmt(height)}';

  Map<String, Object?> toJson() => {
    'label': label,
    'w': width,
    'h': height,
    'labeled': labeled,
    'x': left,
    'y': top,
  };
}

String _fmt(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

/// Every tap or long-press target on screen. Semantics must be enabled
/// (`tester.ensureSemantics()`) and a frame pumped.
List<TapTarget> collectTapTargets(WidgetTester tester) {
  final out = <TapTarget>[];
  for (final RenderView view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) _walk(view.flutterView, root, out);
  }
  return out;
}

void _walk(ui.FlutterView view, SemanticsNode node, List<TapTarget> out) {
  node.visitChildren((child) {
    _walk(view, child, out);
    return true;
  });
  if (node.isMergedIntoParent) return;
  final data = node.getSemanticsData();
  final flags = data.flagsCollection;
  if (flags.isHidden) return;
  if (!data.hasAction(ui.SemanticsAction.tap) &&
      !data.hasAction(ui.SemanticsAction.longPress)) {
    return;
  }
  final labeled = data.label.isNotEmpty || data.tooltip.isNotEmpty;
  final name = data.label.isNotEmpty
      ? data.label
      : data.tooltip.isNotEmpty
      ? data.tooltip
      : data.value.isNotEmpty
      ? data.value
      : '(no label)';
  final label = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  final shortLabel = label.length > 60 ? '${label.substring(0, 57)}...' : label;

  if (flags.isLink || flags.isTextField || node.isInvisible) {
    return;
  }
  var bounds = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final transform = current.transform;
    if (transform != null) {
      bounds = MatrixUtils.transformRect(transform, bounds);
    }
    if (current.flagsCollection.hasImplicitScrolling &&
        _atBoundary(bounds, current.rect)) {
      return;
    }
    current = current.parent;
  }
  final viewRect = Offset.zero & view.physicalSize;
  // A collapsed or off-screen node is not something a person can tap.
  if (bounds.width <= 0 || bounds.height <= 0 || !bounds.overlaps(viewRect)) {
    return;
  }
  if (_atBoundary(bounds, viewRect)) return;
  final size = bounds.size / view.devicePixelRatio;
  out.add(
    TapTarget(
      label: shortLabel,
      width: size.width,
      height: size.height,
      labeled: labeled,
      left: bounds.left / view.devicePixelRatio,
      top: bounds.top / view.devicePixelRatio,
    ),
  );
}

bool _atBoundary(Rect child, Rect parent) =>
    !(child.left - parent.left > 0.001 &&
        parent.right - child.right > 0.001 &&
        child.top - parent.top > 0.001 &&
        parent.bottom - child.bottom > 0.001);

/// One screen measured: what it was, which platform's minimum judges it, and
/// its targets.
class TapSample {
  const TapSample(
    this.source,
    this.platform,
    this.targets, [
    this.rendered,
    this.reason,
  ]);

  factory TapSample.fromJson(Map<String, Object?> json) => TapSample(
    json['source']! as String,
    json['platform']! as String,
    [
      for (final t in json['targets']! as List)
        TapTarget.fromJson((t as Map).cast<String, Object?>()),
    ],
    json['rendered'] as String?,
    json['reason'] as String?,
  );

  final String source;

  /// `android`, `ios` or `macos`: the minimum that judges this screen; `skip`
  /// when the screen ran as a platform none of them covers.
  final String platform;
  final List<TapTarget> targets;

  /// The platform the theme was built for, when it is not the judged one.
  final String? rendered;

  /// Why a skipped pass was not judged, e.g. `pins android`.
  final String? reason;

  bool get skipped => platform == 'skip';

  Map<String, Object?> toJson() => {
    'source': source,
    'platform': platform,
    if (rendered != null) 'rendered': rendered,
    if (reason != null) 'reason': reason,
    'targets': [for (final t in targets) t.toJson()],
  };
}

String platformKey(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android || TargetPlatform.fuchsia => 'android',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => 'macos',
};

/// From this logical width a screen is a desktop window, judged by the macOS
/// minimum whatever the theme platform is.
const desktopWidth = 700.0;

/// The minimum that judges a workflow screen: macOS for a desktop-sized
/// window; on a phone, the platform the theme was built for when that is
/// Android or iOS, else `skip` (it is not a platform a phone runs).
String judgedPlatform(TargetPlatform rendered, double width) {
  if (width >= desktopWidth) return 'macos';
  return switch (rendered) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'skip',
  };
}

/// The platform key a use case pins, when one of [themePlatforms] (the
/// `Theme.data.platform` of every `Theme` it builds) is judged by a different
/// minimum than [pass]; null when it pins nothing or only the pass platform.
String? pinnedPlatform(
  Iterable<TargetPlatform> themePlatforms,
  TargetPlatform pass,
) {
  final passKey = platformKey(pass);
  for (final p in themePlatforms) {
    final key = platformKey(p);
    if (key != passKey) return key;
  }
  return null;
}

/// The platforms of every `Theme` below the app's own, read from the element
/// tree of the pumped use case.
List<TargetPlatform> themePlatformsOf(WidgetTester tester) {
  final out = <TargetPlatform>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Theme) out.add(w.data.platform);
    e.visitChildren(visit);
  }

  tester.binding.rootElement?.visitChildren(visit);
  return out;
}

/// Measures what is on screen now. Semantics are switched on for the call.
Future<TapSample> measureScreen(
  WidgetTester tester,
  String source,
  String platform, [
  String? rendered,
]) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    return TapSample(source, platform, collectTapTargets(tester), rendered);
  } finally {
    handle.dispose();
  }
}

/// Called by the workflow screenshots when `HERMES_TAP_REPORT=1`: measures the
/// screen and appends it to the flow's file. The screen is judged by the
/// platform its theme was built for (what `WORKFLOW_PLATFORM` or the test's
/// `platform:` set; Android when neither did) on a phone, and by the macOS
/// minimum when the window is desktop-sized.
Future<void> recordWorkflowScreen(
  WidgetTester tester,
  String flow,
  String step,
) async {
  var rendered = defaultTargetPlatform;
  try {
    rendered = Theme.of(tester.element(find.byType(Scaffold).first)).platform;
  } on Object {
    // No Scaffold on screen: the test's own platform stands.
  }
  final view = tester.view;
  final width = view.physicalSize.width / view.devicePixelRatio;
  final sample = await measureScreen(
    tester,
    '$flow/$step',
    judgedPlatform(rendered, width),
    rendered.name,
  );
  final file = File('$tapReportDir/workflows/$flow.jsonl');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${jsonEncode(sample.toJson())}\n',
    mode: FileMode.append,
  );
}

List<TapSample> readWorkflowSamples() {
  final dir = Directory('$tapReportDir/workflows');
  if (!dir.existsSync()) return [];
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      for (final line in f.readAsLinesSync())
        if (line.isNotEmpty)
          TapSample.fromJson((jsonDecode(line) as Map).cast<String, Object?>()),
  ];
}

/// `chat-phone-dark/03-x` and `chat-phone/03-x` are one screen: the theme
/// suffix of the flow is dropped.
String stripTheme(String source) =>
    source.replaceFirstMapped(RegExp(r'^([^/]*?)-(dark|light)(?=/)'), (m) {
      return m[1]!;
    });

/// A target that failed a rule, with where it was seen.
class TapFinding {
  const TapFinding(this.platform, this.source, this.target);
  final String platform;
  final String source;
  final TapTarget target;

  /// The identity of a finding for counting: the same control on the same
  /// screen in both themes is one (same place, rounded to 1 px), two equal
  /// controls at different places are two.
  String get key =>
      '$platform  ${stripTheme(source)}  ${target.label}  '
      '${target.size}  @${target.left.round()},${target.top.round()}';

  Map<String, Object?> toJson() => {
    'platform': platform,
    'source': source,
    'label': target.label,
    'size': target.size,
    'w': target.width,
    'h': target.height,
  };
}

const _eps = 1e-3;

/// Whether a macOS target is exactly the 44 or 48 pt a Material control is
/// stretched to (`kMinInteractiveDimension`), which a pointer does not need.
bool isInflated(TapTarget t) {
  bool exact(double v) => (v - 44).abs() < _eps || (v - 48).abs() < _eps;
  return exact(t.width) || exact(t.height);
}

class TapReport {
  TapReport(this.samples);

  final List<TapSample> samples;

  Iterable<TapSample> get _judged => samples.where((s) => !s.skipped);

  Iterable<TapFinding> _findings(
    bool Function(TapSample, TapTarget) test,
  ) sync* {
    for (final s in _judged) {
      for (final t in s.targets) {
        if (test(s, t)) yield TapFinding(s.platform, s.source, t);
      }
    }
  }

  /// Every render's findings, theme repeats included.
  List<TapFinding> rawViolations(String platform) => _findings(
    (s, t) =>
        s.platform == platform &&
        (t.width < tapThresholds[platform]! - _eps ||
            t.height < tapThresholds[platform]! - _eps),
  ).toList();

  List<TapFinding> rawUnlabeled() => _findings((s, t) => !t.labeled).toList();

  List<TapFinding> rawInflated() =>
      _findings((s, t) => s.platform == 'macos' && isInflated(t)).toList();

  /// One finding per (platform, screen without its theme suffix, label, size,
  /// position),
  /// in a stable order.
  List<TapFinding> distinct(List<TapFinding> findings) {
    final byKey = <String, TapFinding>{};
    for (final f in findings) {
      byKey.putIfAbsent(f.key, () => f);
    }
    return byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  List<TapFinding> violations(String platform) =>
      distinct(rawViolations(platform));
  List<TapFinding> unlabeled() => distinct(rawUnlabeled());
  List<TapFinding> inflated() => distinct(rawInflated());

  /// Controls by label and size over distinct findings, most screens first:
  /// the shared widget behind many findings shows up on top.
  List<MapEntry<String, int>> topOffenders(List<TapFinding> findings, int n) {
    final out = <String, int>{};
    for (final f in findings) {
      final key = '${f.target.label}  ${f.target.size}';
      out[key] = (out[key] ?? 0) + 1;
    }
    final list = out.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return list.take(n).toList();
  }

  Map<String, int> get skippedByPlatform {
    final out = <String, int>{};
    for (final s in samples.where((s) => s.skipped && s.reason == null)) {
      out[s.rendered ?? '?'] = (out[s.rendered ?? '?'] ?? 0) + 1;
    }
    return out;
  }

  /// Passes not judged because the use case pins another platform, by reason.
  Map<String, int> get skippedPasses {
    final out = <String, int>{};
    for (final s in samples.where((s) => s.reason != null)) {
      out[s.reason!] = (out[s.reason!] ?? 0) + 1;
    }
    return out;
  }

  Map<String, Object?> toJson({required Map<String, Object?> meta}) => {
    'schema': 2,
    ...meta,
    'thresholds': tapThresholds,
    'screensMeasured': _judged.length,
    'screensSkipped': skippedByPlatform,
    'passesSkipped': skippedPasses,
    'targetsMeasured': _judged.fold<int>(0, (n, s) => n + s.targets.length),
    // Distinct (platform, screen, label, size): the number to climb down.
    'totals': {
      for (final p in tapThresholds.keys) p: violations(p).length,
      'unlabeled': unlabeled().length,
      'macosInflated': inflated().length,
    },
    // Per render, theme repeats included.
    'rawTotals': {
      for (final p in tapThresholds.keys) p: rawViolations(p).length,
      'unlabeled': rawUnlabeled().length,
      'macosInflated': rawInflated().length,
    },
    'topLabels': {
      for (final p in tapThresholds.keys)
        p: [
          for (final e in topOffenders(violations(p), 15))
            {'label': e.key, 'screens': e.value},
        ],
    },
    'violations': {
      for (final p in tapThresholds.keys)
        p: [for (final f in violations(p)) f.toJson()],
    },
    'unlabeled': [for (final f in unlabeled()) f.toJson()],
    'macosInflated': [for (final f in inflated()) f.toJson()],
  };

  String summary({int top = 15}) {
    final b = StringBuffer()
      ..writeln(
        'Tap targets: ${_judged.length} screens judged, '
        '${_judged.fold<int>(0, (n, s) => n + s.targets.length)} targets '
        '(distinct count, raw per-render count in brackets)',
      );
    for (final p in tapThresholds.keys) {
      b.writeln(
        '  $p (< ${tapThresholds[p]!.toStringAsFixed(0)}): '
        '${violations(p).length} [${rawViolations(p).length}]',
      );
    }
    b.writeln(
      '  unlabeled tap targets: ${unlabeled().length} [${rawUnlabeled().length}]',
    );
    b.writeln(
      '  macOS inflated to 44/48: ${inflated().length} [${rawInflated().length}]',
    );
    if (skippedPasses.isNotEmpty) {
      b.writeln('  skipped passes (use case pins a platform): $skippedPasses');
    }
    if (skippedByPlatform.isNotEmpty) {
      b.writeln('  skipped screens by rendered platform: $skippedByPlatform');
    }
    for (final p in tapThresholds.keys) {
      b.writeln('\nTop $p labels (screens  label  size)');
      for (final e in topOffenders(violations(p), top)) {
        b.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
      }
    }
    b.writeln('\nTop unlabeled (screens  size)');
    for (final e in topOffenders(unlabeled(), top)) {
      b.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
    }
    return b.toString();
  }
}
