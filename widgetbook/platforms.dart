import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

const _platforms = {
  'iPhone': TargetPlatform.iOS,
  'Mac': TargetPlatform.macOS,
  'Material': TargetPlatform.android,
};

/// One use case per platform, named after the state and the platform, so
/// the catalog shows the iPhone, Mac and Material look of the same state.
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

/// [page] pushed over a "Chat" page, so its bar has a back button.
class PushedPage extends StatelessWidget {
  const PushedPage(this.page, {super.key});

  final Widget page;

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateInitialRoutes: (_, _) => [
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Chat'))),
      ),
      MaterialPageRoute<void>(builder: (_) => page),
    ],
  );
}
