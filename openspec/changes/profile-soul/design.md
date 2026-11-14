# Design

## Context

Read in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`), `/tmp/h/hermes-agent`. Platforms: iOS, iPadOS, Android, macOS, Windows, Linux; not watchOS. No native, entitlement or manifest change. Invariants touched: explicit profile (the name is in the path), no content in telemetry, 401s handled by the existing sign-in path.

## Server surface

Both routes are in `openapi/hermes-agent.openapi.json` (`/api/profiles/{name}/soul`) with a path `name` and no response schema. Generated methods: `getProfileSoulApiProfilesNameSoulGet(name:)` and `updateProfileSoulApiProfilesNameSoulPut(name:, profileSoulUpdate:)` (`ProfileSoulUpdate` has one field, `content`), both returning untyped `Response<Object>`. The repository calls them through `authController.api!.raw` and parses leniently. Nothing is hand-written.

- **Handlers**: `hermes_cli/web_routers/profiles.py`, `get_profile_soul` and `update_profile_soul`. Body model `ProfileSoulUpdate` in `hermes_cli/web_models.py`: `content: str`, required, no length limit.
- **Auth**: neither path is in `dashboard_auth/public_paths.py`, so `auth_middleware` (`web_server.py`) answers 401 `{"detail": "Unauthorized"}` without the session. Hermes has no roles; anyone signed in may read and write.
- **Profile**: `_resolve_profile_dir` (`web_server_profiles.py`) checks `validate_profile_name(name)` as given (lowercase id, up to 64 characters, `default` allowed, reserved names refused) and `profile_exists`, then uses that profile's directory directly. The profile need not be the dashboard's own or the active one; the route does not scope `HERMES_HOME`. `default` is `~/.hermes`. Errors: 400 with the validator's text; 404 `Profile '<name>' does not exist.` (a deleted profile counts as missing). A server without the route answers 404 `Not Found`, so the app tells the two apart by the detail text.
- **GET** returns `{"content": "<text>", "exists": true}`, or `{"content": "", "exists": false}` when the file is absent. An empty file is `{"content": "", "exists": true}` (tests in `tests/hermes_cli/test_web_profile_soul_writes.py`). It reads `utf-8-sig`, so a leading BOM is dropped. An `OSError` is 500 `Could not read SOUL.md: <error>`. Invalid UTF-8 raises `UnicodeDecodeError`, which the handler does not catch: a plain 500 `Internal Server Error` (read from the code, not run).
- **PUT** `{"content": "<text>"}` replaces the whole file with `utils.atomic_write_text` (temp file, fsync, rename; existing mode and owner kept, 0644 on first write). Answers `{"ok": true}`. An `OSError` is 500 `Could not write SOUL.md: <error>`; the old file survives (tested). Missing or non-string `content` is 422 with FastAPI's `detail` list. A lone surrogate cannot be encoded and would be an uncaught 500; a Flutter text field does not produce one in normal use.
- **Size limit**: none on the route (the 64 KB body limit in `dashboard_auth/body_limit.py` covers public `/auth/` posts only). The limit is on use: `agent/prompt_builder.py` `load_soul_md` truncates head and tail with a marker beyond `context_file_max_chars`, default `max(20,000, min(6% of the model window in characters, 500,000))` (`_get_context_file_max_chars`).
- **Empty save**: `load_soul_md` strips the text and returns nothing when it is empty, and `system_prompt._identity_parts` then uses the built-in default identity. So saving empty text means "use Hermes' default personality". The file stays (`exists: true`). `hermes_cli/config.py` seeds a default SOUL.md on first run, so `exists: false` is rare.
- **When a chat picks it up**: the system prompt is built once per session and stored; a continuing session reuses the stored text (`agent/conversation_loop.py`, `_restore_or_build_system_prompt`). A change reaches **new chats only**. The one exception is Bot Chat sessions, which rebuild when the file's hash changes (`tools/bot_mode_probe.py`, `capability_fingerprint`, `stored_prompt_capability_stale`).
- **Not the Bot Mode field**: `BotModeDetails.soul` and `save(soul:)` in `lib/src/bot_mode/bot_mode_roster_repository.dart` use the gateway RPCs `profiles.describe` and `profiles.configure` (`tui_gateway/methods_profiles.py`), which read and write the same `SOUL.md` (a plain, non-atomic `write_text`, lossy decode). Same file, other route, other writer. The user's text in one is what the other shows.
- **Other writers**: the Bots sheet, the agent's own file tools (gated by Hermes' protected-file approval), a shell or editor on the host, and `hermes profile update` for a distribution-owned SOUL.md (`load_soul_md` also treats that file as untrusted and may block it in the prompt; the route does not say so).
- **Conflicts**: no version, etag, mtime or hash in either response and no precondition on PUT. It is last write wins.

Could not verify: no backend was run for this note, so the 422 body, the plain-text 500 and the BOM and surrogate behaviour come from reading the code. Tasks 1.1 records them from `scripts/dev-backend.sh`.

## What the app has

Profile list and per-profile destinations: `lib/src/profiles/` (`ChatProfiles`, `HermesProfilesRepository`, `MacProfilesPage` with `ProfileSection`), the chat sidebar's per-profile rows (Skills, Memory, Plugins, MCP, Helper models; `thread_sidebar.dart`, `chat_screen_navigation.dart`), and `openMemory` as the model for a per-profile screen with a breadcrumb. No SOUL route is used in `lib/`; the generated methods exist. Bot Mode edits the soul only through RPC.

## Decisions

**Wording.** The screen is "Personality"; a footnote says it is Hermes' SOUL.md file. "Soul" is Hermes' word and means little to most people.

**Where it opens.** A Personality row right after Memory in the sidebar drawer and More section (the chat's profile), and a Personality section after Memory on the Mac Profiles page (the selected profile). Both pass the profile name into the path. The row is always shown; a 404 `Not Found` hides it for the rest of the connection.

**Editor.** One multiline field, no autosave. Autocorrect, suggestions, smart quotes and smart dashes off (the text is instructions and Markdown). A count of characters sits under it. At 20,000 characters a note says "Hermes may shorten text this long when it builds a chat. The limit depends on your server's settings." It does not block. Above 500,000 characters (Hermes' own ceiling) the text opens read-only with "Too long to edit here", since no setting uses more.

**Dirty state.** Save and Revert are enabled only when the text differs from the last loaded or saved text. Leaving with unsaved changes asks "Discard changes?", default Keep editing. The text is never persisted, so a crash loses it; that is accepted over writing prompts to disk.

**Save question.** Always asked, on every save, because it replaces the whole file. Title "Replace the personality of <profile>?" (the profile name is shown, never logged). Body: "New chats use it. Chats already running keep the old one." For empty text: "Hermes will use its default personality." Buttons Cancel (default) and Replace.

**Conflicts.** The controller keeps `baseline = (exists, content)` from the last read or save. On Replace it first does a second GET. If it differs from the baseline, nothing is sent and the user sees "Changed on the server": "This file changed since you opened it. Replacing it will lose those changes." with Show server's version (read-only text, copy by tap), Keep editing (default) and Replace anyway (sends, then the baseline is the sent text). If the check read fails, nothing is sent and the error is shown with Try again. The window between the check and the PUT is one round trip and stays open; the screen says nothing about it, the docs here do.

**Lost answer.** A timeout or dropped connection on the PUT is "Couldn't confirm the save. It may have gone through." The text stays in the editor, nothing is resent, and Save does not read as done. The row offers Check: a user-tapped GET; if the server's text equals the editor's it reports Saved and resets the baseline, otherwise it shows the conflict question. A 200 without `ok: true` is treated as unconfirmed. Errors 400, 404, 422 and 500 show a fixed line, never the response body (it can hold paths).

**Profile switch.** The screen is bound to one profile name. Switching the chat's profile while it is open does not change it; its title names the profile. Late answers after close are dropped.

## Observability

Recorded where the controller calls the repository. None holds text, titles, profile names, ids or error bodies.

- Span `profile_soul.fetch` (attributes: `outcome`, `exists`) and `profile_soul.save` (`outcome`, `empty`, `length_bucket`: `lt_1k`, `lt_5k`, `lt_20k`, `gte_20k`), both with `hermes.*` server attributes.
- Log event `profile_soul.saved` with `outcome` in `saved`, `conflict_kept`, `conflict_replaced`, `failed`, `unconfirmed`, plus `empty`.
- Breadcrumbs `profile_soul.opened` (`source`: `sidebar`, `profiles_page`) and `profile_soul.save.confirmed`.

