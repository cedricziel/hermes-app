import 'package:hermes_app/src/notifications/widgets/open_settings_button.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode openSettingsButtonNode() => WidgetbookComponent(
  name: 'Open settings button',
  useCases: [
    ...onEachPlatform(
      'Default',
      (_) => frame(
        GroupedSection(
          children: [
            GroupedSwitchRow(
              title: 'Notify me',
              warning: 'Turn on notifications for Hermes in system settings.',
              value: true,
              onChanged: (_) {},
            ),
            OpenSettingsButton(onPressed: () {}),
          ],
        ),
      ),
    ),
  ],
);
