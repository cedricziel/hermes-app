import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode newChatFabNode() => WidgetbookComponent(
  name: 'NewChatFab',
  useCases: [
    WidgetbookUseCase(
      name: 'Ready',
      builder: (_) => frame(NewChatFab(onPressed: () {})),
    ),
  ],
);
