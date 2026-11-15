# Design

## Context

Read in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`): `hermes_cli/web_routers/messaging.py` (routes and the bridge watcher), `hermes_cli/web_server_messaging.py` (session record, payload, restart), `hermes_cli/web_server_gateway.py` (`_restart_gateway_after`), `hermes_cli/web_server_profiles.py` (`_config_profile_scope`), `scripts/whatsapp-bridge/bridge.js` (`--pair-only --pair-json`). Platforms: iOS, iPadOS, Android, macOS, Windows, Linux; not watchOS. No native change.

## Reading a 404

A 404 is ambiguous. `start` answers 404 with detail starting "Profile '" ("Profile 'x' does not exist.", `web_server_profiles.py`) when the chat's profile was deleted. A route missing on an old server answers 404 with "No such API endpoint: ..." (or `{"error": ...}` when headless), and a POST to it can answer 405 because the catch-all handles GET only. The app tells them apart by the detail: a profile-detail 404 means the profile is gone; any other 404, or a 405, on start means "this server doesn't offer it". On a poll or apply, 404 means the record is gone. It is never read as an old server.

## Server surface

All four routes need the dashboard sign-in; none is in `dashboard_auth/public_paths.py` (grep finds no messaging path there). The generated `DefaultApi` has `startWhatsappOnboarding...Post`, `getWhatsappOnboardingStatus...Get`, `applyWhatsappOnboarding...Post` and `cancelWhatsappOnboarding...Delete`; responses are untyped JSON, parsed leniently.

### What start spawns

`start_whatsapp_onboarding` (messaging.py) records a session and starts a thread, then returns at once. The thread (`_run_whatsapp_pairing`) sets `installing`, runs `npm install --silent` in the bridge directory if `node_modules` is missing (timeout `WHATSAPP_NPM_INSTALL_TIMEOUT`, default 300 s; `_ensure_whatsapp_bridge_dependencies`), finds Node or tries to install it (`pm.ensure("node")`), and spawns `node bridge.js --pair-only --pair-json --session <dir>` (`_spawn_whatsapp_pairing_process`). So Node is needed on the server but not required beforehand. A missing Node, a failed install or a missing `bridge.js` is not an HTTP error: the session goes to `error` with a text such as "Node.js preparation failed: ..." or "npm install failed for WhatsApp bridge: <last 10 lines>". That text can hold server paths; the app shows it and never records it.

### Request bodies

- Start `WhatsAppOnboardingStart`: `mode` (default `bot`; `bot` or `self-chat`, else 400 "WhatsApp mode must be 'bot' or 'self-chat'."), `allowed_users` (comma-separated text, default empty; spaces removed, otherwise not validated), `profile`. A wrong type is 422.
- Apply `WhatsAppOnboardingApply`: `mode`, `allowed_users`, `profile`, plus `?profile=`. All optional; mode and allowed users fall back to what start stored. The profile used is `body.profile or query.profile or the profile given at start` (`apply_whatsapp_onboarding`).

### Profile

`start` runs under `_config_profile_scope(body.profile)`, so the session directory (`get_hermes_dir("platforms/whatsapp/session", "whatsapp/session")`) is the chosen profile's, not the dashboard's. The profile is remembered in the record. The paths take no profile elsewhere; `GET` and `DELETE` act on the record by id.

### Response and status

Start and GET return `{pairing_id, status, qr_payload, expires_at, mode, allowed_users, account_id, account_name, account_phone, error}` (`_WHATSAPP_PAYLOAD_FIELDS`). `status` is one of `installing`, `starting`, `waiting`, `connected`, `error`, `expired`, `cancelled`.

- `qr_payload` is a string, the text a QR encodes (Baileys' `qr`); the app renders it. It is null until the bridge emits the first `qr` event (`_apply_pairing_event`), then `waiting`. Each new `qr` event replaces it, so it rotates. Baileys' interval (about 20 s) is not in this repo: not verified.
- `expires_at` is ISO UTC, fixed at start plus 600 s (`_WHATSAPP_ONBOARDING_TTL_SECONDS`); it is never extended. The record is checked on each read (`_prune_whatsapp_onboarding_sessions`): live and past `expires_at` becomes `expired`, the bridge is terminated, and `GET` answers 410 with "WhatsApp QR setup expired. Start a new setup." A finished record (`connected`, `error`, `expired` or `cancelled`) is dropped when `expires_at` + 300 s has passed, that is 900 s after start, whatever the time it finished: then 404. A `connected` record never becomes `expired` (it is terminal), so a Finish pressed after 15 minutes gets a 404 on apply, most likely in the "Already linked" case.
- `connected` carries `account_id`, `account_name` and `account_phone` (digits of the JID), read from the bridge's `connected` event.
- `error` carries `error`. After a logout the bridge emits `logged_out` and calls `process.exit(1)`, and `_watch_whatsapp_pairing` then overwrites the text with "WhatsApp pairing process exited with code 1." (or "...exited before pairing completed." for code 0), so `logged_out` is effectively never seen. Spawn-thread failures are `str(HTTPException)`, e.g. "500: Node.js preparation failed: ...". The app shows the text as given, with no per-reason wording.
- There is no polling hint. The app polls every 2 s while the screen is open and the app is in front (Telegram's screen uses 3 s).

### Already linked

If `creds.json` exists in the session directory, start returns `status: connected` with the stored account and spawns nothing. No QR appears; the account in the session directory is reused as it is. No route unlinks it. The app says "Already linked" with the account and offers Finish; it cannot offer to link another account.

### Concurrency

`_register_whatsapp_session` cancels any live record on the same session directory ("Superseded by a newer WhatsApp setup session.", status `cancelled`, bridge terminated). So a second start from another device ends the first, which then reads `cancelled`. Different profiles have different directories and can pair at once. Records are in memory: a dashboard restart makes every id 404.

### Apply

Requires `connected`, else 409 "WhatsApp setup is not connected yet." Unknown or dropped id: 404 "WhatsApp setup session was not found. Start a new setup." The settings may not have been saved, so after a 404 on apply the app offers Start again, which on an already linked session returns `connected` at once with no new scan, then Finish again. Under the profile it writes `WHATSAPP_MODE`, `WHATSAPP_DM_POLICY=pairing`, `WHATSAPP_ALLOWED_USERS` (only when non-empty: blank keeps the old list; in `self-chat` with none given, the linked phone), `WHATSAPP_ENABLED=true` and the config `enabled` flag. A bad value is 400 with its text; any other failure is 500 "Failed to save WhatsApp setup." It then drops the record and asks for a restart of the messaging gateway for the profile (`_restart_gateway_after`; best effort). `restart_started: true` only means a `hermes gateway restart` child was spawned; that child can still refuse (`_spawn_gateway_restart`), so the app never says the gateway was restarted. Response: `{ok, platform: "whatsapp", needs_restart, restart_started, restart_action, restart_pid, restart_error}`. The gateway is shared by profiles (`gateway_shared_with` in status), so the restart stops conversations on every channel it serves. No secret comes back: the WhatsApp credentials stay in the server's session directory.

### Cancel

`DELETE` removes the record, terminates the bridge and returns `{ok: true}` even for an unknown id (idempotent). It does not delete credentials: a session that already reached `connected` stays linked on disk, and the next start reports it as already linked.

### Recorded answers

Recorded on 2026-11-15 from a throwaway dashboard at `d923a5eb` (`scripts/install-hermes.sh` cache, `scripts/dev-backend.sh` with its own `HERMES_HOME` and HOME, a loopback port, stopped and deleted after; the real `~/.hermes` was never touched). Node 22 exists on that machine but the bridge's `node_modules` do not, so a `start` on an unlinked folder would have run `npm install` and then connected to WhatsApp's servers. It was never made: the bridge was not started and nothing contacted WhatsApp. "Already linked" was reached by putting an invented `creds.json` (invented number and name) in the throwaway session folder, which makes `start` answer `connected` without spawning. `apply` was never called with a valid body (it saves settings and spawns a gateway restart); only its refusals before the save were. The fixtures are in `test/messaging/whatsapp/whatsapp_fixtures.dart`, each marked recorded or from source.

| Answer | How known |
| --- | --- |
| Status, apply and cancel of an unknown id: 404 `WhatsApp setup session was not found. Start a new setup.` (status, apply); cancel 200 `{"ok": true}` | recorded |
| Cancel of a known (linked) record 200, then a read of it 404 | recorded |
| `start` with `mode` not `bot`/`self-chat`: 400 `WhatsApp mode must be 'bot' or 'self-chat'.`; apply with a bad mode on a connected record: the same 400, record kept | recorded |
| Wrong types, bad JSON: 422 (FastAPI list) on start and apply | recorded |
| `start` with an unknown profile: 404 `Profile 'ghost' does not exist.`; with an invalid name (`../x`, `a b`): 400 naming the name, both before any record or spawn | recorded |
| Already linked: `start` 200 `connected` with `account_id`, `account_name`, `account_phone` (digits), no code; `allowed_users` normalised (`+1 555 555 0100, 15555550101` became `+15555550100,15555550101`); a second start on the same folder is a second `connected` record, the first is not superseded (only live records are); `self-chat` with no numbers keeps `allowed_users` empty at start | recorded |
| A route this server lacks, or an id with `/` (also `%2F`, which the server decodes): 404 `No such API endpoint: ...`; a POST to a missing route: 405 `Method Not Allowed` | recorded |
| 401 without a session: `{"detail": "Unauthorized"}` on a dashboard without the password gate (no session token header), `{"error": "unauthenticated", "detail": "Unauthorized", "reason": "no_cookie", "login_url": "/login"}` on a gated one, on all four routes | recorded |
| `start` on an unlinked folder: `starting` first, then `installing`, `waiting` with `qr_payload`, rotating codes, `connected` after a scan | from source, not recorded (needs Node, npm and a phone) |
| `error` texts: Node preparation, npm install, bridge script missing, process exit; superseded (`cancelled`, "Superseded by a newer WhatsApp setup session.") | from source, not recorded (invented paths in the fixtures) |
| 410 `WhatsApp QR setup expired. Start a new setup.`; a finished record gone after 900 s | from source, not recorded (a clock of 10 minutes; no way to shorten it) |
| apply success: `{ok, platform, needs_restart, restart_started, restart_action, restart_pid}`, and the failed restart `{..., restart_started: false, restart_error}`; 409 `WhatsApp setup is not connected yet.`; 500 `Failed to save WhatsApp setup.` | from source, not recorded (409 needs an unlinked live record; apply restarts a gateway) |
| The platform list after a save | not recorded: needs an apply; the existing platform fixtures stay as they are |
| A real QR, the rotation interval, a scan | needs a device and an account |

The repository reads a 404 on start by its detail (`Profile '` for the profile, anything else or a 405 for a missing route), a 404 on a read or apply as "record gone" (a `Profile '` detail on apply as the profile), and sorts an `error` text into a fixed category (`nodeUnavailable`, `installFailed`, `bridgeMissing`, `processExited`, `loggedOut`, `other`) by the server's opening words after an optional `<status>: ` prefix, so a failed `npm install` that mentions Node.js stays `installFailed`. The category is the headline; the server's text rides along unchanged in an opaque `WhatsAppServerText` (fixed `toString`, never printed, never logged) on a `error` state and on the failure of a start or apply answered 400, 409 or 500 with a string `detail`, and the screen shows it as given, as above. The controller drops the holder on close, App Lock and sign-out.

### Not verified

Baileys' QR interval; the exact text a failing bridge sends; behaviour on Windows hosts (`windows_hide_flags` exists); no live run was made (needs a phone with WhatsApp). The states that need the bridge are fixtures from the source, not recordings (next section).

## The phone question

WhatsApp links a device when the phone that holds the account scans the QR. On a handset the app and that WhatsApp are one device, so it cannot scan its own screen, and the server has no link-by-number mode. Decision: the flow is kept, not hidden. Handsets (shortest side under 600 dp) first show the notice "Scan this with the phone that has WhatsApp. Open this screen on another device, or on a computer." and reveal the code on the button "Show QR code". Tablets and desktops show the code at once. The notice is the only honest handset path; with a second device signed in to the same server the flow works as on desktop.

## Decisions

- The QR payload and pairing id are secrets by the "Secret fields" rule in `docs/architecture/settings-screens.md`, adapted: they are never typed, so no Show/Hide field; the code is hidden on handsets until tapped, and hidden again when the lifecycle leaves `resumed`, App Lock locks, or (decided by the owner) a desktop window loses focus, and dropped on close. After such a hide a handset needs the tap again; a tablet or computer shows the code again when the app is in front, focused and unlocked. No Copy button, no share sheet, no preferences, no state restoration.
- The request span path contains the pairing id, but the span interceptor (`dart_otel_instrumentation_dio` 0.1.2) sets `http.route` to the first two path segments (`/api/messaging`), so the id does not reach a span (verified by review). Task 2.4 still adds a test for it.
- For the controller: a rethrown 401 `DioException` still carries `requestOptions.uri` (with the id) and `requestOptions.data` (with `allowed_users`); the controller never logs or reports its fields beyond the status. On apply, `allowedUsers: ""` and `null` differ: `""` discards what start stored, `null` keeps it.
- Known upstream gap: a lost answer on start leaves a server pairing the app cannot cancel (cancel needs the id, and the server prunes only on a later request, so the bridge may keep rotating codes until then). Roadmap candidate: ask upstream for a cancel by session folder, or an id the client picks.
- Start, Finish and Cancel are user actions only. Nothing starts on opening the setup form; "Link WhatsApp" is a button.
- Finish shows a confirmation: "Save the WhatsApp setup and ask the messaging gateway to restart? Conversations on messaging channels will be interrupted." Buttons: Cancel (the default) and Save and restart.
- A lost answer on start: the screen says it does not know whether a pairing began and offers Start again (which supersedes any earlier one). A lost answer on Finish: "Could not confirm the setup was saved." with Check, which reads `GET /api/messaging/platforms?profile=`; apply is never resent, because the record is gone once it succeeds (a resend would 404). A 404 on apply: the record is gone (dropped 900 s after start, a dashboard restart, or an apply that already succeeded). The screen says the setup is no longer on the server and the settings may not be saved, and offers Start again.
- The profile is the chat's profile, in the start body and in both places on apply. `allowed_users` is checked in the app (digits, with an optional leading `+`, comma-separated) because the server does not. This is stricter than the bridge's allowlist (`allowlist.js`), which also takes `*` and JIDs/LIDs. Decision: the restriction is a non-goal, not a gap. `*` lets anyone message the agent, so it is not offered in a QR flow, and the screen refuses it with a note that it is a server setting. A blank list keeps the old one (and in `self-chat` becomes the linked phone).
- Only the generated client is used, through `authController.api!.raw`. The repository group lives beside the Telegram one in `hermes_messaging_repository.dart`; `_explaining` already maps 400, 404, 409 and 410 `detail`, and 500 `detail` is added for this group.

## Observability

Spans: `whatsapp.pair.start`, `whatsapp.pair.apply` (they cross the network; attributes `outcome`, `restart`). Log events through `AppEventLogger`: `whatsapp.pair.ended` with `status`, `whatsapp.pair.unavailable` (a route-missing 404 or a 405 on start from an old server, once per connection). Breadcrumbs: `whatsapp.pair.opened`, `whatsapp.pair.qr_shown`, `whatsapp.pair.applied`. None holds the QR, an id, a number, a name, a path, an error text or a profile.

## Design pass

Design (done): canvas published, local render reviewed.

Canvas: https://claude.ai/artifact/PPwKxdh8zKokvagfxS3Gho (private; ask its owner for access). 26 boards, one parametric page, nine rows: entry and setup (A), handset notice and QR (B), linked and end states (C), Finish question and saved outcomes (D), dark (E), largest text (F), German (G), Android (H), Mac and iPad (I). Checked in a local headless Chrome render in both themes, at phone and desktop width and at text scale 1 and 2; not checked: the claude.ai viewer, real devices, a scannable QR, screen readers and focus order, Mac targets, the App Lock cover, the countdown announcements (details in the brief's "Local render review"). The brief `docs/design-briefs/whatsapp-onboarding.md` was written from the design system README, the merged briefs and the shared widgets, and reviewed. Decisions that change behaviour:

- One pushed screen whose body follows the phase, like the Telegram screen; Finish closes both screens to the Messaging list, which shows a banner with the outcome (success when a restart was requested and `needs_restart` is false, warning otherwise; never "restarted").
- Polling (decided by the owner) runs only while the app is in front and App Lock is unlocked. On return while locked nothing polls; once unlocked a line says polling was paused and is resuming, and it goes at the next answer. A countdown that ran out while paused ends locally on return. On unlock a handset needs the "Show QR code" tap again.
- The countdown is the setup's 600 s ("Setup closes in 8:42"), not the code's rotation, which is not verified. A last-minute warning is shown; it is announced at 60, 30 and 10 seconds left only.
- A failed poll keeps the last state and adds an offline or unreachable banner ("This code may be out of date."); polling continues every 2 s.
- While apply is in flight (at most 10 s) the route cannot be popped (system back and the iOS swipe included) and no Cancel is sent; the Mac back chord goes through `MacCommandScope` and is disabled, never a key handler. Leaving after the lost-apply state sends nothing new; the `DELETE` is not sent either: the record is most likely gone, `DELETE` is idempotent but would not unlink anything, and a surviving record is dropped by the server after 900 s. After 10 s with no answer the lost-answer state shows, and Check ends within 10 s with "Couldn't confirm".
- Start again returns to the setup form with the earlier mode and numbers.
- The QR tile is black on white in both themes and does not scale with text size.
- Desktop (decided by the owner): the code is hidden whenever the window loses focus, not only on App Lock or minimise. The catalog keeps a use case for the desktop hidden state.

## Follow-ups outside this change

- Android: block screenshots and screen recording of the QR with `FLAG_SECURE` while the code is shown. Decided by the owner as not part of this change (it needs native work, and the proposal says no native change). Roadmap candidate only; `docs/roadmap.md` is updated by the orchestrator, not here.
