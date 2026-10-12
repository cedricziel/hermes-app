# Navigation and presentation source inventory

Source inspection on 2026-10-12. This inventory supports [the implementation checklist](platform-navigation-todo.md); it records code branches, not verified device behavior.

## Platform and input branches

| Interaction | iOS/iPadOS | macOS | Android, Windows, Linux | Source |
| --- | --- | --- | --- | --- |
| Shared row actions | Swipe destructive actions; long-press action sheet; semantic actions | Secondary-click menu; semantic actions | Wrapper returns the original child; child controls vary | `lib/src/widgets/row_actions.dart` |
| Thread rows | Swipe pin/delete and long-press actions | Dedicated source-list row, context menu, hover actions, drag-out | Inline menu with long-press and secondary tap | `lib/src/chat/widgets/thread_sidebar.dart` |
| Card dragging | Wide cards use touch/stylus delayed drag or immediate mouse/trackpad drag; compact cards use selection and handle | Columns at every width; immediate mouse/trackpad dragging, delayed touch/stylus dragging | Wide cards distinguish pointer devices; compact cards use selection and handle | `lib/src/kanban/kanban_screen.dart`, `lib/src/kanban/widgets/kanban_card_drag.dart` |
| Main destinations | Sidebar or drawer according to layout | Mac sidebar/source-list rows | Sidebar or drawer according to layout | `lib/src/shell/app_shell.dart`, `lib/src/shell/shell_navigation.dart` |
| Detail Back | Route Back with dirty/busy guards | Toolbar and `⌘[` on settings screens, with route guards | Route/system Back with guards | `lib/src/widgets/settings_scaffold.dart`, `lib/src/widgets/adaptive_back_button.dart` |
| Page motion | Framework default | Explicit 150 ms stationary fade; reduced motion shows page content immediately | Framework default | `lib/src/theme/hermes_theme.dart` |
| Tabs | Cupertino sliding segmented control plus TabBarView | Cupertino sliding segmented control plus TabBarView | Material pill control plus TabBarView | `lib/src/widgets/adaptive_tab_bar.dart` |

An iPad with a mouse currently retains the iOS row-action branch. Audit pointer menus before changing that behavior. Kanban distinguishes input devices directly, while general layout width controls its compact non-Mac interaction.

macOS Kanban deliberately keeps columns at every width. Its task inspector is docked at sufficient width and overlays from the right below its breakpoint. Preserve that behavior from `openspec/specs/kanban/spec.md`.

The repository has Android, iOS, macOS, Windows, and Linux app targets. Web is generated temporarily for the Widgetbook catalog by `scripts/build-widgetbook.sh`, not offered as a web app.

## Route-push owners

| Feature | Files |
| --- | --- |
| Chat tools and connection | `lib/src/chat/chat_screen.dart` |
| Skills | `lib/src/skills/skills_screen.dart`, `lib/src/skills/skill_detail_screen.dart` |
| Profiles | `lib/src/profiles/mac_profiles_page.dart` |
| Bots and groups | `lib/src/bot_mode/bot_mode_roster_screen.dart`, `lib/src/bot_mode/groups/group_rooms_panel.dart`, `lib/src/bot_mode/groups/group_chat_screen.dart` |
| Schedules | `lib/src/schedules/schedules_screen.dart`, `lib/src/schedules/schedule_detail.dart`, `lib/src/schedules/blueprint_screens.dart` |
| Kanban | `lib/src/kanban/kanban_screen.dart` |
| MCP | `lib/src/mcp/mcp_servers_screen.dart`, `lib/src/mcp/mcp_server_detail.dart`, `lib/src/mcp/mcp_catalog_screen.dart` |
| Messaging | `lib/src/messaging/messaging_screen.dart`, `lib/src/messaging/messaging_setup_screen.dart` |
| Account | `lib/src/settings/account_actions.dart` |
| Shell group chat | `lib/src/shell/app_shell.dart` |
| Attachments | `lib/src/chat/widgets/attachment_views.dart` |

Main, conversation, and quick-panel apps have separate MaterialApp instances. Auxiliary windows reuse ChatScreen functionality; their navigation must remain bound to their own window.

## Modal migration groups

| Group | Source files and current presentation | Follow-up |
| --- | --- | --- |
| Shared adaptive sheet | `lib/src/widgets/adaptive_sheet.dart` chooses Material dialog or bottom sheet by width. Called by `lib/src/platform_hint/show_platform_hint_prompt.dart` and `lib/src/mcp/mcp_command_review.dart`. | Add platform-aware route presentation while retaining guard, result, and focus behavior. |
| Plugin details | `lib/src/plugins/catalog_tab.dart`, `lib/src/plugins/installed_tab.dart`: panes on wide layouts, bottom sheets on compact layouts. `lib/src/plugins/plugins_screen.dart` uses a dialog for installation; `lib/src/plugins/install_report.dart` uses an adaptive dialog. | Review compact desktop details and installation presentation. |
| MCP details | `lib/src/mcp/mcp_catalog_screen.dart`: pane or bottom sheet. Setup/editor/sign-in route pushes live in the files listed above. | Preserve already migrated setup/editor work; fix remaining presentation only. |
| Skill jobs | `lib/src/skills/skill_job_sheet.dart`: bottom sheet. | Reconcile with adaptive Skill details/status work merged in PR #643 before changing presentation. |
| Kanban details and logs | `lib/src/kanban/widgets/kanban_task_panel.dart`: Apple detent/form sheets for the task-detail helper; direct dialogs for log/edit/assignee/priority. `lib/src/kanban/widgets/task_panel/kanban_task_sheet.dart` implements detent/form helpers. Normal macOS board picks use the inspector. | Preserve inspector and iOS detents; review secondary dialogs and helper routes. |
| Kanban administration | `lib/src/kanban/kanban_boards_screen.dart`, `lib/src/kanban/widgets/kanban_bulk_bar.dart`, `lib/src/kanban/kanban_screen.dart`: direct dialogs. `lib/src/kanban/kanban_workers_screen.dart`, `lib/src/kanban/kanban_errors.dart`: adaptive dialogs. | Split board import/export and bulk actions into small changes. |
| Pickers | `lib/src/models/widgets/model_picker.dart`: dialog or bottom sheet. `lib/src/chat/attachments/attachment_surface.dart`: origin bottom sheet. `lib/src/widgets/adaptive_pickers.dart`: Cupertino modal popup. | Review platform, input, and keyboard behavior together. |
| Settings and profile creation | `lib/src/settings/settings_dialog.dart`, `lib/src/settings/appearance_dialog.dart`, `lib/src/settings/about_dialog.dart`, `lib/src/profiles/widgets/new_profile_dialog.dart`: direct dialogs. | Adapt presentation without changing preferences or profile logic. |
| Device settings | `lib/src/notifications/notifications_dialog.dart`, `lib/src/voice/dictation_dialog.dart`, `lib/src/spotlight/spotlight_dialog.dart`, `lib/src/app_lock/app_lock_dialog.dart`: direct dialogs. | Review route animation and dismissal safeguards. |
| Bot/group confirmations | `lib/src/bot_mode/bot_mode_roster_screen.dart`, `lib/src/bot_mode/groups/group_chat_screen.dart`: direct dialogs. | Preserve destructive confirmation and busy guards. |
| Thread and row menus | `lib/src/chat/widgets/thread_actions_menu.dart`: adaptive rename dialog. `lib/src/widgets/row_actions.dart`, `lib/src/chat/widgets/swipeable_thread_row.dart`: Cupertino action sheets; shared adaptive popup menus elsewhere. | Review context menus separately from page and dialog transitions. |

## Authentication boundary finding

`lib/src/app.dart` keeps a stable Navigator while `_RootRouter` replaces the home content for authentication state changes. A pushed detail/editor route can remain above the new Login/Setup screen. `lib/src/settings/account_actions.dart` confirms sign-out but does not reset the stack. App Lock hides mounted content; the Handoff gate blocks input, and neither performs authentication teardown.

Cover old-session content immediately when the session is invalidated. Explicit sign-out and server change must clear old screens. Session-expiry draft recovery needs an explicit policy and same-account checks before anything is restored. Add app-level navigation tests, including delayed token cleanup, rather than relying only on AuthController tests.

## Regenerate the inventory

Run these searches from the repository root, then inspect platform/layout guards around each match:

```sh
rg -n 'Navigator\.|MaterialPageRoute|CupertinoPageRoute|PageRouteBuilder' lib/src
rg -n 'showDialog|showAdaptiveDialog|showModalBottomSheet|showAdaptiveSheet|showCupertinoModalPopup|showGeneralDialog' lib/src
rg -n 'PopScope|onLongPress|onSecondaryTap|RawGestureDetector|supportedDevices|onHorizontalDrag|Shortcuts|MacCommand.back' lib/src
```

Follow [the adaptive UI series](../openspec/adaptive-ui-series.md) before assigning overlapping feature migrations. Its Skills work and the remaining Kanban/connection/autocomplete work must be reconciled with this backlog.
