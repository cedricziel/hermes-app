# Design

## Context

`display.observe` (Hermes `tui_gateway/methods_display.py`) mints a single-use 30 s ticket and a viewer id for the calling gateway connection and returns `{ticket, path, viewer_id, ...status}`; when the screen is not running it answers error 5300 with only a message, so the reason is not machine-readable. `/api/display/ws` (`hermes_cli/web_routers/display.py`) closes with 4401 for a bad ticket, 4001 when the screen's socket is missing, 1003 for an unframeable or text message, and 4000 for a holder evicted by another person; Host/Origin refusal happens before accept and surfaces as HTTP 403. While a viewer is attached the bridge touches `bot-desktop/activity` at most once a minute, so the idle auto-stop leaves the screen running.

`bot-screen-rfb-client` gives `openDisplaySocket` (typed errors, readable close code) and `RfbClient` (framebuffer, events, byte and encoding counters). `bot-screen-card` gives the card's `onEnlarge` slot (null today) and `bot-screen-chat-preview` the preview's `onTap`, which opens the Activity panel. `InspectorLayout` (`lib/src/widgets/inspector_layout.dart`) docks a 380 pt panel from 760 pt and overlays the same 380 pt panel below that; it is not a full-window surface.

## Decisions

- **`BotScreenRepository.observe(profile, {viewerId})`** returns a `BotScreenObservation` (ticket, path, viewer id and the status; its `toString` shows none of them) or a failure; a failure triggers a `display.status` read in the controller to pick Off (not running) or Error.
- **`BotScreenViewerController`** (`lib/src/bot_screen/viewer/`) owns observe → open → handshake, holds `paused` from visibility, lifecycle, App Lock and profile, and maps endings:

  | Ending                                     | Action                                                                                               |
  | ------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
  | 1000 sent by the app                       | none                                                                                                 |
  | 4000                                       | observe again and reconnect as a watcher                                                             |
  | 4001                                       | Off state, no retry                                                                                  |
  | 4401                                       | observe again once; a second 4401 is an error                                                        |
  | 1003                                       | protocol error, no retry                                                                             |
  | HTTP 403 (`DisplaySocketError.notAllowed`) | "Viewing isn't allowed from this app", no retry                                                      |
  | anything else, decode failures included    | full-jitter backoff, 300 ms base, 15 s cap, 5 attempts, then "Can't reach the screen" with Try Again |

  Pausing closes with 1000 and drops the framebuffer; resuming observes again (a ticket works once).

- **Control in the picture.** The controller follows the `BotScreenController`'s lease and holds one of its `watch()`es for its life, which also keeps the status read and, through the thumbnail poll, notices a takeover that no broadcast reported. While `holder: human` and the hash matches no viewer id this app holds (in this change it never does), `framebuffer` is null and the phase is `blanked`: the view shows a blank surface with "Someone else is in control" and keeps the stream open, so the picture returns as soon as control goes back to Hermes. Until the screen controller has a status there is no known lease, so no picture is shown either (fail closed).
- **Drawing.** After each update `FramebufferPicture` builds a `ui.Image` with `ui.decodeImageFromPixels` (RGBA8888, which copies the pixels at once), at most once per frame via `SchedulerBinding.scheduleFrameCallback`, paints it with `RawImage` inside an `InteractiveViewer` (min scale fit, max 4×), and disposes the previous image once the next is ready. Decoding stays on the UI isolate: a benchmark of one full 1280x800 ZRLE update (all raw tiles, a mix of solid and palette-RLE tiles, all solid) took 2.5 to 8.5 ms AOT and 13 to 20 ms in JIT on an Apple-silicon Mac, under the 16.7 ms of a 60 Hz frame, and incremental updates are far smaller.
- **Presentation.** `showBotScreenViewer` picks by the window's width. Below 760 pt (`kInspectorDockedMinWidth`): a `MaterialPageRoute` on the root navigator (the platform's own transition), full screen, following orientation. From 760 pt: `BotScreenViewerOverlay`, an entry in the root `Overlay` that covers the whole window (not only the chat screen) over a black `ModalBarrier`, so there is no separate scrim. The header is the viewer's own (a 44 pt bar on iOS, 52 pt on a Mac, 56 pt on Material, black in both themes like the image viewer, with room for the traffic lights and Close at the trailing edge in a Mac overlay), not `MacToolbar`, which takes its colours from the theme. A `CallbackShortcuts` for Escape inside the overlay closes it; this is a widget handler, not a menu chord, so no menu item owns Escape. The overlay asks for focus itself after its first frame, because an `autofocus` does not take it from the chat's own focused field. Closing it ends the stream at once; a page closed from the owner's `dispose` is removed after the frame, since the navigator must not change while the tree unmounts.
- **Openers.** `ChatScreen` passes `_openViewer(source)` as the card's `onEnlarge` (and the card's picture tap, through `BoundActivityPanel.onEnlargeScreen`) and as the preview's `onTap`, replacing `_openActivity` there. It creates the `BotScreenViewerController` when the viewer opens, gives it the same `foreground` and `unlocked` gates as the screen controller, and closes the viewer when the chat changes profile and in `dispose`, which also covers sign-out.
- **Design system sync.** `design/web/src/components/BotScreenViewer/` (header, picture area, connecting, reconnecting, off, blanked, not allowed, cannot reach) with `docs/BotScreenViewer.md`, `category: Screens`, the category of the other full screens such as `ImageViewerScreen`.

Platforms: iOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode change.

Invariants touched:

- Telemetry: span `bot_screen.stream` in `BotScreenViewerController` from the connection's telemetry (`outcome`, `close_code`, `encodings_used` from `RfbClient.encodingsSeen`, `kib_received` bucketed `<256`, `256-4096`, `>=4096`); log `bot_screen.stream_failed` (`step`, `error_type` from the typed failure kind) through `AppEventLogger`; breadcrumbs `bot_screen.viewer.opened` and `.closed` in the presentation. No ticket, URL, viewer id, profile or pixels.

## Risks / Trade-offs

- [An open viewer keeps the screen alive and costs the server bandwidth] → The stream closes whenever the viewer is not visible.
- [Building a `ui.Image` per update allocates] → Coalesced to one per frame; the framebuffer is reused.
- [Blanking while someone else holds control hides a picture Hermes Desktop still shows] → Chosen for privacy, consistent with the thumbnail.
