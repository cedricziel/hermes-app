import 'package:hermes_app/src/notifications/widgets/open_settings_button.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode openSettingsButtonNode() => WidgetbookComponent(
  name: 'Open settings button',
  useCases: [
    WidgetbookUseCase(
      name: 'Default',
      builder: (_) => frame(OpenSettingsButton(onPressed: () {})),
    ),
  ],
);
