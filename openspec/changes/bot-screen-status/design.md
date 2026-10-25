# Design

## Context

Hermes' gateway exposes the Bot Screen through `display.*` JSON-RPC methods on `/api/ws` (`tui_gateway/methods_display.py`, pinned in `openrpc/hermes-gateway.openrpc.json`). Every handler is `@_profile_scoped`: without `profile` it answers for the gateway's launch home, not the chat's profile. Status results (`DisplayStatus`) carry the runtime facts, `placement` (`gateway` or the terminal backend's sandbox), and a public view of the control lease in which the holder's viewer id is replaced by `viewer_hash` (first 12 hex digits of its SHA-256). Failures answer error code 5300 with a message and, for lease refusals, `data: {code: "viewer_mismatch"}`. The server broadcasts `display.status` when a screen starts or stops and `display.lease` on lease transitions made in the dashboard's own process, to every connected client, keyed by `profile_key` (the profile's `HERMES_HOME` path). Lease transitions made by other processes (the messaging gateway, a CLI turn) are only visible by reading (`lease.py`: "Transitions made by another process are observed by reading, not by callback").

What the app has:

- `HermesGatewayTransport.request(method, params)` calls `_call`, which wraps the request in `.timeout(requestTimeout)` (30 s) and on `TimeoutException` runs `_drop(client)` and throws `GatewayConnectionClosed`. That is right for chat calls (a gateway that stops answering is dead) and wrong for a framebuffer grab on a loaded server: the shared connection carries running replies.
- `GatewayRpcClient._settle` builds `GatewayRpcException(code, message)` and drops the error's `data`.
- `GatewayConnectionTransport.connectionEvents` delivers raw broadcasts tagged with their connection, plus `GatewayConnectionEvent.lost`.
- `ChatController.profile` is null when the chat shows the dashboard's default profile; `kDefaultProfile` (`'default'`, `lib/src/surfaces/surface_snapshot.dart`) is the name the app already uses for it (`_profile ?? kDefaultProfile` in `chat_controller.dart`).
- `AppPresence` (`lib/src/shell/app_presence.dart`) and `AppLockController.covered`.

## Goals / Non-Goals

**Goals:** one repository and one controller per (connection, profile) that the card, the transcript preview, the viewer and takeover extend rather than replace; display calls that never harm the chat.

**Non-Goals:** see the proposal.

## Decisions

- **Explicit profile.** Every display call sends `profile`. The controller is created for a profile name; a chat whose `ChatController.profile` is null uses `kDefaultProfile`. Hermes resolves `default` to the root `HERMES_HOME`, which is the launch home on a dashboard started without `-p`, and stays correct when the dashboard was launched under another profile.
- **Timeout without dropping.** `HermesGatewayTransport` gains `requestKeepingConnection(method, params, {required Duration timeout})`, also on the `GatewayRequester` interface and `SessionChatTransport`; it shares `_call`, which gained `timeout` and `dropOnTimeout` parameters, with `request`. A timeout throws `GatewayRequestTimeout` (new, in `gateway_rpc_client.dart`) and leaves the client open; the late answer settles a completer nobody awaits. `request` itself keeps its signature: Dart cannot add named parameters to its optional positional `params`, and a positional `bool` would read badly at the call site. Display calls use 10 s. The connection's heartbeat still drops a socket that is really dead.
- **Error data.** `GatewayRpcException` gains `final Map<String, Object?>? data`, filled by `_settle` when `error.data` is a map; `dataCode` reads `data['code']` as a string. Existing callers are unaffected.
- **`BotScreenRepository`** (`lib/src/bot_screen/bot_screen_repository.dart`) takes the transport's `request` and the connection's `HermesRepositories.telemetry`. It parses leniently into `BotScreenStatus` (`supported`, `installed`, `missing`, `running`, `geometry`, `placement`, `installCommand`, `blocker`, `memoryAvailableMb`, `profileKey`, `lease: BotScreenLease(holder, viewerHash, reason, epoch)`) and `BotScreenFrame` (`jpeg(Uint8List)`, `suppressed`, `stopped`). Results are a sealed `BotScreenResult` (`ok`, `unsupported` for `-32601`, `failed(kind)` for 5300, timeout or a closed connection), never an exception into callers. The data URL is decoded once (`base64Decode` after the comma).
- **`BotScreenController`** (`ChangeNotifier`, one per profile and connection; the card change gives `ChatScreen` ownership) holds `status`, `frame`, `starting`, `startError` and a demand count (`watch()` returns a handle, `release()` lowers it). It polls `display.thumbnail` every 3 s while demand is above zero, the status says `running`, and the gates the owner sets (`foreground`, `unlocked`) hold, with at most one request in flight.
- **Following state.** It subscribes to `connectionEvents`, keeps `display.status`/`display.lease` payloads whose `profile_key` matches the one learned from its first status, and applies them. A lease with `holder: human` clears the frame at once. It re-reads `display.status` when it gains demand, on `GatewayConnectionEvent.lost` while it has demand (broadcasts sent during the gap are lost), when the owner reports the app resumed, and with every 10th thumbnail request (lease changes from other processes).
- **Stale answers.** A generation counter is bumped on `unlocked = false`, on profile switch (the owner disposes the controller) and on dispose; an answer whose generation is old is dropped before it touches state, so a frame requested before App Lock is never shown after it.
- **Who is "you".** This change holds no viewer id, so `holder: human` is always someone else. `bot-screen-takeover` adds the local viewer ids; the model already has the hash.

Platforms: iOS, Android, macOS, Windows, Linux (no UI yet). No native, entitlement, manifest or Xcode change.

Invariants touched:

- API layering: display calls are gateway JSON-RPC, not REST, so no OpenAPI change.
- Telemetry: span `bot_screen.thumbnail` is started in `BotScreenRepository.thumbnail` from the connection's telemetry with `hermes.*` attributes, `outcome` and `bytes_kib` (bucketed: `<16`, `16-64`, `64-256`, `>=256`). Log events `bot_screen.unsupported` and `bot_screen.read_failed` (`method`, `error_type`) go through the connection's `AppEventLogger`. None carries the image, the install command, blocker text, profile names, `profile_key` or ids.

## Risks / Trade-offs

- [A thumbnail every 3 s costs the server a framebuffer grab and JPEG encode] → Only while a surface asks and the app is in front and unlocked; one request in flight.
- [Every 10th poll adds a status read] → One small call per 30 s, the price of noticing a takeover made through another process.
- [A late answer to a timed-out call still arrives] → Ignored; it only costs bandwidth.
