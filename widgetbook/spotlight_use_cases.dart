import 'package:hermes_app/src/spotlight/widgets/spotlight_settings_view.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// The Spotlight dialog on iOS, where chats can be added to system search.
WidgetbookNode spotlightNode() => WidgetbookFolder(
  name: 'Spotlight',
  children: [
    WidgetbookComponent(
      name: 'Settings dialog',
      useCases: [
        for (final on in [false, true])
          WidgetbookUseCase(
            name: on ? 'On' : 'Off (default)',
            builder: (_) => fill(
              GroupedDialog(
                title: 'Spotlight',
                children: [
                  SpotlightSettingsView(enabled: on, onChanged: (_) {}),
                ],
              ),
            ),
          ),
      ],
    ),
  ],
);
