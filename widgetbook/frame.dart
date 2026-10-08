import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// Places a widget the way a chat thread or a board column would: a bounded
/// column at the top left, in a list, so its height is not stretched.
Widget frame(Widget child, {double maxWidth = 480}) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  ),
);

/// Places a screen-sized widget (a sidebar, an empty state) in the space the
/// viewport gives it, since a scrolling frame would leave it unbounded.
Widget fill(Widget child, {double? width}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: width, child: child),
);

const _platforms = {
  'iPhone': TargetPlatform.iOS,
  'Mac': TargetPlatform.macOS,
  'Material': TargetPlatform.android,
};

/// One use case per platform, named after the state and the platform.
List<WidgetbookUseCase> onEachPlatform(
  String state,
  Widget Function(BuildContext context) builder,
) => [
  for (final MapEntry(key: name, value: platform) in _platforms.entries)
    WidgetbookUseCase(
      name: '$state ($name)',
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(platform: platform),
        child: Builder(builder: builder),
      ),
    ),
];

/// Shows [page] pushed over another route, so it has a back button.
Widget pushed(Widget page) => Navigator(
  onGenerateInitialRoutes: (_, _) => [
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('Chat'))),
    ),
    MaterialPageRoute<void>(builder: (_) => page),
  ],
);
