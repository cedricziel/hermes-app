# Proposal

## Why

Reference activity (session usage, side answers, notices) and the idle billing action take permanent space above every chat although they are never urgent. They need a home the user opens on purpose. This is the second of four changes (after `chat-activity-quiet`; design: https://claude.ai/artifact/JxjvcyRkd7YC9ajQSqvFXn): it adds the Activity panel and moves the For reference tier into it.

## What Changes

- New Activity panel with three sections in fixed order: **Now** (Working items), **Plan** (the todo plan with its tasks), **This session** (For reference items and the Verify billing access action). An empty section is left out.
- The panel opens as a bottom sheet on phones (Apple detent sheet on iOS, Material modal sheet on Android) and as an inspector on the right from 760 pt wide (full-screen iPad, Mac, Windows, Linux), drawn over the chat below that width, like the Kanban inspector.
- An Activity button in the chat header (a toolbar button on the Mac) opens and closes it; on the Mac also View > Inspector (⌥⌘I). The inspector stays open across chat switches in the same window.
- Main chat window and Mac conversation windows get the panel; the quick panel does not.
- For reference items stop drawing in the strip: session usage, side results, notices and keyed notifications, the session acknowledgement, connection-wide and settled connector activity, and the idle billing row (its Verify action moves to This session).
- Working items still draw in the strip until `chat-activity-line`; the panel shows them under Now as well.

## Non-goals

- The docked Needs-you card and the Activity button's dot (`chat-activity-needs-you`).
- The working line and the Mac toolbar subtitle, and removing Working items from the strip (`chat-activity-line`).
- Remembering the inspector's open state across launches.

## Capabilities

### New Capabilities

None (adds to `chat-activity` from `chat-activity-quiet`).

### Modified Capabilities

- `chat-activity`: Activity panel, its placement per form factor, the Activity button, and reference activity living only in the panel.
- `agent-billing-verification`: Verify billing access is offered in the Activity panel.
- `agent-side-results`: side results show in the Activity panel instead of the strip.

## Impact

- New `lib/src/chat/activity/` widgets: `ActivityPanel` (sections from plain models), `ActivityInspectorLayout` (shared with or generalised from `KanbanInspectorLayout`), sheet presenters for iOS and Material.
- `ChatHeader`, `MacChatToolbar`, `ChatScreen`, `ConversationWindowScreen`, `ChatThreadView` (stop drawing reference cards), `macos/mac_commands.dart` (`MacCommand.toggleInspector` offered by the chat), `menu_layout.dart` entry already exists.
- Widgetbook use cases for the panel (every section, empty sections, phone and desktop, both themes) and a workflow test step.

## Security and privacy

None. The panel shows the same data the strip shows today under the same ownership and App Lock rules; nothing new is stored or sent.

## Observability

- Breadcrumb `chat.activity.opened` with `surface` (`sheet` | `inspector`) and `source` (`button` | `menu`): a user step that explains a later crash in the panel. Fixed values only.
- Breadcrumb `chat.activity.closed` with `surface`.
- No spans or log events: the panel does no I/O of its own; the reads it shows (usage, billing) already log through their controllers.
