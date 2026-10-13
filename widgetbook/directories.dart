import 'memory_use_cases.dart';
import 'agent_warning_use_cases.dart';
import 'session_state_use_cases.dart';
import 'background_check_status_use_cases.dart';
import 'chat_suggestions_use_cases.dart';
import 'connection_use_cases.dart';
import 'thread_grouping_use_cases.dart';

import 'package:widgetbook/widgetbook.dart';

import 'grouped_form_use_cases.dart';
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
import 'kanban_form_use_cases.dart';
import 'mac_sidebar_use_cases.dart';
import 'mac_toolbar_use_cases.dart';
import 'mcp_screen_use_cases.dart';
import 'mcp_use_cases.dart';
import 'model_use_cases.dart';
import 'palette_use_cases.dart';
import 'platform_hint_use_cases.dart';
import 'plugins_screen_use_cases.dart';
import 'plugins_use_cases.dart';
import 'quick_look_use_cases.dart';
import 'quick_panel_use_cases.dart';
import 'schedules_mac_use_cases.dart';
import 'schedules_screen_use_cases.dart';
import 'settings_chrome_use_cases.dart';
import 'settings_screen_use_cases.dart';
import 'messaging_use_cases.dart';
import 'skills_messaging_use_cases.dart';
import 'skills_use_cases.dart';
import 'state_message_use_cases.dart';
import 'busy_bar_use_cases.dart';
import 'menu_bar_extra_use_cases.dart';
import 'spotlight_use_cases.dart';
import 'bot_mode_roster_use_cases.dart';
import 'bot_chat_use_cases.dart';
import 'group_use_cases.dart';
import 'state_use_cases.dart';
import 'schedules_use_cases.dart';
import 'voice_use_cases.dart';

final List<WidgetbookNode> directories = [
  agentWarningNode(),
  sessionStateNode(),
  backgroundCheckStatusNode(),
  connectionNode(),
  handoffNode(),
  paletteNode(),
  stateMessageNode(),
  busyBarNode(),
  platformHintNode(),
  adaptiveChromeNode(),
  settingsChromeNode(),
  groupedFormNode(),
  macToolbarNode(),
  menuBarExtraNode(),
  spotlightNode(),
  appIconsNode(),
  appNode(),
  adaptiveNode(),
  dialogsNode(),
  chatNode(),
  memoryNode(),
  chatSuggestionsNode(),
  chatThreadNode(),
  quickLookNode(),
  voiceNode(),
  macSidebarNode(),
  threadGroupingNode(),
  conversationWindowNode(),
  quickPanelNode(),
  modelNode(),
  kanbanNode(),
  kanbanFormFieldsNode(),
  schedulesNode(),
  schedulesScreensNode(),
  schedulesMacNode(),
  skillsMessagingNode(),
  skillsNode(),
  messagingNode(),
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
