import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_kinds.dart';

const _reportedAtKey = 'hermes.widgets.reported_at';
const _reportEvery = Duration(hours: 24);

/// Says, at most once a day, which Home Screen widgets are installed. The
/// widget extension has no telemetry of its own, so this is the only way to
/// learn whether anyone uses them. It logs kinds, families and counts only.
class WidgetUsageReporter {
  WidgetUsageReporter({
    this.events = noopAppEventLogger,
    SharedPreferencesAsync? prefs,
    DateTime Function()? clock,
    List<String>? androidKinds,
  }) : _androidKinds = androidKinds ?? kAndroidWidgetKinds,
       _prefs = prefs ?? SharedPreferencesAsync(),
       _clock = clock ?? DateTime.now;

  final AppEventLogger events;
  final SharedPreferencesAsync _prefs;
  final DateTime Function() _clock;
  final List<String> _androidKinds;

  /// Logs `widgets.installed` unless it did within the last 24 hours. Never
  /// throws; a plugin that fails is tried again on the next start.
  Future<void> report() async {
    try {
      final now = _clock();
      final last = await _prefs.getInt(_reportedAtKey);
      if (last != null &&
          now.difference(
                DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
              ) <
              _reportEvery) {
        return;
      }
      final counts = <String, int>{};
      final platform = defaultTargetPlatform;
      final known = platform == TargetPlatform.android
          ? _androidKinds
          : kSurfaceWidgetKinds;
      for (final widget in await HomeWidget.getInstalledWidgets()) {
        // Android reports the provider's short class name (`.HermesBoard`).
        final (kind, family) = platform == TargetPlatform.android
            ? (
                widget.androidClassName?.replaceFirst(RegExp(r'^\.'), ''),
                'android',
              )
            : (widget.iOSKind, widget.iOSFamily);
        if (!known.contains(kind)) continue;
        final key = '$kind/$family';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final kinds = counts.keys.toList()..sort();
      events('widgets.installed', {
        'widgets.count': counts.values.fold<int>(0, (a, b) => a + b),
        'widgets.kinds': [for (final key in kinds) '$key=${counts[key]}']
            .join(','),
      });
      await _prefs.setInt(_reportedAtKey, now.toUtc().millisecondsSinceEpoch);
    } on Object {
      // Telemetry must not break the app.
    }
  }
}
