import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_back_button.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:widgetbook/widgetbook.dart';

/// Phone is iOS and Desktop is macOS in this catalog, so each viewport shows
/// that platform's bar; Android is covered by the widget tests.
WidgetbookNode adaptiveChromeNode() => WidgetbookComponent(
  name: 'Adaptive bars',
  useCases: [
    WidgetbookUseCase(
      name: 'Detail bar with back and tabs',
      builder: (_) => const _Pushed(),
    ),
  ],
);

class _Pushed extends StatelessWidget {
  const _Pushed();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const _Detail())),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const AdaptiveBackButton(previousTitle: 'Skills'),
          leadingWidth: adaptiveBackLeadingWidth(context),
          title: const Text('Plugins'),
          bottom: const AdaptiveTabBar(labels: ['Installed', 'Catalog']),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Installed')),
            Center(child: Text('Catalog')),
          ],
        ),
      ),
    );
  }
}
