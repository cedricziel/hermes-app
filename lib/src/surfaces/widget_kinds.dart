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

/// The kinds that read only whether anyone is signed in, so a write reloads
/// them only when that flips: WidgetKit budgets reloads, and a chat list or
/// request change says nothing to them.
const kSignedInOnlyWidgetKinds = <String>{
  'HermesNewChat',
  'HermesDictate',
  'HermesQuickLaunch',
};
