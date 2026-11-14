import 'package:flutter/foundation.dart' show TargetPlatform;

/// The WidgetKit kinds that read the surface snapshot; the store reloads each
/// after a write. A widget's `kind` in Swift must match its name here, and a
/// new widget appends its kind. A kind that also has an Android provider joins
/// [kAndroidWidgetKinds] too.
const kSurfaceWidgetKinds = <String>[
  'HermesRecentChats',
  'HermesNeedsYou',
  'HermesBoard',
  'HermesNewChat',
  'HermesDictate',
  'HermesQuickLaunch',
];

/// The kinds that read only whether anyone is signed in, so a write reloads
/// them only when that flips: WidgetKit budgets reloads, and a chat list or
/// request change says nothing to them.
const kSignedInOnlyWidgetKinds = <String>{
  'HermesNewChat',
  'HermesDictate',
  'HermesQuickLaunch',
};

/// The kinds with an Android `AppWidgetProvider`: a receiver in the app's root
/// package named like the iOS kind, which is what `updateWidget` resolves and
/// `getInstalledWidgets` reports. Empty until the first Android widget ships;
/// the store asks Android to reload only these, since a kind with no provider
/// class makes the plugin answer error -3.
const kAndroidWidgetKinds = <String>[];

/// The kinds the store reloads and the usage report counts on [platform].
List<String> surfaceWidgetKindsFor(TargetPlatform platform) =>
    platform == TargetPlatform.android
    ? kAndroidWidgetKinds
    : kSurfaceWidgetKinds;
