import 'package:widgetbook/widgetbook.dart';

import 'app_use_cases.dart';
import 'chat_thread_use_cases.dart';
import 'chat_use_cases.dart';
import 'dialogs_use_cases.dart';
import 'kanban_use_cases.dart';
import 'mcp_screen_use_cases.dart';
import 'mcp_use_cases.dart';
import 'palette_use_cases.dart';
import 'plugins_screen_use_cases.dart';
import 'plugins_use_cases.dart';
import 'schedules_screen_use_cases.dart';
import 'skills_bots_use_cases.dart';
import 'state_use_cases.dart';
import 'schedules_use_cases.dart';

final List<WidgetbookNode> directories = [
  paletteNode(),
  appNode(),
  dialogsNode(),
  chatNode(),
  chatThreadNode(),
  kanbanNode(),
  schedulesNode(),
  schedulesScreensNode(),
  skillsBotsNode(),
  statesNode(),
  pluginsNode(),
  pluginsScreensNode(),
  mcpNode(),
  mcpScreensNode(),
];
