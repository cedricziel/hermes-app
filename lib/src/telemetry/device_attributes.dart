import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Facts about the device, attached to every log and span.
///
/// Limited to what tells devices apart for debugging: which system and
/// version, the hardware model (an identifier shared by every unit of it, such
/// as `iPhone17,1`), and phone or tablet. Nothing that identifies a person or
/// one device: no device name, vendor or hardware ID, locale, disk or memory
/// sizes, or build fingerprint.
Future<Map<String, Object>> deviceAttributes({DeviceInfoPlugin? plugin}) async {
  final Map<String, Object> basics;
  try {
    basics = describeDevice(
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
  try {
    return {...basics, ...await _hardware(plugin ?? DeviceInfoPlugin())};
  } catch (_) {
    // No plugin in tests, or the platform refused; the basics still stand.
    return basics;
  }
}

Future<Map<String, Object>> _hardware(DeviceInfoPlugin plugin) async {
  switch (Platform.operatingSystem) {
    case 'ios':
      final info = await plugin.iosInfo;
      return describeApple(
        family: info.model,
        identifier: info.utsname.machine,
        simulator: !info.isPhysicalDevice,
        iosAppOnMac: info.isiOSAppOnMac,
      );
    case 'macos':
      final info = await plugin.macOsInfo;
      return describeApple(identifier: info.model, arch: info.arch);
    case 'android':
      final info = await plugin.androidInfo;
      return describeAndroid(
        manufacturer: info.manufacturer,
        model: info.model,
        release: info.version.release,
        apiLevel: info.version.sdkInt,
        simulator: !info.isPhysicalDevice,
      );
    default:
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

/// What an iPhone, iPad or Mac reports. [family] is the marketing family
/// (`iPhone`, `iPad`), which says phone or tablet more reliably than the
/// screen does.
@visibleForTesting
Map<String, Object> describeApple({
  String? family,
  required String identifier,
  String? arch,
  bool? simulator,
  bool? iosAppOnMac,
}) {
  final formFactor = switch (family?.toLowerCase()) {
    final f? when f.startsWith('ipad') => 'tablet',
    final f? when f.startsWith('iphone') || f.startsWith('ipod') => 'phone',
    _ => null,
  };
  return {
    'device.manufacturer': 'Apple',
    'device.model.identifier': identifier,
    'device.form_factor': ?formFactor,
    'host.arch': ?arch,
    'device.simulator': ?simulator,
    'app.ios_app_on_mac': ?iosAppOnMac,
  };
}

@visibleForTesting
Map<String, Object> describeAndroid({
  required String manufacturer,
  required String model,
  required String release,
  required int apiLevel,
  required bool simulator,
}) => {
  'device.manufacturer': manufacturer,
  'device.model.identifier': model,
  'os.version': release,
  'android.os.api_level': apiLevel,
  'device.simulator': simulator,
};

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
