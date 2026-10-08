import 'thread_grouping_use_cases.dart';

import 'package:widgetbook/widgetbook.dart';

import 'handoff_use_cases.dart';
import 'adaptive_use_cases.dart';
import 'adaptive_chrome_use_cases.dart';
import 'app_icons_use_cases.dart';
import 'app_use_cases.dart';
import 'chat_thread_use_cases.dart';
import 'chat_use_cases.dart';
import 'conversation_window_use_cases.dart';
import 'dialogs_use_cases.dart';
import 'kanban_use_cases.dart';
import 'mac_sidebar_use_cases.dart';
import 'mac_toolbar_use_cases.dart';
import 'mcp_screen_use_cases.dart';
import 'mcp_use_cases.dart';
import 'model_use_cases.dart';
import 'palette_use_cases.dart';
import 'plugins_screen_use_cases.dart';
import 'plugins_use_cases.dart';
import 'schedules_mac_use_cases.dart';
import 'schedules_screen_use_cases.dart';
import 'settings_chrome_use_cases.dart';
import 'settings_screen_use_cases.dart';
import 'skills_messaging_use_cases.dart';
import 'state_message_use_cases.dart';
import 'busy_bar_use_cases.dart';
import 'bot_mode_roster_use_cases.dart';
import 'bot_chat_use_cases.dart';
import 'group_use_cases.dart';
import 'state_use_cases.dart';
import 'schedules_use_cases.dart';

final List<WidgetbookNode> directories = [
  handoffNode(),
  paletteNode(),
  stateMessageNode(),
  busyBarNode(),
  adaptiveChromeNode(),
  settingsChromeNode(),
  macToolbarNode(),
  appIconsNode(),
  appNode(),
  adaptiveNode(),
  dialogsNode(),
  chatNode(),
  chatThreadNode(),
  macSidebarNode(),
  threadGroupingNode(),
  conversationWindowNode(),
  modelNode(),
  kanbanNode(),
  schedulesNode(),
  schedulesScreensNode(),
  schedulesMacNode(),
  skillsMessagingNode(),
  botModeRosterNode(),
  botChatNode(),
  groupUiNode(),
  statesNode(),
  pluginsNode(),
  pluginsScreensNode(),
  mcpNode(),
  mcpScreensNode(),
  settingsScreensNode(),
];
