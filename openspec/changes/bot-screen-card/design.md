# Design

## Context

`bot-screen-status` provides `BotScreenController` (per profile and connection: status, frame, demand handles from `watch()`, `foreground`/`unlocked` gates, `start()`). The Activity panel is `ActivityPanel` (`lib/src/chat/activity/widgets/activity_panel.dart`) filled by `BoundActivityPanel`, which today takes only `chat` and `thread` and builds Now from the chat's session state and MoA progress. `ChatScreen` opens it as an inspector on wide layouts (`InspectorLayout`, `_activityOpen`) and as a detent sheet on phones (`_toggleActivity` in `chat_screen_navigation.dart`). `ActivityKind` in `activity_tier.dart` assigns tiers. On macOS the main window is hidden, not released, when closed (`MacApp.windowlessChanges` reports it), so its widgets keep running. `AppLockController.covered` is true while locked and while the app is inactive.

## Decisions

- **Ownership.** `ChatScreen` creates one `BotScreenController` for the chat's profile (`ChatController.profile ?? kDefaultProfile`) from the shared gateway transport and the connection's telemetry, replaces it on profile switch and disposes it on sign-out. `ConversationWindowScreen` and `QuickPanelScreen` create none.
- **Panel input.** `BoundActivityPanel` gains `BotScreenController? screen`; the inspector and the phone sheet pass the same controller. When it is null (conversation windows, mock data) Now is unchanged.
- **When the card is listed.** Never after `unsupported`. Otherwise when `status.running`, or when the open thread holds a tool call named `computer_use` (a scan of the thread's messages' tool calls, done when the chat changes). `ActivityKind.screen` (tier Working) is added so the strip, which shows Working and Needs-you items from the chat's state, keeps leaving it out: the strip's builder does not read the controller.
- **Card model.** `BotScreenCard` (`lib/src/bot_screen/widgets/bot_screen_card.dart`) takes a sealed `BotScreenCardModel`, derived by `BotScreenCardModel.from(controller state)` in the order of the spec: `notOffered`, `notInstalled(command?, sandbox)`, `blocked(text, memoryMb?)`, `starting`, `off(error?)`, `error`, `frame(bytes, control)`, `controlled(byYou)` (no picture; `byYou` stays false until `bot-screen-takeover` gives the app viewer ids). Callbacks: `onStart`, `onCopyCommand`, `onRetry`, `onEnlarge` (null hides Enlarge; this change always passes null). `notInstalled` with `placement != "gateway"` shows the sandbox sentence and no command. The frame is drawn with `Image.memory(gaplessPlayback: true)` in an `AspectRatio` from `geometry` (16:10 when unknown). Chrome follows `platformChromeOf(context)` like the other Activity cards.
- **Demand.** A `_BotScreenWatch` state object holds a `watch()` handle while the card is mounted and `Visibility.of(context)` is true (the inspector keeps its child alive when hidden), and releases it otherwise. `ChatScreen` sets the controller's `foreground` from `AppPresence.focused(lifecycleState)` (resumed only; `AppPresence.foreground` counts a hidden or inactive Mac app as running) and, on macOS, from `MacApp.windowlessChanges` (false while no window is on screen), and `unlocked` from `!AppLockController.covered`.
- **Breadcrumb on change.** The card keeps the last recorded state name and records `bot_screen.card.shown` only when it differs, so a 3 s frame refresh records nothing.
- **Design system sync.** `design/web/src/components/BotScreenCard/` (`BotScreenCard.tsx`, `.css`; props mirror the model, every state described in JSDoc) exported from `src/index.ts`, and `design/web/docs/BotScreenCard.md` with `category: Agent activity`, the category the other Activity cards use.

Platforms: iOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode change.

Invariants touched:

- Telemetry: log event `bot_screen.start` (`outcome`) in `BotScreenController.start` through the connection's `AppEventLogger`; breadcrumbs `bot_screen.card.shown` (`state`: `not_offered`, `not_installed`, `blocked`, `starting`, `off`, `error`, `frame`, `controlled`) in `BotScreenCard`'s state and `bot_screen.start.pressed` in its Start handler. None carries the image, install command, blocker text, profile names or ids.

## Risks / Trade-offs

- [Each poll records two spans (the thumbnail span and the RPC request span)] → Kept at one poll per 3 s, only while the card is visible.
- [A chat that used `computer_use` long ago shows an Off card] → The panel is opened on purpose and Off offers Start Screen.
- [The inspector's hidden state relies on `Visibility`] → The same signal `KanbanBoardController.active` uses; covered by a widget test.
