import 'package:widgetbook/widgetbook.dart';

import 'chat_use_cases.dart';
import 'kanban_use_cases.dart';
import 'palette_use_cases.dart';

final List<WidgetbookNode> directories = [
  paletteNode(),
  chatNode(),
  kanbanNode(),
];
