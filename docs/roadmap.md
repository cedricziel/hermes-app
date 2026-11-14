# Roadmap

Started 14 November 2026 from a full review of the app: structure, practice, bugs, alignment with Hermes and what is missing. This file is the checklist for that work. It is kept current as items merge.

## Rules

- Every item ships as its own pull request, reviewed by an isolated reviewer agent with fresh context, and merged by squash auto-merge once `Analyze & test` is green. A CodeRabbit comment counts as a review only when it actually reviewed the diff.
- A bug fix starts with a failing test.
- A UI change starts with a Claude Design pass (the "Hermes App" design system), then a Widgetbook use case, and only then the screen. The React copies in `design/web` are updated with it.
- A new feature starts with an OpenSpec change (`openspec/changes/<name>/`).
- A pre-release is cut (the release-please PR is merged) after each completed wave. Promoting a pre-release to App Review is the owner's step.
- We own only the client. Anything that needs a Hermes change is listed under "Upstream" and is not built here.
- Anything found along the way (by a reviewer, a lead, CI or a proposal) that is not fixed in the PR that found it is added to "Found along the way" in the same or the next roadmap update, with where it came from. Nothing is left only in a PR description.

## Status values

`merged` (with PR), `open` (PR up, in review or CI), `building`, `queued`, `blocked` (with the reason), `dropped` (with the reason).

## Wave 1: bugs in ordinary use

| Item | What                                                                                                                                                               | Status      |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- |
| 1.1  | Gateway liveness: `streaming`/`resuming` count as live in the silence probe; a malformed answer settles as an error instead of hanging                             | merged #897 |
| 1.2  | Chat history: a prompt sent before the first page loads keeps its place; a refresh during "load older" leaves no gap; rows without an id are skipped               | open #902 (second review round) |
| 1.3  | Schedules: a one-shot job that already ran can be edited; an incomplete job listing no longer deletes mutes or run baselines                                       | merged #900 |
| 1.4  | Controller state: Skills Discover no longer spins forever; skill toggle rollback; Kanban refresh ordering; memory settings stale write; avatar failures not cached | open #901 |

## Wave 2: robustness and security

| Item | What                                                                                                                                                                                     | Status    |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| 2.1  | Background and App Lock: the second approval in a chat is announced; widgets reload at most hourly across isolates; suspension marks; App Lock fails closed when the device check throws | open #906 |
| 2.2  | Sign-in hardening: the loopback listener ignores requests without the app's state; a cross-host redirect no longer gets the stored session                                               | open #908 |
| 2.3  | Bot Screen: a lease held by a paused viewer is released on shut-down; no stale picture or dead input after a take-over retry; older lease broadcasts are ignored                         | open #905 |
| 2.4  | Voice: a late transcribe socket is closed; a throwing permission check or start ends as failed; one error instead of two                                                                 | merged #904 |

## Practice

| Item | What                                                                                                                                                                                                                                                                                                                                                | Status      |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| P.1  | `CLAUDE.md` cut from 128 KB to 16 KB; the detail moved to `docs/architecture/`                                                                                                                                                                                                                                                                      | merged #899 |
| P.2  | Test coverage measured per shard and summarized in CI; accurate package description                                                                                                                                                                                                                                                                 | merged #898 |
| P.3  | 17 implemented OpenSpec changes archived; the open ones listed in `openspec/changes/README.md`                                                                                                                                                                                                                                                      | merged #903   |
| P.4  | This roadmap; the `parallel-ui-rollout` skill amended with what this run learned (leads cannot spawn reviewers, the orchestrator does; CI events for a superseded commit)                                                                                                                                                                           | merged #909 |
| P.5  | Broad catches audited (about 500 `on Object` handlers in `lib/`, 25 of them `on Object catch (_)`): each either narrowed, logged, or justified in place                                                                                                                                                                                                                                            | queued      |
| P.6  | Leftover low findings from the bug hunt, each verified first: early `panel`/`focused` calls from a new window dropped; `QuickPanelShortcut` unawaited toggle; schedule preview in device time (needs a time-zone source); refresh 403 treated as expired only with Hermes' own error body (needs a spec change); legacy session without `serverUrl` | building |

**Release R1** is cut when waves 1 and 2 and P.1 to P.4 are merged.

## Wave 3: structure

| Item | What                                                                                                                                                                        | Status |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 3.1  | Split `HermesGatewayTransport` (about 3,150 lines) into connection and replay, turn lifecycle, and side requests, with no behaviour change and the existing tests untouched | open #910 |
| 3.2  | Typed gateway bindings generated from `openrpc/hermes-gateway.openrpc.json`, replacing the 51 method names written as string literals across `lib/`                                                          | queued |
| 3.3  | Composition root: group the 35 providers in `main.dart` by concern; move watchers and prompts out of `AppShell` into owners of their own                                    | building |
| 3.4  | Localization: `flutter gen-l10n` set up, every user-visible string extracted to English resources, German added as the first translation                                    | building (scaffolding first, then extraction by directory) |

**Release R2** is cut when wave 3 is merged.

## Wave 4: what a Hermes client should offer

Each item is an OpenSpec change, a Claude Design pass and catalog use cases before the screen.

| Item | What                                                                                                                                    | Hermes surface                                                                               | Status |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------ |
| 4.1  | Provider and API key setup, so a fresh server can be made usable from the app                                                           | `/api/providers/*`, `/api/env`, `/api/credentials/pool`, `model.save_key`                    | proposal open #913 |
| 4.2  | Working directory and projects for a chat                                                                                               | `projects.*`, `session.cwd.set`, `/api/chat/workspaces`                                      | proposal building |
| 4.3  | Files: browse and open what the agent wrote                                                                                             | `/api/files/*`, `/api/fs/*`                                                                  | proposal building |
| 4.4  | Subagent control: list, tail, interrupt, steer                                                                                          | `subagent.*`, `delegation.*`                                                                 | proposal open #912 |
| 4.5  | Checkpoints and context: roll back, compress, see what fills the context                                                                | `rollback.*`, `session.compress`, `session.context_breakdown`                                | proposal building |
| 4.6  | Toolsets: see and configure what the agent may use                                                                                      | `/api/tools/*`                                                                               | proposal building |
| 4.7  | Server care: status, update Hermes, restart the messaging gateway, logs, doctor, usage. Restarting the gateway does not unstick a chat in the app (the chat socket is in the dashboard process); Stop does                                                                     | `/api/gateway/*`, `/api/logs`, `/api/ops/doctor`, `/api/hermes/update/*`, `/api/analytics/*` | proposal open #915 |
| 4.8  | Smaller ones: SOUL editing, session export, jump to a search hit (`messages/around`), WhatsApp onboarding, webhooks, the skills curator | assorted                                                                                     | queued |
| 4.9  | Chat activity line and Needs-you dock (changes `chat-activity-line`, `chat-activity-needs-you`, not started)                            | existing frames                                                                              | queued |
| 4.10 | Reply from the notification (change `notification-inline-reply`, not started)                                                           | `request.answer`, `prompt.submit`                                                            | queued |
| 4.11 | Hands-free voice conversation (change `voice-conversation`, not started)                                                                | `/api/audio/*`                                                                               | queued |

**Release R3** is cut when wave 4 is merged; it may be cut in two parts if the wave runs long.

## Wave 5: platform parity

| Item | What                                                                                                                              | Status |
| ---- | --------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 5.1  | Android home screen widgets reading the surface snapshot                                                                          | queued |
| 5.2  | Android request notifications with the command or question and answer buttons, as on iOS and macOS                                | building |
| 5.3  | Windows and Linux: state in the README what is supported, and close the gaps that are cheap (notifications, App Lock explanation) | queued |
| 5.4  | Remaining open changes that are partly done: `bot-mode-roster`, `bot-mode-chats`, `bot-mode-group-protocol`                       | queued |

**Release R4** is cut when wave 5 is merged.

## Found along the way

Things the work itself turned up. Each is verified before it is built; an item moves into a wave table when it is scheduled.

| Item | What | Found by | Status |
| --- | --- | --- | --- |
| F.1 | CI: the `Test watch core` job runs on the macOS runner for every PR and was queued for about 18 minutes; it gates `Analyze & test`. Run it only when `ios/HermesWatch`, `ios/HermesSurfaceKit`, `ios/HermesComplication` or the workflow change, and report success otherwise | CI on #899 | queued |
| F.2 | `test/quick_look_attachment_test.dart` ("a file card Space downloads once…") failed once in CI on a PR that does not touch Quick Look: find what it races on and make it deterministic | CI on #901 | building (with #901) |
| F.3 | A formatter hook rewrites Markdown on save and turned `(x86_64,` and `REVIEW_*` in `CLAUDE.md` into emphasis; make the hook leave prose alone or exclude the files it damages | lead of #899 | queued |
| F.4 | Background request alerts: the marks of a request that stays open are never renewed, so after about 100 newer announcements its mark is trimmed and it is announced a second time. Re-add the marks of requests that are still showing | review of #906 | queued |
| F.5 | Surface snapshot: save the widget reload mark only when a reload succeeded | review of #906 | queued |
| F.6 | Sign-in: a 403 on refresh should count as an expired session only with Hermes' own error body (Hermes sends 401 `session_expired`, never 403). Needs a spec change in `openspec/specs/auth` | lead of #908 | queued |
| F.7 | A stored session with no recorded server (from before the server was recorded) is still accepted for a new address the user types while the saved one is unreachable | lead of #908 | queued |
| F.8 | Voice: `TranscribeStream` calls `connect` outside its try, so a connector that throws synchronously escapes; other awaits in `DictationController._start` after the permission check are unguarded | review of #904 | queued |
| F.9 | Skills: a list reload that lands during a toggle leaves the rollback value from before the reload | review of #901 | queued |
| F.10 | Avatars: with the gateway down, each remount of an avatar asks again; add a short negative-cache window if telemetry shows it | review of #901 | queued |
| F.11 | Schedules: the "next runs" preview is in device time while Hermes evaluates cron in the profile's `timezone`, else `HERMES_TIMEZONE`, else the server's zone. Showing server time needs the profile's config read and a time-zone database dependency | lead of #900 | queued |
| F.12 | Profiles: set a profile's default model with `POST /api/model/set` in place of `PUT /api/profiles/{name}/model`, so it gets Hermes' expensive-model confirmation | proposal #913 | queued |
| F.13 | Side tasks started with `prompt.background` or `prompt.btw`: starting them belongs to a composer change; Hermes offers no way to list or stop them (see Upstream) | proposal #912 | queued |
| F.14 | `design/web` (the React copies Claude Design uses) drifts from the Flutter widgets: audit it once against the catalog and bring it level before the wave 4 design passes rely on it | design-sync notes | queued |
| F.15 | Cloud delivery: the environment's setup script now installs the Flutter release pinned in `.fvmrc`; document it and the child-session workflow in the `parallel-ui-rollout` skill once a fresh session has proven it | this run | queued |
| F.16 | Chat: a send in a chat whose first page is still loading now waits for that read; decide what the user sees meanwhile and cap the wait | review of #902 | open (with #902) |

## Blocked

| Item                                                                               | Why                                                                                                                                                                      |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| The eight `watch-*` changes                                                        | What is left is native fixtures, accessibility work and verification on a watch or the watch simulator, which needs a Mac with Xcode. The delivery environment is Linux. |
| Device verification tasks listed as "Not verified on a device" in archived changes | Same: no iPhone, Mac or Android device in the delivery environment. CI builds all platforms; behaviour on a device is unobserved.                                        |
| Making the real-backend contract test a required check                             | Recorded as a deliberate decision (advisory) in `docs/agent-gap-plan.md`, and branch protection is the owner's setting.                                                  |

## Upstream (needs a Hermes change; not built here)

- A structured list of pending memory and skill proposals, in place of parsing `/memory pending` text.
- Response schemas for the routes the app parses leniently (sessions, profiles, messaging, skills, plugins).
- A push channel, so requests and replies reach a closed app without the 15-minute background refresh.
- A way to answer clarify, sudo and secret requests in a hosted group room.
- A prompt hint for the `hermes_app` session source.
- A way to list and stop side tasks started with `prompt.background` or `prompt.btw`.
- One route that says how each provider connects (key, sign-in code, command line), in place of merging four.
- Roles: today anyone signed in to the dashboard may restart the gateway and update Hermes.

## Out of scope

- Git review (`/api/git/*`) and local models (`/api/local-models/*`): desktop features.
- Single-label hosts counting as local: a documented trade-off.
