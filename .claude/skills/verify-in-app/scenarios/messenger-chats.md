# Messenger Chats and recipients

Follow the shared client-isolation prerequisite before any native launch. The
checkout's `scripts/dev-backend.sh` isolates backend state; it does not isolate
the macOS Debug app's preferences, cache, window state, or keychain. Use a
disposable graphical account or VM, or a temporary client namespace whose
storage and routing have been reviewed and verified. Do not use the ordinary
Debug app in the developer's session for this check. The current
`scripts/dev-app.sh` does not establish client isolation by itself.

Use a compact iOS or Android target to verify the full-page Chats home and
list/detail Back behavior. The existing macOS helper can verify wide-layout
recipient and avatar surfaces, but macOS compact-window behavior retains its
existing overlay and does not establish phone navigation. Record the platform
and actual window or simulator dimensions with the result.

On Xcode 27, use Device Hub (`com.apple.dt.Devices`) to create or select the
disposable simulator. `Simulator.app` is not the available device surface in
this setup. Record the selected device name and UDID, confirm its fresh home
screen and app container, and use only that simulator for the run; do not infer
client isolation from a distinct app build path or bundle identifier alone.

## Fixture

1. Record the checkout revision and relevant patch hash. Check `command -v
   hermes`, `command -v flutter`, and free space before a build. Flutter work
   is serialized across worktrees; coordinate the SDK slot before running any
   test, analysis, or build.
2. Create a unique fixture root outside the checkout, such as
   `/private/tmp/hermes-messenger-verify-<unique>/`, and keep its backend home,
   runtime home, and temporary directory there. Start the isolated dashboard
   with a scrubbed environment, `dashboard --isolated --no-open --port 0`, and
   record its PID, loopback port, homes, launch command, and fixture details in
   `fixture-manifest.json` under that root. Confirm the recorded PID owns the
   loopback listener and `/api/status` reports that exact external backend
   home. Do not use `.dart_tool` runner state for the backend or screenshots.
   Never stop another dashboard.
3. Populate only that throwaway home with synthetic session rows and two
   profiles, such as `default` and `work`. `scripts/seed_demo_sessions.py`
   seeds synthetic default-profile chats. Add profile fixture data only inside
   the throwaway home. If a profile must be created through Hermes, follow the
   shared guide's wrapper-directory redirection rule so aliases cannot be
   written to the real home. A small synthetic avatar may be seeded directly
   into the fixture profile's assets before launch. Keep the backend active
   profile set to `default` for the local recipient check. Start the selector
   checks without model configuration so the real discovery response shows
   `Set up a model`. Configure the local model only after observing this state,
   then refresh discovery before checking sends or reply continuity. Use a
   synthetic credential in each exercised profile's own config; profiles do not
   inherit the default profile's model config. Never inherit personal keys.
   Start a fresh chat after correcting model configuration: an existing
   session can retain its earlier model selection across backend restarts.
   Confirm the composer shows the intended local model before sending.
4. Launch the client only after the disposable client namespace passes the
   shared checks. Use `client_base_url` from `fixture-manifest.json` as
   `HERMES_SERVER_URL`; when a fixture proxy is used, this is the proxy URL.
   Never rely on a saved server address. The provided
   `scripts/dev-app.sh start`
   targets the normal macOS Debug identity, so it is not a safe launcher until
   its client isolation has been independently established. For an iOS
   simulator run, target only the recorded disposable simulator UDID and
   verify its app container before first launch. On Xcode 27, control and
   inspect it through Device Hub (`com.apple.dt.Devices`).

## Checks

1. On a compact phone target, start without a deep link or other explicit
   navigation action. Confirm Chats is the full-page root, the current
   profile's synthetic conversations are visible, and no detail screen covers
   the list. Check the empty or retry view separately if the fixture can
   safely provide it. Opening Chats must not send a message or mark a thread
   read.
2. Open a synthetic conversation. Enter a recognizable unsent draft, use the
   header Back action, reopen the same conversation, and confirm the draft is
   present and no message was sent. Repeat Back with the platform gesture or
   system Back. Search text and list position should remain available when
   returning.
3. Exercise model setup and retry before sending a prompt. Start with no model
   config in the selected profile. After model discovery succeeds with an empty
   provider list, confirm the composer says `Set up a model`. Tap it and check
   the guidance names the current profile and shows `hermes model` for
   `default`, or `hermes -p work model` for `work`. Close with `Check again`;
   with no model configured, the selector should remain incomplete and sending
   should be disabled. If discovery returns an error, confirm the pill says
   `Could not load models` and exposes a separate `Retry` action. Keep a draft,
   tap Retry, and confirm the draft remains unchanged. These expected labels
   come from `composer_model_pill.dart` and `chat_screen.dart`; record them as
   observed only after the native run confirms them.
4. Configure only the selected profile's
   `<fixture-home>/profiles/<profile>/config.yaml` (or the fixture root
   `config.yaml` for `default`) with the local Ollama model from the shared
   guide. Never copy a personal provider key. Reopen setup guidance and tap
   `Check again`, or use `Retry` after failed discovery. Confirm the configured
   model appears in the composer and is selected in the model picker, with the
   draft intact. Start a fresh chat after configuring if the synthetic session
   retained an earlier model selection. Send a synthetic prompt only after
   confirming the local model, and confirm its streamed reply completes.
   Report empty, failed, recovered, and successful-send states separately;
   source tests are not native evidence.
5. Start a synthetic reply on a disposable backend configured with a local
   model, or use an already-running synthetic reply fixture. In a multi-profile
   fixture, configure the model in the selected profile's own
   `<fixture-home>/profiles/<profile>/config.yaml`; secondary profiles do not
   inherit the launch profile's model. Return to Chats, wait briefly, and reopen
   the conversation. Confirm the same reply continues and the composer/list
   remain usable. Without a model, report reply continuity as unobserved; do not
   infer it from a static transcript.
6. From Chats, choose New message and select `work`. Before sending, confirm
   the recipient label and profile-specific composer state follow `work`,
   while `/api/profiles/active` remains `default`. Inspect backend request logs
   or request counters and confirm selection, opening, returning, and resuming
   did not issue `POST /api/profiles/active` or write profile configuration.
   Do not send a prompt for this check. Reopen a seeded `default` conversation
   and confirm its history and recipient remain bound to `default`.
7. If a fixture-only endpoint proxy is available, vary recipient responses
   independently from model discovery. An empty `/api/profiles` response
   should show `No profiles available` and profile setup guidance; a failed
   request should show `Could not load recipients` with its own `Retry`. Restore
   the endpoint and retry, then confirm the current recipient and unsent draft
   remain intact. For the loopback proxy described by the manifest, set the
   `/api/profiles` entry in `proxy-control.json` to `hold`, `empty`, or
   `fail503`; change it back to `pass` to release a held request or restore the
   real fixture response. Use the same modes on `/api/model/options` to exercise
   model discovery independently. The proxy forwards other HTTP traffic and
   WebSocket frames to the isolated backend. Do not edit app code or client
   storage to manufacture these states. Record a state as unobserved if a real
   fixture response did not produce it.
8. Inspect profile identity in conversation rows, the New message picker and
   selected recipient, and the chat header. Confirm the recipient and model
   controls sit side by side in the composer, including
   on a narrow layout; long labels must truncate without overflowing. Confirm
   the same deterministic
   monogram and color appear when no image is configured and the visible or
   accessible profile name distinguishes recipients. If the fixture has a
   configured image served by the existing authenticated asset contract,
   verify it appears on each surface. The client must only read the seeded
   asset; do not upload an image or configure an external image URL.
9. If available, open the shell menu from Chats and confirm existing
   destinations remain reachable under their capability gates. This check
   must not navigate by an unrelated saved route or deep link.

Record screenshots for the root, reopened draft, recipient picker, and avatar
surfaces under the fixture root (for example, `shots/`). Keep screenshots
uncommitted and remove only fixture outputs owned by this run.

## Teardown

Quit the fixture client first and restore any temporary source, plist, build,
or signing substitutions from their exact backups. Do not hot restart after
restoring them. Stop only the backend PID recorded in `fixture-manifest.json`,
confirm its recorded listener is gone, and remove the fixture root only after
keeping any requested screenshot evidence. Record every behavior that could
not be observed. Do not run `hermes dashboard --stop`.
