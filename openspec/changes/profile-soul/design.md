# Design

## Context

Read in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`), `/tmp/h/hermes-agent`. Platforms: iOS, iPadOS, Android, macOS, Windows, Linux; not watchOS. No native, entitlement or manifest change. Invariants touched: explicit profile (the name is in the path), no content in telemetry, 401s handled by the existing sign-in path.

## Server surface

Both routes are in `openapi/hermes-agent.openapi.json` (`/api/profiles/{name}/soul`) with a path `name` and no response schema. Generated methods: `getProfileSoulApiProfilesNameSoulGet(name:)` and `updateProfileSoulApiProfilesNameSoulPut(name:, profileSoulUpdate:)` (`ProfileSoulUpdate` has one field, `content`), both returning untyped `Response<Object>`. The repository calls them through `authController.api!.raw` and parses leniently. Nothing is hand-written.

- **Handlers**: `hermes_cli/web_routers/profiles.py`, `get_profile_soul` and `update_profile_soul`. Body model `ProfileSoulUpdate` in `hermes_cli/web_models.py`: `content: str`, required, no length limit.
- **Auth**: neither path is in `dashboard_auth/public_paths.py`, so `auth_middleware` (`web_server.py`) answers 401 `{"detail": "Unauthorized"}` without the session. Hermes has no roles; anyone signed in may read and write.
- **Profile**: `_resolve_profile_dir` (`web_server_profiles.py`) checks `validate_profile_name(name)` as given (lowercase id, up to 64 characters, `default` allowed, reserved names refused) and `profile_exists`, then uses that profile's directory directly. The profile need not be the dashboard's own or the active one; the route does not scope `HERMES_HOME`. `default` is `~/.hermes`. Errors: 400 with the validator's text; 404 `Profile '<name>' does not exist.` (a deleted profile counts as missing). A 404 is ambiguous: a detail starting `Profile '` is a missing profile; any other 404 (an old server's `No such API endpoint: /api/...`, or `{"error": ...}` when headless) means the server lacks the route, and a PUT to a missing route can answer 405 (the catch-all serves GET only). The app tells them apart by the detail text and never treats every 404 as an old server.
- **GET** returns `{"content": "<text>", "exists": true}`, or `{"content": "", "exists": false}` when the file is absent. An empty file is `{"content": "", "exists": true}` (tests in `tests/hermes_cli/test_web_profile_soul_writes.py`). It reads `utf-8-sig`, so a leading BOM is dropped. An `OSError` is 500 `Could not read SOUL.md: <error>`. Invalid UTF-8 raises `UnicodeDecodeError`, which the handler does not catch: a plain 500 `Internal Server Error` (read from the code, not run).
- **PUT** `{"content": "<text>"}` replaces the whole file with `utils.atomic_write_text` (temp file, fsync, rename; existing mode and owner kept, 0644 on first write). Answers `{"ok": true}`. An `OSError` is 500 `Could not write SOUL.md: <error>`; the old file survives (tested). Missing or non-string `content` is 422 with FastAPI's `detail` list. A lone surrogate cannot be encoded and would be an uncaught 500; a Flutter text field does not produce one in normal use.
- **Size limit**: none on the route (the 64 KB body limit in `dashboard_auth/body_limit.py` covers public `/auth/` posts only). The limit is on use: `agent/prompt_builder.py` `load_soul_md` truncates head and tail with a marker beyond `context_file_max_chars`, default `max(20,000, min(6% of the model window in characters, 500,000))` (`_get_context_file_max_chars`). That 500,000 is only the dynamic cap: an explicit `context_file_max_chars` in `config.yaml` wins with no ceiling, so a server may allow more.
- **Empty save**: `load_soul_md` strips the text and returns nothing when it is empty, and `system_prompt._identity_parts` then uses the built-in default identity. So saving empty text means "use Hermes' default personality". The file stays (`exists: true`). `hermes_cli/config.py` seeds a default SOUL.md on first run, so `exists: false` is rare.
- **When a chat picks it up**: the system prompt is built once per session and stored; a continuing session reuses the stored text (`agent/conversation_loop.py`, `_restore_or_build_system_prompt`). A change reaches **new chats only**. The one exception is Bot Chat sessions, which rebuild when the file's hash changes (`tools/bot_mode_probe.py`, `capability_fingerprint`, `stored_prompt_capability_stale`).
- **Not the Bot Mode field**: `BotModeDetails.soul` and `save(soul:)` in `lib/src/bot_mode/bot_mode_roster_repository.dart` use the gateway RPCs `profiles.describe` and `profiles.configure` (`tui_gateway/methods_profiles.py`), which read and write the same `SOUL.md` (a plain, non-atomic `write_text`, lossy decode). Same file, other route, other writer. The user's text in one is what the other shows.
- **Other writers**: the Bots sheet, the agent's own file tools (gated by Hermes' protected-file approval), a shell or editor on the host, and `hermes profile update` for a distribution-owned SOUL.md (`load_soul_md` also treats that file as untrusted and may block it in the prompt; the route does not say so).
- **Conflicts**: no version, etag, mtime or hash in either response and no precondition on PUT. It is last write wins.

Could not verify: no backend was run for this note, so the 422 body, the plain-text 500 and the BOM and surrogate behaviour come from reading the code. Task 2.1 records them from `scripts/dev-backend.sh`.

## What the app has

Profile list and per-profile destinations: `lib/src/profiles/` (`ChatProfiles`, `HermesProfilesRepository`, `MacProfilesPage` with `ProfileSection`), the chat sidebar's per-profile rows (Skills, Memory, Plugins, MCP, Helper models; `thread_sidebar.dart`, `chat_screen_navigation.dart`), and `openMemory` as the model for a per-profile screen with a breadcrumb. No SOUL route is used in `lib/`; the generated methods exist. Bot Mode edits the soul only through RPC.

## Decisions

**Wording.** The screen is "Personality"; a footnote says it is Hermes' SOUL.md file, the only place the file name appears (owner decision). "Soul" is Hermes' word and means little to most people.

**Where it opens.** A Personality row right after Memory in the sidebar drawer and More section (the chat's profile), and a Personality section after Memory on the Mac Profiles page (the selected profile). Both pass the profile name into the path. The row is always shown; a route-missing 404 (detail not starting `Profile '`) or a 405 hides it for the rest of the connection.

**Editor.** One multiline field, no autosave. Autocorrect, suggestions, smart quotes and smart dashes off (the text is instructions and Markdown). A count of characters sits under it. At 20,000 characters a note says "Hermes may shorten text this long when it builds a chat. The limit depends on your server's settings." It does not block, at any length: Hermes has no fixed ceiling (an explicit `context_file_max_chars` has none), so the app never locks the editor.

**Dirty state.** Save and Revert are always visible and enabled only when the text differs from the last loaded or saved text. Leaving with unsaved changes asks "Discard changes?", default Keep editing. The text is never persisted, so a crash loses it; that is accepted over writing prompts to disk. App Lock drops unsaved edits at once, with no grace period and nothing kept in memory (owner decision).

**Save question.** Always asked, on every save, because it replaces the whole file. Title "Replace the personality of <profile>?" (the profile name is shown, never logged). Body: "New chats use it. Chats already running usually keep the old one; Bot Chats may pick it up." For empty text: "Hermes will use its default personality. Chats already running usually keep the old one; Bot Chats may pick it up." (Bot Chat sessions rebuild when the file's hash changes; see Server surface.) After a Check that found the earlier text, the question adds "An earlier save may still be pending on the server." Buttons Cancel (default) and Replace.

**Conflicts.** The controller keeps `baseline = (exists, content)` from the last read or save. On Replace it first does a second GET, which gives up after 10 s (a controller-level timeout, like `kFilesAnswerTimeout`); the PUT has the same bound. If the read equals the text about to be sent (an unconfirmed earlier save landed), it reports Saved and moves the baseline without sending. If it differs from the baseline, nothing is sent and the user sees "Changed on the server": "This file changed since you opened it. Replacing it will lose those changes." with Show server's version (read-only text with a Copy button), Keep editing (default) and Replace anyway (sends, then the baseline is the sent text). If the check read fails or times out, nothing is sent and the error is shown with Try again. The window between the check and the PUT is one round trip and stays open; the screen says nothing about it, the docs here do.

**Lost answer.** A timeout or dropped connection on the PUT is "Couldn't confirm the save. It may have gone through." The text stays in the editor, nothing is resent, and Save does not read as done. The row offers Check: a user-tapped GET compared with the text that was sent (the editor may have changed since); outcomes are in the Design pass section. A PUT that times out after 10 s is this state. A 200 without `ok: true` is treated as unconfirmed. Errors 400, 404, 422 and 500 show a fixed line, never the response body (it can hold paths).

**Profile switch.** The screen is bound to one profile name. Switching the chat's profile while it is open does not change it; its title names the profile. Late answers after close are dropped.

## Observability

Recorded where the controller calls the repository. None holds text, titles, profile names, ids or error bodies.

- Span `profile_soul.fetch` (attributes: `outcome`, `exists`) and `profile_soul.save` (`outcome`, `empty`, `length_bucket`: `lt_1k`, `lt_5k`, `lt_20k`, `gte_20k`), both with `hermes.*` server attributes.
- Log event `profile_soul.saved` with `outcome` in `saved`, `conflict_kept`, `conflict_replaced`, `failed`, `unconfirmed`, plus `empty`.
- Breadcrumbs `profile_soul.opened` (`source`: `sidebar`, `profiles_page`) and `profile_soul.save.confirmed`.

## Design pass

Status: Design: brief reviewed, canvas pending (publish quota, resumes after 2026-11-15 00:00 UTC). The full record is `docs/design-briefs/profile-soul.md`; a Design canvas is started and incomplete (https://claude.ai/artifact/P2oqCBdLmdviWpGWmZmRjB, private, partly published), so no build starts before it exists. Decisions that change behaviour:

- **Check outcomes.** After a lost answer, Check reads the file and compares it with the text that was sent, not the editor. Equal to the sent text (the file exists and its content matches; a missing file never confirms, even when both texts are empty): Saved, the baseline becomes that text and edits made since stay dirty. Equal to the old baseline: the screen says "The server still has the earlier text. Your text is still here." and keeps the text (no conflict question, since nothing changed on the server). It is not a definite failure, because a timed-out PUT can still land later; the next Save asks again with the extra pending-save line. Anything else: the changed-on-server question.
- **Unconfirmed save that landed.** Save after a lost answer still reads first; if the server's text equals the text about to be sent it reports Saved and moves the baseline without a PUT.
- **App Lock in flight.** A running check or PUT finishes, its outcome is discarded, and the unlocked screen reloads the server's text.
- **Read-only while busy.** The editor is read-only while the check read and the PUT run, so the baseline cannot race the text.
- **Revert asks.** Revert and every leave (back, window close) ask "Discard changes?", default Keep editing.
- **Read failure shows no editor.** A failed or 500 read never shows an empty editor, so the user cannot save over a file the app could not read.
- **No locked state.** The proposal's "too long to edit" state does not exist; the editor stays editable at any length.
- **Changed-on-server is a sheet** (dialog on wide windows) holding the server's text behind a disclosure; if the file is gone on the server, it says so.
- **Mac Profiles page** row pushes the same page with a bar as on other platforms, so the Discard question is asked on back and window close; there is no profile or section change beside an open editor.
- **Layout and chrome.** The editor is a filled field (surface-high token) while editable and transparent while read-only; it follows the grouped list's width (about 600 pt on a Mac, 640 pt on an iPad). The `AppBanner` action stacks under the text at the largest text size and in German, aligned to the text's leading edge, and every banner action has a minimum target of 44 pt, 48 dp or 28 pt by construction. Material uses the same grouped-card editor. Revert aligns to the note and status text. A cleared editor shows the default-personality line at once. Material confirmations are two text buttons, Cancel first, through `showConfirmDialog(cancelIsDefault: true)`. The changed-on-server sheet caps the server's text box at 40% of the height, with Copy. The save error banner is title "Couldn't save" with detail "Hermes reported a problem. Nothing was changed on the server."; the failed-check banner is "Couldn't confirm" with "Check again".
- **Input hardening.** The editor turns off autocorrect, suggestions, smart punctuation, autofill, keyboard learning and restoration.
