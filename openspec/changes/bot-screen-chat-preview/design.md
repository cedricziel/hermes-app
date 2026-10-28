# Design

## Context

`bot-screen-status` and `bot-screen-card` give `ChatScreen` one `BotScreenController` per chat profile, with `watch()` demand handles and the foreground/unlocked/window gates already driven by `ChatScreen`. Tool calls render through `chat_builders.dart`: a run of calls the agent made back to back becomes a `ToolCallGroup` (`lib/src/chat/widgets/tool_call_group.dart`), which shows a single call as its own `ToolCallCard` and folds two or more behind a header that starts collapsed. The Activity panel opens through `_toggleActivity` in `chat_screen_navigation.dart`, which flips `_activityOpen` on wide layouts and opens a detent sheet on phones; calling it while the inspector is open closes it.

## Decisions

- **Which run shows it.** While a reply is pending, `chatMessageToFlyer` (the mapper, which sees the whole reply, where a message builder sees one run) marks the run that holds the reply's latest tool call named `computer_use` with `kMetaScreenPreview` (the reply's id), whatever that call's status, since the preview lasts until the reply ends. No other run is marked. When the reply ends, no run qualifies. `chat_builders.dart` only draws the preview for a marked run.
- **Slot placement.** `ToolCallCard` and `ToolCallGroup` each get `Widget? preview`, drawn under the header. When the run has one call, the card draws it; when it has several, the group header draws it, so it stays visible while the group is folded. Both widgets stay plain and catalog-ready.
- **`BotScreenPreview`** (`lib/src/bot_screen/widgets/bot_screen_preview.dart`) takes a plain model (`frame(bytes, control)`, `suppressed`, `hidden`) and `onTap`; a small binding listens to the controller and maps its state, drawing nothing unless the screen runs. `gaplessPlayback: true` avoids flicker on refresh.
- **On-screen demand.** The binding wraps the preview in `VisibilityDetector` (package `visibility_detector`, published by Google, pure Dart, every platform) and holds a `watch()` handle only while the visible fraction is above zero and its page is not covered (`TickerMode`, as `BotScreenDemand` does); a widget built in the `ListView` cache extent but off screen holds none. Until the screen runs the binding draws a one pixel placeholder under the detector instead of nothing: a box with no area is never reported as visible, and the watch is what reads the status, so without it the preview could never appear. It draws nothing once the server has no Bot Screen. The handle is released on dispose. This is why the package is added rather than `Visibility.of`, which only reports the subtree's own visibility flag.
- **Open-only action.** `_openActivity({required String source})` in `chat_screen_navigation.dart` opens the inspector or the sheet and does nothing if the inspector is already open; `_toggleActivity` keeps its behaviour. The preview calls `_openActivity(source: 'preview')`, which records the existing `chat.activity.opened` crumb with that source.
- **Shared poll attribute.** `BotScreenController` passes its current watcher count to `BotScreenRepository.thumbnail(watchers:)`, which sets it on the thumbnail span.
- **Who holds the controller.** `ChatScreen` passes its controller and the open-only action to `boundChatThreadView`, which builds a `ScreenPreviewBuilder` for `ChatThreadView`; the preview's `shown` memory (`shown.previewReply`) lives on the controller, one reply id at a time.
- **Design system sync.** `design/web` `ToolCallCard` and `ToolCallGroup` get `preview?: ReactNode`, and a `BotScreenPreview` component (`docs/BotScreenPreview.md`, `category: Agent activity`), documented in JSDoc so the synced prompt explains them.

Platforms: iOS, Android, macOS, Windows, Linux. No native change. `ConversationWindowScreen` and `QuickPanelScreen` pass no controller, so their transcripts show no preview.

Invariants touched: telemetry. Breadcrumbs `bot_screen.preview.shown` (in the binding, once per reply via the reply's message id kept in memory) and `bot_screen.preview.tapped`; the thumbnail span's `watchers` count. No user content, ids or names.

## Risks / Trade-offs

- [A streaming reply rebuilds the run often] → The preview listens only to the controller; the run rebuild does not refetch.
- [A new dependency] → Small, maintained by Google, no platform code; the alternative is hand-written viewport intersection.
- [Two surfaces (card and preview) on screen at once] → One poll, counted as two watchers.
