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
pre-commit install                # hooks run dart format + flutter analyze on staged Dart files
```

CI (`.github/workflows/ci.yml`) runs format, analyze and test, then builds Android (debug APK), iOS (simulator), macOS and Linux (release bundle, packaged by `scripts/package-linux.sh`). Releases attach a Linux tar.gz and .deb (x86_64, arm64) to the GitHub release. Every release is cut as a GitHub pre-release and its build goes to TestFlight; promoting one to a full release starts `app-store.yml`, which runs `fastlane submit` to send that version's TestFlight build to App Review on iOS and macOS (release stays manual). It needs the `REVIEW_CONTACT_*` secrets. A version already in review or released is skipped, so promoting one you submitted by hand does no harm. Run it by hand with `dry_run` (the workflow's default input) to update the listing without submitting. The iOS build needs the watchOS platform installed and an explicit simulator: `flutter build ios --simulator -d <udid>`.

Commits follow Conventional Commits; release-please builds `CHANGELOG.md` and bumps `pubspec.yaml` from them. Don't edit the version by hand.

### Running against a real backend

- `scripts/dev-backend.sh start|stop|url` runs a throwaway Hermes dashboard on an OS-assigned port with its own `HERMES_HOME` (needs `hermes` on PATH).
- `scripts/dev-app.sh start|reload|restart|screenshot|logs|stop` runs the macOS app against it and can screenshot the window. State lives in `.dart_tool/hermes-dev/`.
- `scripts/store-screenshots.sh ios|mac|finish` retakes the App Store and README screenshots; the `store-screenshots` skill (`.claude/skills/store-screenshots/SKILL.md`) has the procedure and the traps.
- The `verify-in-app` skill (`.claude/skills/verify-in-app/SKILL.md`) has the full loop and its rules. Never point the app or `hermes` at the real `~/.hermes`, and never run `hermes dashboard --stop`.
- Building the macOS app rewrites tracked `ios/` and `macos/` Xcode files. Stage files by name, never `git add -A`, and `git restore` those afterwards.
- `test/real_backend_contract_test.dart` checks the response shapes the repositories parse against a live backend. It skips unless `HERMES_DEV_URL` is set. Tests that call a model also need `HERMES_DEV_MODEL_CALLS=1`, and the Telegram pairing test needs `HERMES_DEV_TELEGRAM_PAIRING=1`. It runs in CI as a non-required check (`real-backend-contract.yml`, Hermes pinned by `HERMES_REF`).

### Regenerating the API client

```bash
./scripts/generate_hermes_api_client.sh   # needs a JDK (npx openapi-generator-cli) and dart on PATH
```

`verify-hermes-api-client.yml` fails CI if `openapi/`, `scripts/` or `packages/hermes_api/` change without a matching regenerated client. Never hand-edit `packages/hermes_api`. Fix template bugs in `scripts/patch_openapi_for_dart.py` or `scripts/patch_generated_dart_client.py`. `packages/hermes_api/pubspec.lock` is committed on purpose.

## Architecture

**State and routing.** `lib/main.dart` sets up telemetry and `provider` (`AuthController`, `ThemeController`, `NotificationSettings`, `ShareController`). `lib/src/app.dart` picks the screen purely from `AuthController.state` (`HermesConnectionState`): setup, login or `AppShell`. There are no named routes. `shell/app_shell.dart` is the navigation between Chat, Kanban and Schedules. The Kanban tab (`lib/src/kanban/`) only exists while the server reports the Kanban plugin as on, and the Schedules tab (`lib/src/schedules/`, the server's cron jobs) only while `/api/cron/delivery-targets` answers. Both are re-checked on connect and on app resume; with neither, the shell is the bare chat. Opening a run of a job goes through `ChatOpenRequests` to the chat screen. `AuthController` owns the whole connection lifecycle: server URL discovery, sign-in, token storage and refresh, and the authenticated `Dio` instance.

**Auth.** Both OIDC and password sign-in use the same RFC 8252 flow (`auth/native_login_flow.dart`, `pkce.dart`): system browser, loopback HTTP listener, PKCE, then a bearer token pair kept in secure storage. Tokens refresh before use and again on any 401. Concurrent 401s must not sign the user out, and sign-in must never be left spinning (regressions fixed in 0.1.8 and 0.1.9). If `/api/status` reports `auth_required: false`, sign-in is skipped. A failed connect is classified in `auth/connect_failure.dart`; the setup screen adds a VPN hint for tailnet/private addresses, and `network/network_signals.dart` (`connectivity_plus` plus app resume) makes `AuthController` retry the saved server after a network failure. VPN detection is only a hint, never a gate: iOS and macOS cannot report it. `--dart-define=HERMES_SERVER_URL=<url>` overrides the saved server address, for dev and tests.

**Two API layers.**

- `packages/hermes_api` is a generated `dart-dio` client for the backend's OpenAPI spec (`openapi/hermes-agent.openapi.json`). Reach it through `authController.api!.raw`, which shares the managed `Dio`, instead of adding hand-rolled calls.
- `lib/src/api/hermes_api_client.dart` hand-writes only `/api/status`, `/api/auth/providers` and `/api/auth/me`, because the spec has no response schemas for them. It also hand-writes the Kanban attachment download (`fetchKanbanAttachment`), because the generated method decodes the body as JSON and cannot return a file's bytes.
- Many routes (sessions, profiles, bots, skills, plugins) also lack response schemas, so the generated methods return untyped JSON. The repositories (`chat/hermes_chat_repository.dart`, `profiles/`, `bots/`, `skills/`, `plugins/`, `schedules/hermes_cron_repository.dart`) parse those rows leniently and skip rows that don't fit. The contract test above guards these shapes.

**Chat** (`lib/src/chat/`, built on `flutter_chat_ui`).

- History is loaded over REST by `HermesChatRepository`. Sending and streaming go through the `ChatTransport` interface (`chat_transport.dart`), a sealed `ChatEvent` stream. The real implementation, `gateway/hermes_gateway_transport.dart`, speaks JSON-RPC over the dashboard's `/api/ws` websocket (`session.create` or `session.resume`, then `prompt.submit`, with replies as `message.delta` events). `gateway_rpc_client.dart` and `gateway_connection.dart` handle the socket.
- Domain messages (`chat_models.dart`) map to flyer messages in `chat_message_mapper.dart`. `chat_controller_sync.dart` applies before/after diffs to the `InMemoryChatController`. Custom message kinds and cards (tool calls, approval and clarify requests) live in `chat_message_kinds.dart` and `widgets/`. The design for agent input requests is in `openspec/changes/archive/2026-09-19-agent-input-requests/`.
- With no repository, `ChatScreen` falls back to `mock_chat_data.dart`. A canned reply is used when there is no transport.

**Plugins** (`lib/src/plugins/`). The chat sidebar's Plugins row opens a screen with three tabs. Installed lists the dashboard's agent plugins (`GET /api/dashboard/plugins/hub`) and enables, disables, updates, removes and hides them; it does not list Kanban or Achievements, which the hub reports apart as dashboard-only extensions. Catalog (`GET /api/dashboard/plugins/catalog`, loaded when first opened) searches the curated catalog and installs from it, and installs from a Git URL behind an unreviewed-code warning; the typed URL can hold a token, so it is never logged or kept. Providers (the `providers` object of the same hub, loaded when first opened) picks the memory provider and context engine: only providers the server reports as ready can be picked, the rest list what they need on the server (the app runs nothing), and Save sends only the fields that changed to `PUT /api/dashboard/plugin-providers`. `PluginsController`, `CatalogController` and `ProvidersController` hold the state. Details are a bottom sheet below 900 px and a pane at 900 px or wider. The generated client puts a plugin's name into the path unencoded, so the repository encodes it. An install can outlast the client's 30 s timeout, so a timeout is reported as "still installing", not as a failure.

**MCP servers** (`lib/src/mcp/`). List, switch, test and remove the MCP servers of the active profile, opened from the chat sidebar. `HermesMcpRepository` wraps the generated MCP calls and parses leniently. `McpServersController` holds one visit's state (the profile learned first, the list, the test results), and `McpServersScreen` and `McpServerDetail` render it, side by side from 900 logical pixels. The "Add" button is a menu: "Browse the catalog" opens `McpCatalogScreen` (Hermes' approved catalog, searched and filtered on the device; `McpCatalogController`), where an entry that is not installed opens `McpInstallPanel` (a bottom sheet, or the right-hand pane from 900 logical pixels) and an installed one opens its server. `McpInstallController` sends the install and, for entries Hermes builds on the server, polls `GET /api/actions/{name}/status`. Credentials live only in the panel's text fields and go into the install request. `McpSignInScreen` waits while the user approves an OAuth sign-in in the browser (`McpServersController.startSignIn`, then polling `GET /api/mcp/oauth/flows/{id}`); Hermes keeps the token and the app never sees the code. "Add a custom server" opens `McpAddServerScreen` (remote or command server) and the overflow menu's "Edit as JSON" opens `McpJsonEditorScreen`, which loads the whole map from `GET /api/config` (the servers route is lossy) and saves it with `PUT /api/mcp/servers`. A command server makes the Hermes host run a program, so `McpServersController.addServer` and `replaceServers` take a required `McpReviewer` and send nothing until it confirms; the screens pass `showMcpCommandReview` (bottom sheet, dialog from 900 px). Bearer tokens, environment values and the editor's text stay in screen state and are cleared after the request.

**Notifications** (`lib/src/notifications/`). Local notifications when a reply finishes or the agent needs the user, gated by `attention_policy.dart` and user settings. A second source is `schedules/schedule_alerts.dart`: while the app is in front, `ScheduleWatcher` (owned by the shell) polls every profile's cron jobs each minute and announces a run since the last look; Hermes has no push channel, so nothing arrives while the app is closed.

**Telemetry** (`lib/src/telemetry/`). OpenTelemetry to SignalDB through the `flutter_otel` git dependency, which is pinned to a commit along with its sibling packages in `dependency_overrides`. It is off unless `OTEL_EXPORTER_OTLP_ENDPOINT` is passed via `--dart-define`. When off, no SDK exists and no `traceparent` header is added. Telemetry code must never break the app (see `safely.dart`).

**Native pieces.** `ios/ShareExtension` (share sheet, `receive_sharing_intent`, linked by a version-pinned path in `project.pbxproj`, so a plugin upgrade must be mirrored there) and `ios/HermesWatch` (the watchOS companion app embedded in the iOS app; it has no network of its own and asks the phone, which answers in `lib/src/watch/`). macOS has its own share inbox (`share/macos_share_inbox.dart`). Debug builds use bundle ID `com.cedricziel.hermesApp.dev`, so every extension's Debug ID must be prefixed with it. Release and TestFlight builds go through `fastlane` (lanes in `fastlane/Fastfile`, store metadata in `fastlane/metadata/`).

## Testing conventions

Tests drive the real generated client and Dio pipeline against `test/support/fake_hermes_server.dart`, an `HttpClientAdapter` with per-route responses, rather than mocking the client. Other helpers in `test/support/`: `fake_chat_transport.dart`, `memory_token_store.dart`, `fake_share_inbox.dart`, `pump_chat.dart`.

`test/workflows/` walks whole user flows (onboarding, chat, kanban, skills/bots/settings) on phone and desktop, light and dark, and saves a screenshot per step to `build/workflow_screenshots/` (`workflow-screenshots` skill). Look at them after a UI change.

## Specs

`openspec/` holds spec-driven change proposals (`openspec/specs/` for current behavior, `openspec/changes/` for work in progress). Start a change with `/opsx:propose "<idea>"`; project context for it lives in `openspec/config.yaml`. Design history lives under `openspec/changes/archive/`.

## Skills

Project skills live in `.claude/skills/<name>/SKILL.md` (frontmatter `name` and a `description` that says when to use it). When you learn something reusable about working in this repo, such as a workflow, a gotcha or a verification step, write it to a skill rather than to memory, so it is checked in and shared.

- Amend the existing skill when the new knowledge fits it. Fix a skill that turns out to be wrong or stale as soon as you notice.
- Create a new skill when the knowledge is a distinct, repeatable task no current skill covers. Keep the description specific enough that it triggers at the right time.
- Use memory only for things that are personal to the user or don't belong in the repo.
- Commit skill changes with the work that prompted them, or on their own as `docs:`.

## Dependencies

Before writing platform or infrastructure code by hand (storage, permissions, sharing, notifications, deep links, auth flows, and the like), check pub.dev for a mature, maintained plugin and prefer it over a homegrown implementation. Judge maturity by recent releases, publisher, platform coverage, popularity and open issues. If none fits, say why in the PR. The existing choices (`flutter_chat_ui`, `receive_sharing_intent`, the generated `hermes_api` client) follow this rule.
