import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Coarse facts about the device, attached to every log and span.
///
/// Deliberately limited to what tells devices apart for debugging (which
/// system, roughly which version, phone or tablet) and nothing that
/// identifies a person or one device: no model, name, locale or hardware ID.
Map<String, Object> deviceAttributes() {
  try {
    return describeDevice(
      os: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      shortestSideLogical: _shortestSideLogical(),
      buildMode: kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
    );
  } catch (_) {
    return const {};
  }
}

/// The pure part of [deviceAttributes], so it can be tested for any platform.
@visibleForTesting
Map<String, Object> describeDevice({
  required String os,
  required String osVersion,
  required double? shortestSideLogical,
  required String buildMode,
}) {
  final version = _majorMinor(os, osVersion);
  final formFactor = _formFactor(os, shortestSideLogical);
  return {
    'os.type': os,
    'os.version': ?version,
    'device.form_factor': ?formFactor,
    'app.build_mode': buildMode,
  };
}

// iOS and macOS report "Version 26.0 (Build 23A344)"; other systems return a
// kernel string that is neither short nor useful, so it is left out.
String? _majorMinor(String os, String osVersion) {
  if (os != 'ios' && os != 'macos') return null;
  return RegExp(r'(\d+(?:\.\d+)?)').firstMatch(osVersion)?.group(1);
}

String? _formFactor(String os, double? shortestSide) {
  switch (os) {
    case 'macos' || 'windows' || 'linux':
      return 'desktop';
    case 'ios' || 'android':
      if (shortestSide == null || shortestSide <= 0) return null;
      return shortestSide >= 600 ? 'tablet' : 'phone';
    default:
      return null;
  }
}

double? _shortestSideLogical() {
  final view = PlatformDispatcher.instance.implicitView;
  if (view == null) return null;
  final size = view.physicalSize / view.devicePixelRatio;
  return size.shortestSide;
}
