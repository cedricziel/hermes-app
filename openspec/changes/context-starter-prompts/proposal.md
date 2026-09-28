# Proposal

## Why

The welcome view of a new chat always offers the same four hardcoded starter prompts. Some of them do not fit a real server ("Summarize open issues tagged "auth"") and none of them relate to what the user is doing. The app already reads the user's scheduled jobs, Kanban board, chats and skills, so it can suggest prompts that are worth tapping: a job that failed, a task that is stuck, the chat from earlier, a skill the user relies on.

## What Changes

- The welcome view shows up to four starter prompts built on the device from the active profile's context. The sources, in this order, give at most one prompt each:
  1. **Scheduled jobs**: a job whose last run failed ("Why did the scheduled job 'Nightly backup' fail on its last run?").
  2. **Kanban**: a blocked task, or else a task waiting for review, only while the Kanban plugin is on ("What's blocking the Kanban task 'Migrate auth'?").
  3. **Recent chats**: the most recent titled chat ("Pick up 'Debugging the Telegram pairing'").
  4. **Skills**: the enabled skill the user has used most ("Use the nextcloud-notes skill to ").
- Generic prompts that make sense on any server fill the remaining slots, so a new install still sees four prompts. The generic prompts replace the current placeholders.
- Tapping a prompt does one of three things, depending on the prompt:
  - a generic prompt is sent, as it is today;
  - a prompt that names a job, task or skill is put in the composer so the user can edit it before sending;
  - a recent-chat prompt opens that chat.
- Each card shows a small icon for its source (schedule, Kanban, chat, skill).
- The generic prompts show at once. The contextual prompts replace them in a single swap once the context has loaded. A source that fails or times out is left out without an error.
- No model is called to write the prompts.

### Non-goals

- Prompts based on the time of day.
- Prompts written by a model or by the auxiliary models.
- MCP servers as a source. The server list has no descriptions or tools without running a connection test, so it cannot produce a useful prompt.
- Starter prompts on the watch, in the share extension, or anywhere other than the chat welcome view.
- Letting the user hide or configure the contextual prompts.

### Security and privacy

None. Job names, task titles, chat titles and skill names come from the user's own server over the existing authenticated client and are only shown on the device. Nothing new is stored or sent.

### Telemetry

None.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: the welcome view's starter prompts come from the user's context. The "Empty thread" scenario changes, and a new requirement defines where the prompts come from, their order, the generic fallback and what tapping each kind does.

## Impact

- `lib/src/chat/widgets/welcome_view.dart`: takes a list of prompts with a source and an action instead of reading `kStarterPrompts`.
- `kStarterPrompts` moves from `lib/src/chat/mock_chat_data.dart` to the new `starter_prompts.dart` and becomes the generic fallback list.
- New pure builder and a context loader under `lib/src/chat/`. The loader uses the existing `HermesRepositories` (`cron`, `plugins`, `kanban`, `skills`); no new API routes and no regeneration of `packages/hermes_api`.
- `chat_screen.dart` / `chat_builders.dart`: pass the prompts through and handle the prefill and open-chat actions.
- `widgetbook/chat_use_cases.dart`, `test/welcome_view_test.dart`, a new builder unit test and a chat screen test against `FakeHermesServer`.
- Backend routes used (already used by other screens): `GET /api/cron/jobs`, `GET /api/dashboard/plugins`, `GET /api/plugins/kanban/board`, `GET /api/skills`.
