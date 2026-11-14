# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Flutter client (iOS, Android, macOS, Windows, Linux) for the Hermes Agent web dashboard (`hermes dashboard`, from NousResearch/hermes-agent). The user enters a self-hosted server URL, signs in, and chats with the agent. The sign-in flow is specified in `openspec/specs/auth/spec.md`, and `openapi/README.md` covers the generated client.

## Commands

```bash
flutter pub get
flutter run
dart format .                     # CI runs: dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test test/auth_controller_refresh_test.dart          # one file
flutter test --plain-name "some test name"                   # one test
flutter gen-l10n                  # regenerate strings after an ARB edit, pull, rebase or merge (test/analyze don't)
                                  # `flutter pub get` does it too; analyze and the pre-commit hook fail until one of them ran after a pull that brings ARB changes
dart run tool/setup_git_hooks.dart  # installs the dart_pre_commit hook (format + analyze on staged Dart files); once per clone, shared by worktrees
flutter run -d macos -t widgetbook/main.dart   # component catalog (Widgetbook); see the `component-catalog` skill
```

Install the hook in every clone, cloud sessions included, before the first commit. A failing hook is fixed, never bypassed (no `--no-verify`, no `core.hooksPath` change, no edit of the `dart_pre_commit:` config). Its `outdated` check at level `major` fails a commit while a dependency is a major version behind, so dependency updates are part of normal work: `flutter pub upgrade`, raise the constraint, fix the break.

Every workflow installs the Flutter release pinned in `.fvmrc` (`flutter-version-file`; also what `fvm use` reads locally), and `update-flutter.yml` opens a PR each Monday when a newer stable ships, so bumping it is a one-line change. CI (`.github/workflows/ci.yml`) runs format and analyze, and the tests in four parallel jobs split by file (`scripts/test-shard.sh <index> 4`; shard 0 is the Widgetbook test alone); `Analyze & test`, the required check, passes once all of them did. A `Changes` job first diffs a pull request against its base: when only `docs/`, `openspec/` or Markdown files changed (so a skill's `SKILL.md`, but not a script beside it), the test shards, coverage, watch test and every platform build are skipped and `Analyze & test` still passes (no test reads those paths; if one starts to, take the path out of the filter in `ci.yml`). `Test watch core` runs only when `ios/HermesWatch`, `ios/HermesSurfaceKit` or `ci.yml` changed. On a pull request the five platform builds run only when native code, dependencies, assets or the workflow changed (the path list is in the `flutter-ci` skill), so a Dart-only PR skips them. A push to main or a manual run always runs everything, builds included, and a run on main in progress finishes while a queued one is replaced by the newer one, so read main's latest finished run for build breakage that a Dart-only PR could not show. Only pull-request runs are cancelled by a newer push. The Linux native audio test (`test/voice/native_voice_player_test.dart`) runs in its own job, `Test native audio (Linux)`, on every code pull request; the required check does not wait for it. Then it builds Android (release APK, debug-signed), Windows, iOS (simulator), macOS and Linux (release bundle, packaged by `scripts/package-linux.sh`). Releases attach a notarized macOS DMG (`fastlane mac dmg`), a Linux tar.gz and .deb (x86_64, arm64), an Android APK and AAB signed with the upload key, and an unsigned Windows x64 zip to the GitHub release; the `release` skill covers their signing. Every release is cut as a GitHub pre-release and its build goes to TestFlight; promoting one to a full release starts `app-store.yml`, which runs `fastlane submit` to send that version's TestFlight build to App Review on iOS and macOS, which goes live by itself once approved. It needs the `REVIEW_CONTACT_*` and `REVIEW_DEMO_*` (demo server URL, user, password) secrets. A version already in review or released is skipped, so promoting one you submitted by hand does no harm. Run it by hand with `dry_run` (the workflow's default input) to update the listing without submitting. The iOS build needs the watchOS platform installed and an explicit simulator: `flutter build ios --simulator -d <udid>`.

Commits follow Conventional Commits; release-please builds `CHANGELOG.md` and bumps `pubspec.yaml` from them. Don't edit the version by hand.

### Running against a real backend

- `scripts/dev-backend.sh start|stop|url` runs a throwaway Hermes dashboard on an OS-assigned port with its own `HERMES_HOME` (needs `hermes` on PATH).
- `scripts/dev-app.sh start|reload|restart|screenshot|logs|stop` runs the macOS app against it and can screenshot the window. State lives in `.dart_tool/hermes-dev/`.
- `scripts/store-screenshots.sh ios|mac|finish` retakes the App Store and README screenshots; the `store-screenshots` skill (`.claude/skills/store-screenshots/SKILL.md`) has the procedure and the traps.
- The `verify-in-app` skill (`.claude/skills/verify-in-app/SKILL.md`) has the full loop and its rules. Never point the app or `hermes` at the real `~/.hermes`, and never run `hermes dashboard --stop`.
- Building the macOS app rewrites tracked `ios/` and `macos/` Xcode files. Stage files by name, never `git add -A`, and `git restore` those afterwards.
- `test/real_backend_contract_test.dart` checks response shapes against a live backend and skips unless `HERMES_DEV_URL` is set. Free loopback scripted-model turns run without provider credentials. Paid-provider tests need `HERMES_DEV_MODEL_CALLS=1`; external Telegram pairing needs `HERMES_DEV_TELEGRAM_PAIRING=1`; the Bot Screen checks require a running screen with `HERMES_DEV_BOT_SCREEN=1` (a Linux backend, see the `verify-bot-screen` skill). CI leaves all three flags unset. The standalone `real-backend-contract.yml` remains advisory and resolves its source revision from matching `openapi/HERMES_REF` and `openrpc/HERMES_REF` through `python3 -I scripts/hermes_contracts.py resolve`. Its summary distinguishes setup, tests, and cleanup outcomes. The pinned backend uses Python 3.14.

### Regenerating the API client

```bash
scripts/fetch_openapi_spec.sh [ref]       # rebuild openapi/ from hermes-agent main or a ref; needs gh, curl, uv
./scripts/generate_hermes_api_client.sh   # needs a JDK (npx openapi-generator-cli) and dart on PATH
```

`update-hermes-contracts.yml` runs both every Monday, refreshes `openrpc/` from the same Hermes commit, and opens one PR when contract JSON or either provenance file changes. It regenerates the Dart client only when OpenAPI JSON changes. Run `python3 -I scripts/test_hermes_contracts.py` to check revision resolution and update detection.

`verify-hermes-api-client.yml` fails CI if `openapi/`, `scripts/` or `packages/hermes_api/` change without a matching regenerated client. Never hand-edit `packages/hermes_api`. Fix template bugs in `scripts/patch_openapi_for_dart.py` or `scripts/patch_generated_dart_client.py`. `packages/hermes_api/pubspec.lock` is committed on purpose.

## Architecture

Before changing an area, read its file under `docs/architecture/` ([index](docs/architecture/README.md)). Each file holds the full description of its area; this map only names where things live and the rules that are easiest to break. When you change an area's behaviour, update its file there, not this one.

- **App shell and navigation** (`lib/main.dart`, `lib/src/app.dart`, `lib/src/shell/`, `lib/src/profiles/`): the screen follows `AuthController.state` alone, with no named routes; `AuthController` owns the whole connection lifecycle and the authenticated `Dio`. Picking a chat profile never changes the server's active profile; most features send the chat's profile explicitly, but Kanban requests (`lib/src/kanban/`) send no `profile`, since every profile shares the board. Kanban and Schedules (`lib/src/schedules/`) tabs exist only while the server offers them. When `appPlatformHint` changes, add the old text to `earlierAppPlatformHints` (`lib/src/platform_hint/`). [app-shell.md](docs/architecture/app-shell.md)
- **Server care** (`lib/src/server_care/`): the Server screen shows status, update, the messaging gateway (not the chat gateway), logs, usage and a server check; `AppShell` owns the status, gateway, update and check controllers. The restart, update and doctor POSTs are never resent (a lost answer is followed); doctor never runs with `--fix`; copied commands are never run; log lines and check reports live in memory only and are dropped on App Lock cover, sign-out, server change and profile switch. [app-shell.md](docs/architecture/app-shell.md)
- **Auth** (`lib/src/auth/`): one RFC 8252 loopback + PKCE flow for OIDC and password; concurrent 401s must not sign the user out and sign-in must never be left spinning; secure-store mutations go through the SQLite session lock and never overwrite a newer pair; cleartext `http://` only for local hosts (`isLocalHost`) unless the user confirmed it (`allowCleartext`). [auth.md](docs/architecture/auth.md)
- **Headless runtime** (`lib/src/background/`): work without a screen goes through `withHeadlessHermes`, never its own `AuthController`, and never clears the stored session. [headless-runtime.md](docs/architecture/headless-runtime.md)
- **Chat** (`lib/src/chat/`): `ChatController` and `ChatScreen` are split into private library parts; keep a feature change in its part. Composer, activity tiers, branching, model pill, search and Mac sidebar are there too. [chat.md](docs/architecture/chat.md)
- **Server files** (`lib/src/files/`, `lib/src/chat/media/`): the Files page of a chat reads the chat's working folder over `/api/fs/*`, not `/api/files/*`. Hermes has two route families that look alike: `/api/files` ("managed files": the dashboard host's disk only, never the profile's SSH workspace, no `profile`, one locked root, uploads) and `/api/fs` (the desktop app's family: follows the profile to the machine the agent works on, `profile` on every route, no root). The app uses `/api/fs` only (`list`, `git-root`, `default-cwd`, `read-text`, `download`) and leaves `/api/files` to `MEDIA:` attachments and later upload and delete. Only the first `default-cwd` goes without `profile`, and its folder is thrown away (`FilesAvailability`: 404 or 405 hides every entry point, any other failure does not). The highest folder is the server-resolved git root of the start (else the start): the client never requests a path outside it, and every path is one the server returned (`ServerPath`, no join). Downloads stream through `MediaStore.stageDownload` (`.part`, never in memory; Save copies by path through `FileExport`), a text file is read with `read-text` first (512 KB), and nothing downloads without a tap. Secret-looking names (`SecretNames`) ask first, are cached under the `fs-secret:` prefix and deleted when their preview closes; every Files download goes on sign-out and when App Lock locks (`MediaStore.clearFileDownloads`, `FilesLockCleanup`). A preview is covered while the app is inactive; no path, name or content reaches a breadcrumb, span or log. On Windows no Open with… for runnable types and the Mark of the Web on staged files (`FilesPlatformPolicy`). [chat.md](docs/architecture/chat.md)
- **Gateway transport** (`lib/src/chat/gateway/`): JSON-RPC over `/api/ws`; sessions send `source: hermes_app`, `prompt.submit` is never resent, and a dropped reply reconnects and replays by `seq`. [gateway.md](docs/architecture/gateway.md)
- **Deep links** (`lib/src/deep_links/`): every `hermes://` link is built with `deepLinkUri` and read with `parseDeepLink`, never by hand; a link's `prompt` goes under the composer's draft and is never sent, and `dictate=1` only starts the microphone when the profile offers it. [deep-links.md](docs/architecture/deep-links.md)
- **Voice** (`lib/src/voice/`, `packages/hermes_speech`): a transcript is never sent unless the user presses send (and nothing after a failed transcription); on Apple platforms the device recognizer is the default. [voice.md](docs/architecture/voice.md)
- **Bot Mode** (`lib/src/bot_mode/`): hosted group rooms over `groups.*` RPCs, roster and Bot Chat registries. [bot-mode.md](docs/architecture/bot-mode.md)
- **Bot Screen** (`lib/src/bot_screen/`): display calls always send an explicit `profile`; tickets, viewer ids, frames, passwords and anything typed are never stored or logged; input goes only on the stream that holds the lease. [bot-screen.md](docs/architecture/bot-screen.md)
- **Settings screens** (`lib/src/widgets/settings_scaffold.dart`, `lib/src/plugins/`, `lib/src/mcp/`, `lib/src/settings/`): shared `SettingsScaffold` chrome; MCP command servers are never sent without the reviewer's confirmation. [settings-screens.md](docs/architecture/settings-screens.md)
- **Memory** (`lib/src/memory/`): settings, reset and proposals, always with an explicit profile; Approve all sends one command per id, never `all`. [memory.md](docs/architecture/memory.md)
- **Notifications and background work** (`lib/src/notifications/`, `lib/src/background/`, `lib/src/schedules/`, `lib/src/agent_messages/`, `lib/src/live_activities/`): a background run never signs the user out and announces nothing while the app is in front. On macOS the time-sensitive entitlement is added only by the fastlane lane, never checked in. [notifications-and-background.md](docs/architecture/notifications-and-background.md)
- **System surfaces** (`lib/src/surfaces/`, `lib/src/quick_actions/`, `lib/src/intents/`, `lib/src/spotlight/`): extensions read only the surface snapshot, which never holds a token, server address or identity. Add a new widget's kind to `kSurfaceWidgetKinds` so snapshot writes reload it. [surfaces-and-intents.md](docs/architecture/surfaces-and-intents.md)
- **Watch** (`lib/src/watch/`, `ios/HermesWatch`, `ios/HermesComplication`): the watch has no network of its own; complications carry the turn's state and, once the chat is named, its title (only the state under App Lock), never message text or the prompt. [watch.md](docs/architecture/watch.md)
- **Telemetry** (`lib/src/telemetry/`): off unless `OTEL_EXPORTER_OTLP_ENDPOINT` is set and must never break the app; server details are `hermes.*` span attributes, never resource attributes. [telemetry.md](docs/architecture/telemetry.md)
- **macOS** (`lib/src/macos/`, `lib/src/windows/`, `lib/src/drag_out/`, `lib/src/quick_panel/`): menu bar commands come from `MacCommandScope`; don't add a key handler for a chord the menu owns; conversation windows hold no session. [macos.md](docs/architecture/macos.md)
- **Native pieces** (`ios/`, `macos/` Runners, extensions, `ios/HermesSurfaceKit`): bundle IDs, BGTask registration and extension wiring. Traps: every macOS extension's Debug bundle ID must be prefixed with `com.cedricziel.hermesApp.dev`; `ios/ShareExtension` links `receive_sharing_intent` by a version-pinned path, so a plugin upgrade must be mirrored in `project.pbxproj`; renaming the `HermesLiveActivity` target would orphan its provisioning profile. [native.md](docs/architecture/native.md)
- **Localization** (`lib/l10n/`, `l10n.yaml`): user-visible text goes in `lib/l10n/arb/app_en.arb` and `app_de.arb` under its area's `@@x-area-<dir>` anchor, read with `context.l10n`; never strings below the widget layer, never telemetry names, ids or server values; only `kReleasedLocales` is offered. [localization.md](docs/architecture/localization.md)

**Privacy rules for every change.** Breadcrumbs, app event logs and feature spans carry fixed names, counts, flags and outcomes only: never message text, titles, profile names, server addresses, ids, tokens or passwords. Two deliberate exceptions, both bound for the operator's own SignalDB: the crash reporter logs uncaught errors with full message, stack trace and breadcrumbs, and spans and request logs describe their server with `hermes.*` attributes (version, install ID and the like). The surface snapshot, notifications, the Lock Screen and Siri never get content beyond what a notification body already allows, and App Lock blanks titles and text. Secrets (tokens, passwords, credentials typed into a screen) stay in secure storage or screen state and are never written to preferences or logs.

**Two API layers.**

- `packages/hermes_api` is a generated `dart-dio` client for the backend's OpenAPI spec (`openapi/hermes-agent.openapi.json`). Reach it through `authController.api!.raw`, which shares the managed `Dio`, instead of adding hand-rolled calls.
- `lib/src/api/hermes_api_client.dart` hand-writes only `/api/status`, `/api/auth/providers` and `/api/auth/me`, because the spec has no response schemas for them. It also hand-writes the Kanban attachment download (`fetchKanbanAttachment`), because the generated method decodes the body as JSON and cannot return a file's bytes. `downloadFsFile` (`/api/fs/download`) streams a server file into a sink for the same reason: the generated method decodes JSON and cannot stream bytes.
- Many routes (sessions, profiles, messaging, skills, plugins) also lack response schemas, so the generated methods return untyped JSON. The repositories (`chat/hermes_chat_repository.dart`, `profiles/`, `messaging/`, `skills/`, `plugins/`, `schedules/hermes_cron_repository.dart`) parse those rows leniently and skip rows that don't fit. The contract test above guards these shapes.

## Testing conventions

Tests drive the real generated client and Dio pipeline against `test/support/fake_hermes_server.dart`, an `HttpClientAdapter` with per-route responses, rather than mocking the client. Other helpers in `test/support/`: `fake_chat_transport.dart`, `memory_token_store.dart`, `fake_share_inbox.dart`, `pump_chat.dart`.

`test/workflows/` walks whole user flows (onboarding, chat, kanban, skills/messaging/settings) on phone and desktop, light and dark, and saves a screenshot per step to `build/workflow_screenshots/` (`workflow-screenshots` skill). Look at them after a UI change.

`widgetbook/` is a Widgetbook catalog of single widgets in each state (`component-catalog` skill). **UI work starts in the catalog, not in the app.** A new screen or a redesign first gets a design pass (`design-pass` skill). For any new widget, redesign or layout/state change, build or change it as a use case first, as a plain-model widget (models and callbacks, no controller or repository), and get every state, both themes and phone and desktop width right there. Only then wire it into a screen, and check the screen with a workflow test or `verify-in-app`. A widget a screen builds inline gets pulled out into `lib/src/*/widgets/` so it can have a use case. `test/widgetbook_test.dart` builds every use case in both themes, and `widgetbook.yml` publishes the catalog to GitHub Pages from `main` (`scripts/build-widgetbook.sh` builds it).

## Specs

`openspec/` holds spec-driven change proposals (`openspec/specs/` for current behavior, `openspec/changes/` for work in progress). Start a change with `/opsx:propose "<idea>"`; project context for it lives in `openspec/config.yaml`. Design history lives under `openspec/changes/archive/`.

`docs/roadmap.md` is the checklist of planned and running work, with what is blocked and why. When a review, a CI run or your own work turns up something that the current PR does not fix, add it to its "Found along the way" table; do not leave it only in a PR description. Update an item's status in the PR that changes it.

## Skills

Project skills live in `.claude/skills/<name>/SKILL.md` (frontmatter `name` and a `description` that says when to use it). When you learn something reusable about working in this repo, such as a workflow, a gotcha or a verification step, write it to a skill rather than to memory, so it is checked in and shared.

- Amend the existing skill when the new knowledge fits it. Fix a skill that turns out to be wrong or stale as soon as you notice.
- Create a new skill when the knowledge is a distinct, repeatable task no current skill covers. Keep the description specific enough that it triggers at the right time.
- Use memory only for things that are personal to the user or don't belong in the repo.
- Commit skill changes with the work that prompted them, or on their own as `docs:`.

## Dependencies

Before writing platform or infrastructure code by hand (storage, permissions, sharing, notifications, deep links, auth flows, and the like), check pub.dev for a mature, maintained plugin and prefer it over a homegrown implementation. Judge maturity by recent releases, publisher, platform coverage, popularity and open issues. If none fits, say why in the PR. The existing choices (`flutter_chat_ui`, `receive_sharing_intent`, the generated `hermes_api` client) follow this rule.
