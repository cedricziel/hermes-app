# Spec Delta

## Purpose

Describes the snapshot of the user's Hermes state that the app shares with its system surfaces (widgets, quick actions, Spotlight, App Intents): what it holds, the limits that keep it small and private, when the app writes it while in front, how failing sources are handled, and its signed-out form.

## ADDED Requirements

### Requirement: Snapshot content

The app SHALL keep one snapshot, stored as JSON under the key `hermes.surface.v1` in the shared App Group's `UserDefaults` on iOS (and the equivalent shared storage on Android), with these fields:

- `version` (1), `updatedAt` (UTC, ISO 8601), `signedIn`, `profile` (the profile the app shows);
- `profiles`: the names of the server's profiles, in the server's order;
- `recentChats`: at most 10 chats across all profiles, newest first, each with `profile`, `id`, `title`, an optional `snippet` of at most 120 characters on one line, `updatedAt` and a `url` of the form `hermes://chat?profile=<p>&id=<id>`;
- `pending`: open requests, each with `profile`, `threadId`, `threadTitle`, `kind` (`approval`, `question` or `input`), `requestId`, `createdAt` and the chat's `url`;
- `kanban`: `blocked` and `review` task counts, or null when the server has no Kanban plugin enabled;
- `schedules`: `nextRunAt` and `nextJobName` of the next run of an enabled job, and `lastFailed` (`profile`, `jobId`, `name`, `at`, `url` of the form `hermes://schedules?profile=<p>&job=<id>`) for the most recent failed run, or null when the server has no scheduled tasks.

A request's `createdAt` SHALL be the time the app first learned of it, since Hermes reports none.

#### Scenario: Two profiles with chats

- **WHEN** profile `default` has 8 chats and `work` has 6, and the snapshot is written
- **THEN** `recentChats` holds the 10 most recent of the 14, newest first, each with its profile and link

#### Scenario: Server without Kanban

- **WHEN** the server does not have the Kanban plugin enabled
- **THEN** `kanban` is null

### Requirement: Nothing sensitive in the snapshot

The snapshot SHALL NOT contain a token, the server address or the user's identity. An open request SHALL be described only by its chat, kind and id, never by the command, the question, the choices or the name of a secret. A snippet SHALL be at most 120 characters of the chat's latest message, cut the same way as a notification body.

#### Scenario: Approval for a command

- **WHEN** the agent asks for approval to run `rm -rf build` in chat "Cleanup"
- **THEN** the snapshot's pending entry says `kind: approval` with thread title "Cleanup" and does not mention the command

### Requirement: Profile names

The snapshot SHALL list the server's profile names in `profiles`, read with the other profiles' chats, so that intent pickers can offer them without a request. When the profile list cannot be read, the previous snapshot's `profiles` SHALL be kept. The signed-out snapshot SHALL have an empty `profiles`.

#### Scenario: Two profiles

- **WHEN** the server has profiles `default` and `work` and the snapshot is written
- **THEN** `profiles` is `["default", "work"]`

#### Scenario: Profiles fail to load

- **WHEN** `GET /api/profiles` fails while the snapshot is rebuilt
- **THEN** `profiles` keeps the names of the previous snapshot

### Requirement: App Lock omits titles and snippets

While App Lock is on, the snapshot SHALL write every chat title and thread title empty and SHALL leave out every snippet and job name. Counts, kinds, times, ids, profile names and links SHALL stay, so surfaces can still show how many chats and requests there are and open them through the app. When App Lock is turned off, the next write SHALL include titles and snippets again.

#### Scenario: App Lock on

- **WHEN** App Lock is on and the snapshot is written
- **THEN** every recent chat and pending entry has an empty title and no snippet, and the number of recent chats, pending entries and the Kanban counts are the same as without App Lock

#### Scenario: App Lock turned off

- **WHEN** App Lock is turned off and the snapshot is written next
- **THEN** recent chats carry their titles and snippets again

### Requirement: When the app writes the snapshot

While the app is in front and signed in, it SHALL write the snapshot after the chat list loads, when a reply ends (completed, failed or stopped), when an open request appears, is answered, expires or is withdrawn, and when the app moves to the background. Changes in the open profile's chats SHALL be applied without an extra server request and written within a few seconds. The other profiles' chats, Kanban and schedules SHALL be read from the server at most once every five minutes while in front, and on every move to the background. A snapshot equal to the stored one SHALL NOT be written again. After each write, the app SHALL ask the system to reload the widgets that read it.

#### Scenario: Reply finished

- **WHEN** a reply completes in chat A of the open profile
- **THEN** within a few seconds chat A is the first recent chat, its snippet is the start of the reply, and no extra server request was made for it

#### Scenario: Going to the background

- **WHEN** the user leaves the app
- **THEN** the app reads chats of every profile, Kanban and schedules and writes the snapshot

### Requirement: Failing sources

Each source (profiles and their chats, Kanban, schedules) SHALL be read independently and SHALL count as failed when it errors or takes more than five seconds. A failed source SHALL keep its section from the previous snapshot, or leave it empty or null when there is none. A source the server reports as unavailable SHALL set its section to null. Open requests of profiles the app is not showing SHALL be kept from the previous snapshot.

#### Scenario: Kanban times out

- **WHEN** the Kanban board takes longer than five seconds to answer
- **THEN** the written snapshot keeps the previous Kanban counts and the other sections are updated

### Requirement: Signed-out snapshot

When the user signs out, the session expires, or the user changes the server, the app SHALL write a snapshot with `signedIn: false`, empty `profiles`, `recentChats` and `pending`, and null `kanban` and `schedules`, and SHALL ask the system to reload the widgets.

#### Scenario: Sign-out

- **WHEN** the user signs out
- **THEN** the stored snapshot has `signedIn: false` and no chats, requests, Kanban or schedules

### Requirement: Telemetry without content

Building the snapshot SHALL record a span `surface.snapshot.build` with the trigger, the number of failed sources and the connection's server attributes. A failed write to shared storage SHALL be logged as `surface.snapshot.write_failed` with the error type. Neither SHALL contain titles, snippets, ids or profile names, and a failed write SHALL NOT affect the app.

#### Scenario: Write fails

- **WHEN** the shared storage cannot be written
- **THEN** `surface.snapshot.write_failed` is logged and the app goes on as usual

### Requirement: Backend contract

The snapshot SHALL be built from routes the app already uses: `GET /api/profiles`, `GET /api/sessions?profile=<p>&order=recent&archived=exclude`, `GET /api/dashboard/plugins` and `GET /api/plugins/kanban/board`, `GET /api/cron/delivery-targets` and `GET /api/cron/jobs?profile=all`. It SHALL need no new Hermes route, RPC method or minimum version.

#### Scenario: Oldest supported Hermes

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** the snapshot is written with every section the server supports
