# Design

## Context

After `chat-activity-quiet`, every activity source has a tier and a content check, and `ChatThreadView` stacks the remaining cards above the transcript. The Kanban board already has a right-hand inspector (`lib/src/kanban/widgets/kanban_inspector_layout.dart`: docked from 760 pt, over the board below) and View > Inspector (⌥⌘I, `MacCommand.toggleInspector`, laid out in `menu_layout.dart`) offered through the board's `MacCommandScope`. `ChatThreadView` is shared by `ChatScreen`, `ConversationWindowScreen` and `QuickPanelScreen` through `chat_thread_bindings.dart`.

## Goals / Non-Goals

**Goals:**

- One `ActivityPanel` widget built from plain models, so the sheet and the inspector draw the same sections and Widgetbook can show every state.
- Reuse the Kanban inspector's layout rules rather than a second implementation.

**Non-Goals:**

- Redesigning the individual cards: the panel lists rows that open the existing card bodies (usage details, side answer, notice) inside the panel.
- Persisting the inspector's open state.

## Decisions

- **Generalise `KanbanInspectorLayout` into `InspectorLayout`** (`lib/src/widgets/inspector_layout.dart`) with the 760 pt threshold, the docked/overlay switch and Escape/tap-outside dismissal, and make the Kanban board use it. Alternative: a second chat-only copy. Rejected: two inspectors with different thresholds would drift; the Kanban workflow and widget tests guard the refactor.
- **Panel models.** `ActivityPanelModel { now, plan, session }`, each a list of row models built by an `ActivityPanelSource` adapter that reads the existing controllers and the tier mapping. The panel listens to the controllers through the adapter's `Listenable.merge`. Widgets take only models and callbacks (catalog rule).
- **Sheets.** iOS: a Cupertino-style detent sheet (`showCupertinoSheet` where available on the pinned Flutter, else the app's existing `Sheet`-style detent presenter used by other screens); Android/phone Material: `showModalBottomSheet` with `isScrollControlled` and a drag handle at half height. Which one comes from `platformChromeOf(context)` like every other adaptive surface.
- **Where the open state lives.** A `ValueNotifier<bool>` per window, owned by `ChatScreen` and `ConversationWindowScreen`, so it survives chat switches but not launches. The sheet is not a state: it closes on chat switch.
- **Menu command.** The chat offers `MacCommand.toggleInspector` in its `MacCommandScope` (title "Inspector"); a key conversation window's priority-1 scope already routes window commands to it.
- **Reference cards leave the strip** by filtering `ChatThreadView`'s activity list by tier (`reference` dropped). Working and Needs-you entries stay until the later changes.

Platforms: iOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode change; the menu item already exists.

Invariants touched: telemetry. `chat.activity.opened` is recorded in `ChatScreen`/`ConversationWindowScreen` where the panel opens, with `surface` and `source`; `chat.activity.closed` with `surface`. Both go through `Breadcrumbs` (no-op when telemetry is off) and carry fixed values only, never titles, ids or profile names.

## Risks / Trade-offs

- [Billing details and pending connector cards still sit in the strip until `chat-activity-needs-you`] → Accepted for one release step; they are Needs-you items and keep today's behaviour.
- [The inspector takes 300 pt from the chat on a 1024 pt iPad] → The chat column is capped at 680 pt anyway; below the docking threshold it goes over the chat.
- [Generalising the Kanban inspector touches Kanban] → Pure refactor with existing Kanban inspector tests as the guard; done as its own commit.

## Implementation notes

- The panel takes the existing cards as children instead of row models: `ActivityPanel` (plain widgets, in the catalog) and `BoundActivityPanel`, which reads one chat's controllers and filters by tier, play the roles of the panel and `ActivityPanelSource`.
- The phone sheet reuses the Kanban detent sheet (`showKanbanDetentSheet`) on iOS and Android rather than two presenters.
- The panel scrolls a `Column`, not a lazy list: it holds a handful of cards and every one must be reachable by keyboard and tests.
- Conversation windows have no telemetry of their own, so their inspector records no breadcrumbs; the main window's does.

