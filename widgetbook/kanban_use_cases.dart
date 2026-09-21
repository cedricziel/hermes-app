import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookUseCase _card(String name, KanbanCard card) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(card, maxWidth: 320));

WidgetbookNode kanbanNode() => WidgetbookFolder(
  name: 'Kanban',
  children: [
    WidgetbookComponent(
      name: 'KanbanCard',
      useCases: [
        _card('Plain', const KanbanCard(task: plainTask)),
        _card('Busy', const KanbanCard(task: busyTask)),
        _card('Selected', const KanbanCard(task: busyTask, selected: true)),
      ],
    ),
  ],
);
