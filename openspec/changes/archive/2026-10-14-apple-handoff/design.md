## Context

See `proposal.md` for motivation and scope. Hermes already opens external chat targets through `ChatOpenRequests` and `ChatController.open`, including sessions beyond the loaded page and sessions on another profile. Selecting a saved thread loads history and follows a reply started by another client.

iOS uses an empty `SceneDelegate: FlutterSceneDelegate`. Its app delegate registers method channels when the implicit Flutter engine initializes. macOS already uses an app-delegate method channel with a `take` operation for incoming shares. `AppLockGate` keeps its child mounted while locked, so mounting the shell does not establish permission to restore a Handoff activity.

## Goals / Non-Goals

Goals: reuse profile-aware restoration, retain a target across shell recreation during sign-in, and make server changes explicit. Keep native code limited to Apple activity lifecycle and Flutter transport.

Non-goals: introduce a route framework, a server credential store for multiple dashboards, or a separate reply transport. Feature scope exclusions are listed in `proposal.md`.

## Decisions

### Use a small native bridge

Add `hermes_app/handoff` with `publish`, `clear`, and `take` methods and an incoming-activity notification. Keep the native pending payload until Dart consumes it. Install the Dart listener before calling `take`, and drain through the same path for launch and runtime events to avoid duplicate delivery.

Retain the current `NSUserActivity` strongly. Declare `com.cedricziel.hermesApp.continueChat` in both Runner plists. Publish with `isEligibleForHandoff = true`, a generic `Continue chat in Hermes` title, and search and public indexing disabled. Use `becomeCurrent()` and invalidate replaced or withdrawn activities. Do not set `webpageURL` or enable continuation streams.

A dedicated method channel follows existing native integrations without adding a package dependency. Universal links would introduce website association for arbitrary self-hosted addresses and are outside scope.

### Restore through scene and app delegates

On iOS, receive `scene(_:continue:)` and inspect `connectionOptions.userActivities` during `scene(_:willConnectTo:options:)`. Preserve superclass forwarding for unrelated activity types and scene initialization. Register the bridge in the existing implicit-engine callback. On macOS, handle `application(_:continue:restorationHandler:)` and native continuation failures in `AppDelegate`; retain launch-time data before the channel exists.

Native reception acknowledges a supported activity without claiming that the chat has already opened. Application failures are reported through the Dart restoration path.

### Version and validate the identity

Version 1 contains `version`, `serverUrl`, `profile`, and `threadId`. Profile and thread ID must be non-empty strings. Publish only after an explicit profile is known and the selected chat is saved remotely. This avoids resolving a missing profile against another device's sticky default.

Require a serialized payload smaller than 3 KB. Accept only absolute HTTP or HTTPS server URLs with a host, without user information, query, or fragment. Preserve a dashboard base path. Canonicalize scheme, host, default ports, and trailing path slashes for comparison, without treating different hosts as aliases. If a configured URL cannot be represented safely, omit advertisement rather than stripping credentials silently.

Reject unknown versions, invalid URLs, missing identities, and oversized payloads before any network call. Handoff carries no tokens, transcript, draft, local file paths, or queued prompts. The server still authorizes each history request.

### Keep pending restoration above auth routing

Place the Handoff coordinator above `_RootRouter`, beside existing app-wide controllers. Store at most one validated target in memory; a newer incoming activity replaces an older pending target. Do not persist it. An explicit sign-out, change-server action, cancellation, or deliberate navigation after reception discards the target and invalidates outstanding restoration work. Ordinary startup, token refresh, sign-in, and connection retry retain it.

Wait until app-lock settings have loaded and the app is unlocked. If the canonical server matches, wait for auth ready and submit the profile-aware target through the shell's chat-open requests. Use a generation guard so delayed loads cannot navigate after cancellation or a newer target. Reuse existing history loading and gateway attachment without sending a prompt, interrupting the source, or transferring its local queue.

For another server or an unconfigured device, show a standard connection prompt after unlock. **Connect** uses the existing change-server and setup flow with the incoming address prefilled, preserving this accepted target across that intentional transition. Cancellation keeps the current connection. If `HERMES_SERVER_URL` fixes the server for a development run, reject a different incoming server with an explanation instead of changing the override.

A missing profile or chat produces an error without creating a replacement. Network failures retain the pending target for explicit retry or normal connection recovery. Prevent automatic retry loops. Use the existing chat-open failure presentation where possible, with a small completion result only if needed to distinguish retryable failures from missing targets.

### Publish only eligible visible state

Derive the outgoing identity from auth, app lock, visible destination, and selected chat. Publish when identity or eligibility changes, not on every streamed token. Suppress advertisement while an incoming restoration is pending. Clear when leaving the chat destination or covering it with another route, selecting an unsaved chat, locking, signing out, changing servers, or losing auth readiness.

Do not withdraw solely for an inactive or background lifecycle event when app lock is off; switching devices is the intended use. When app lock is on, its background lock transition withdraws the activity. Deletion or profile changes recompute eligibility.

### Preserve platform and project contracts

iOS and iPadOS: modify Runner activity declarations and Swift scene integration. macOS: modify Runner activity declarations and app-delegate integration. Add Swift source references to Xcode projects only where required. No new entitlements, associated domains, App Groups, URL schemes, or deployment-target changes are planned. Release apps must use the same developer Team ID. Use `com.cedricziel.hermesApp.continueChat.dev` for development builds on both platforms so an installed development app cannot claim release activities.

Android, Windows, and Linux use a no-op bridge and retain current behavior. watchOS is unchanged.

Auth refresh and secure token storage remain untouched. REST restoration uses the generated client through existing repositories. No OpenAPI regeneration is needed because routes do not change. Tests exercise real repositories against `FakeHermesServer`, while bridge tests substitute only the operating-system boundary. No new telemetry is emitted.

## Risks / Trade-offs

- Handoff availability depends on device settings and Apple delivery. Validate on physical devices signed into the same Apple Account with Wi-Fi, Bluetooth, and Handoff enabled.
- Dashboard addresses can differ across networks. Require exact canonical server identity and an explicit connection choice for differences.
- App lock can hide a still-mounted chat. Subscribe to lock state explicitly rather than relying on widget lifetime.
- A server switch can lose local queues under existing behavior. The connection prompt must explain that changing dashboards clears the current session and local queued messages.
- Cold launch can arrive before Flutter is ready. Keep a native pending activity and drain it after the Dart listener is registered.
- Restoring a bot chat through ordinary session loading may omit its identity banner. Preserve existing bot-context hydration where supported; never create or rebind a bot during restoration.

## Migration Plan

No stored-data migration or backend deployment is required. Ship both native implementations together. Before release, verify matching signing teams and two-way physical-device continuation. Rollback removes advertisement and reception without changing saved chats or credentials.

## References

- [Apple Handoff implementation](https://developer.apple.com/documentation/Foundation/implementing-handoff-in-your-app)
- [Apple scene continuation callback](https://developer.apple.com/documentation/uikit/uiscenedelegate/scene%28_%3Acontinue%3A%29)
- [Flutter scene lifecycle](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
