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

### Not verified

Baileys' QR interval; the exact text a failing bridge sends; behaviour on Windows hosts (`windows_hide_flags` exists); no live run was made (needs Node and a phone). The fixtures task records the shapes from `scripts/dev-backend.sh`, with the bridge replaced by a stub where Node is absent.

## The phone question

WhatsApp links a device when the phone that holds the account scans the QR. On a handset the app and that WhatsApp are one device, so it cannot scan its own screen, and the server has no link-by-number mode. Decision: the flow is kept, not hidden. Handsets (shortest side under 600 dp) first show the notice "Scan this with the phone that has WhatsApp. Open this screen on another device, or on a computer." and reveal the code on the button "Show QR code". Tablets and desktops show the code at once. The notice is the only honest handset path; with a second device signed in to the same server the flow works as on desktop.

## Decisions

- The QR payload and pairing id are secrets by the "Secret fields" rule in `docs/architecture/settings-screens.md`, adapted: they are never typed, so no Show/Hide field; the code is hidden on handsets until tapped, and hidden again when the lifecycle leaves `resumed` or App Lock locks, and dropped on close. After such a hide a handset needs the tap again; a tablet or computer shows the code again when the app is in front and unlocked. No Copy button, no share sheet, no preferences, no state restoration.
- The request span path contains the pairing id. `DioOTelInterceptor.privacy` (`lib/src/telemetry/telemetry.dart`) is not verified to template paths: task 1 adds a test, and if the id reaches a span the repository records its own spans with the fixed route.
- Start, Finish and Cancel are user actions only. Nothing starts on opening the setup form; "Link WhatsApp" is a button.
- Finish shows a confirmation: "Save the WhatsApp setup and ask the messaging gateway to restart? Conversations on messaging channels will be interrupted." Buttons: Cancel (the default) and Save and restart.
- A lost answer on start: the screen says it does not know whether a pairing began and offers Start again (which supersedes any earlier one). A lost answer on Finish: "Could not confirm the setup was saved." with Check, which reads `GET /api/messaging/platforms?profile=`; apply is never resent, because the record is gone once it succeeds (a resend would 404). A 404 on apply: the record is gone (dropped 900 s after start, a dashboard restart, or an apply that already succeeded). The screen says the setup is no longer on the server and the settings may not be saved, and offers Start again.
- The profile is the chat's profile, in the start body and in both places on apply. `allowed_users` is checked in the app (digits, with an optional leading `+`, comma-separated) because the server does not. This is stricter than the bridge's allowlist (`allowlist.js`), which also takes `*` and JIDs/LIDs. Decision: the restriction is a non-goal, not a gap. `*` lets anyone message the agent, so it is not offered in a QR flow, and the screen refuses it with a note that it is a server setting. A blank list keeps the old one (and in `self-chat` becomes the linked phone).
- Only the generated client is used, through `authController.api!.raw`. The repository group lives beside the Telegram one in `hermes_messaging_repository.dart`; `_explaining` already maps 400, 404, 409 and 410 `detail`, and 500 `detail` is added for this group.

## Observability

Spans: `whatsapp.pair.start`, `whatsapp.pair.apply` (they cross the network; attributes `outcome`, `restart`). Log events through `AppEventLogger`: `whatsapp.pair.ended` with `status`, `whatsapp.pair.unavailable` (a route-missing 404 or a 405 on start from an old server, once per connection). Breadcrumbs: `whatsapp.pair.opened`, `whatsapp.pair.qr_shown`, `whatsapp.pair.applied`. None holds the QR, an id, a number, a name, a path, an error text or a profile.

## Design pass

No Claude Design canvas was built; the brief `docs/design-briefs/whatsapp-onboarding.md` was written from the design system README, the merged briefs and the shared widgets. Decisions that change behaviour:

- One pushed screen whose body follows the phase, like the Telegram screen; Finish closes both screens to the Bots list, which shows a banner with the outcome (success when a restart was requested and `needs_restart` is false, warning otherwise; never "restarted").
- Polling also pauses while App Lock is locked, not only in the background (the code is hidden then, so a stale poll has nothing to show). On unlock a handset needs the "Show QR code" tap again.
- The countdown is the setup's 600 s ("Setup closes in 8:42"), not the code's rotation, which is not verified. A last-minute warning is shown; it is announced at the minute, 30 s and 10 s only.
- A failed poll keeps the last state and adds an offline or unreachable banner ("This code may be out of date."); polling continues every 2 s.
- Back is disabled while apply is in flight (at most 10 s); no Cancel is sent then. After 10 s with no answer the lost-answer state shows, and Check ends within 10 s with "Couldn't confirm".
- Start again returns to the setup form with the earlier mode and numbers.
- The QR tile is black on white in both themes and does not scale with text size.
