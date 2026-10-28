import 'voice_call_use_cases.dart';
import 'messenger_identity_use_cases.dart';
import 'reaction_use_cases.dart';
import 'billing_verification_use_cases.dart';
import 'change_invalidation_use_cases.dart';
import 'memory_proposal_use_cases.dart';
import 'memory_tool_use_cases.dart';
import 'memory_use_cases.dart';
import 'session_usage_use_cases.dart';
import 'connector_operation_use_cases.dart';
import 'side_result_use_cases.dart';
import 'process_output_use_cases.dart';
import 'agent_warning_use_cases.dart';
import 'session_state_use_cases.dart';
import 'todo_plan_use_cases.dart';
import 'activity_panel_use_cases.dart';
import 'moa_progress_use_cases.dart';
import 'background_check_status_use_cases.dart';
import 'queue_recovery_use_cases.dart';
import 'chat_suggestions_use_cases.dart';
import 'connection_use_cases.dart';
import 'thread_grouping_use_cases.dart';
import 'new_chat_fab_use_cases.dart';

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
import 'bot_screen_use_cases.dart';
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
  voiceCallNode(),
  messengerIdentityNode(),
  reactionNode(),
  changeInvalidationNode(),
  agentWarningNode(),
  sessionStateNode(),
  todoPlanNode(),
  activityPanelNode(),
  botScreenNode(),
  activityButtonNode(),
  moaProgressNode(),
  backgroundCheckStatusNode(),
  queueRecoveryNode(),
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
  memoryProposalsNode(),
  memoryToolNode(),
  sessionUsageNode(),
  connectorOperationNode(),
  sideResultNode(),
  processOutputNode(),
  billingVerificationNode(),
  chatSuggestionsNode(),
  chatThreadNode(),
  quickLookNode(),
  voiceNode(),
  macSidebarNode(),
  threadGroupingNode(),
  newChatFabNode(),
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
