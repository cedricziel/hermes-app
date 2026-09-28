# Design

## Context

See proposal.md for the motivation and specs/chat/spec.md for the behaviour.

Today `WelcomeView` (`lib/src/chat/widgets/welcome_view.dart`) renders the constant `kStarterPrompts` (`lib/src/chat/mock_chat_data.dart`). `buildChatBuilders` passes `onPickPrompt`, which `ChatScreen` wires straight to `onSend`. Several tests tap `kStarterPrompts.first` and expect a send (`chat_screen_test.dart`, `chat_builders_test.dart`, `chat_screen_hermes_test.dart`, `thread_actions_test.dart`, `welcome_view_test.dart`).

Every source is already reachable from `ChatScreen` through `HermesRepositories.maybeOf(context)`:

- `cron.listJobs(profile:)`: `CronJob` with `name`, `lastRunAt`, `outcome` (`CronOutcome.failed`).
- `plugins.isKanbanEnabled()` and `kanban.loadBoard()` (default board): `KanbanBoard.columns[].tasks[]`, `KanbanTask.title` and `status`.
- `skills.list(profile:)`: `HermesSkill` with `name`, `enabled`, `usage`.
- Threads come from `ChatController.threads` (`ChatThread.title`, `updatedAt`) and the profile from `ChatController`'s active profile.

The shell's `ScheduleWatcher` and its Kanban flag are not reachable from `ChatScreen`, and threading them through `AppShell` would couple the shell to the welcome view.

## Goals / Non-Goals

**Goals:**

- A widget that takes plain models only, so it can be catalogued in Widgetbook.
- The choice of prompts is a pure function, tested without widgets or HTTP.
- The existing tests that tap a generic prompt keep working.

**Non-Goals:**

- Sharing loaded data with the Schedules or Kanban tabs, or with `ScheduleWatcher`.
- Caching context across app launches.

## Decisions

**1. Three layers: model, pure builder, loader.**

- `StarterPrompt { String text; StarterSource source; StarterAction action; String? threadId }`. `StarterSource` is `generic | schedule | kanban | chat | skill` and chooses the icon. `StarterAction` is `send | prefill | openThread`.
- `StarterContext { CronJob? failedJob; KanbanTask? kanbanTask; ChatThread? recentThread; HermesSkill? topSkill }`.
- `buildStarterPrompts(StarterContext) -> List<StarterPrompt>` (in `lib/src/chat/starter_prompts.dart`) applies the order, the wording and the generic fill. It always returns four prompts.
- `StarterContextLoader` picks one item per source from the repository calls, with its own filtering (failed job with the latest `lastRunAt`, first blocked task else first review task, top-used enabled skill). The recent thread is picked in the builder's caller from `ChatController.threads`, because those are already in memory.

Alternative: one class that fetches and formats. Rejected, because the ordering and wording rules are the part most worth testing, and they need no HTTP.

**2. The loader lives in `ChatScreen`'s state and fetches on its own.** The loader calls the four repositories in parallel with `Future.wait`. Each call gets its own 5 s timeout and its own `catchError` that yields null, so one slow or failing source never blocks or drops the others. The Kanban board is only requested after `isKanbanEnabled()` returns true. The result is kept with the profile name and a timestamp. It is reloaded when the profile changes, or when the welcome view is built and the result is more than five minutes old. A load in progress for a profile that is no longer active is discarded.

Alternative: pass `ScheduleWatcher` data and the Kanban flag from `AppShell`. Rejected: the watcher polls every profile only while notifications are on, and its data is shaped for alerts. It would also add constructor parameters to the shell and to `ChatScreen` for one widget.

**3. One swap, not progressive.** The view shows the generic prompts until every source has settled, then shows the result of `buildStarterPrompts` once. Filling in cards as each source answers would make the grid jump up to four times while the user is reading it.

**4. Actions go through one callback.** `WelcomeView` takes `List<StarterPrompt> prompts` and `ValueChanged<StarterPrompt> onPick`. `ChatScreen` switches on `action`:

- `send` calls `onSend(text)`, as today;
- `prefill` sets `_composerController.value` with the cursor at the end, as the shared-text draft already does;
- `openThread` selects the thread through `ChatController`, as a tap in the sidebar does.

The composer has no `FocusNode` today. This change does not add one: on a phone, raising the keyboard over the grid as soon as the user taps would hide the prompt they just picked.

**5. `kStarterPrompts` becomes the generic list.** It moves next to the builder in `starter_prompts.dart`, because it is shown to real users and no longer only to tests and previews. It stays a `const List<String>` with new wording that fits any server:

- "What can you help me with?"
- "Which skills and tools can you use?"
- "Draft a status update for the team"
- "Help me think through a problem"

Tests that tap `kStarterPrompts.first` then still see a generic prompt that sends, because those tests use a server with no jobs, tasks or skills.

**6. Wording lives in the builder, in English.** The app has no localization layer yet, so the strings sit next to the existing UI strings.

**Platforms:** all Flutter platforms (iOS, Android, macOS, Windows, Linux). watchOS is not affected. No entitlement, manifest or Xcode project change.

**Invariants touched:** API layering: all calls go through the existing repositories, which use the generated client through `authController.api!.raw`. There are no new routes and `packages/hermes_api` is not regenerated. Tests run against `FakeHermesServer`. Auth: a 401 on a context call goes through the existing refresh path, and a failure is swallowed by the loader and does not sign the user out.

## Risks / Trade-offs

- [Three to four extra requests every time a new chat opens] → Results are reused for five minutes per profile, and the Kanban board is only requested when the plugin is on.
- [A big Kanban board is a heavy response only to pick one task] → The loader uses the same `loadBoard` call as the Kanban tab, with archived tasks excluded. If this turns out to be slow, a status filter can be added later without changing the spec.
- [Names from the server can be long] → Cards already wrap. The builder cuts a name longer than 60 characters and adds "…" so a card stays at two or three lines.
- [A "Pick up" card opens a chat, which can surprise someone who expected a message to be sent] → The card's chat icon and the "Pick up" wording set that expectation.
- [Swapping the prompts while the user is reaching for one] → There is a single swap, and it usually happens within a second of the view opening.

## Migration Plan

None. This is client-only with no stored state. A rollback is a revert.
