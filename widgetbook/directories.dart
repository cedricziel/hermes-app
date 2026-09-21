import 'package:widgetbook/widgetbook.dart';

import 'chat_use_cases.dart';
import 'kanban_use_cases.dart';
import 'mcp_screen_use_cases.dart';
import 'mcp_use_cases.dart';
import 'palette_use_cases.dart';
import 'plugins_screen_use_cases.dart';
import 'plugins_use_cases.dart';
import 'schedules_screen_use_cases.dart';
import 'schedules_use_cases.dart';

final List<WidgetbookNode> directories = [
  paletteNode(),
  chatNode(),
  kanbanNode(),
  schedulesNode(),
  schedulesScreensNode(),
  pluginsNode(),
  pluginsScreensNode(),
  mcpNode(),
  mcpScreensNode(),
];
