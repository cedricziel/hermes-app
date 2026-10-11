/// The WidgetKit kinds that read the surface snapshot; the store reloads each
/// after a write. A widget's `kind` in Swift must match its name here, and a
/// new widget appends its kind.
const kSurfaceWidgetKinds = <String>[
  'HermesRecentChats',
  'HermesNeedsYou',
  'HermesBoard',
  'HermesNewChat',
  'HermesDictate',
  'HermesQuickLaunch',
];
