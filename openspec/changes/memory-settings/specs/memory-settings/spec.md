## ADDED Requirements

### Requirement: Learning settings

The Memory screen SHALL show a Learning section for its profile with three switches and two value rows:

- "Remember things about me" for `memory.user_profile_enabled`;
- "Keep agent notes" for `memory.memory_enabled`;
- "Ask before saving" for `memory.write_approval`;
- "Review chats" for `memory.nudge_interval`, offering Off (0) and Every 5, 10 or 20 messages;
- "Memory updates in chat" for `display.memory_notifications`, offering Off (`off`), Short note (`on`) and With details (`verbose`).

The section SHALL be captioned "Ask before saving applies right away, the rest from the next chat." Values SHALL be read from `GET /api/config?profile=<profile>` with defaults included. A missing or ill-typed key SHALL show the server's default (true, true, false, 10, `on`). A value the app does not offer SHALL be shown as it is and kept as a choice until the user picks another.

#### Scenario: Settings shown

- **WHEN** the config holds `memory.write_approval: true` and `memory.nudge_interval: 5`
- **THEN** "Ask before saving" is on and "Review chats" reads "Every 5 messages"

#### Scenario: Unknown interval

- **WHEN** the config holds `memory.nudge_interval: 15`
- **THEN** "Review chats" reads "Every 15 messages" and that choice is offered next to Off, 5, 10 and 20

#### Scenario: Config cannot be read

- **WHEN** the config request fails
- **THEN** the Learning section shows a retry row instead of its controls, and the Storage section and Reset remain usable

### Requirement: Changing a learning setting

A change SHALL take effect on screen at once and SHALL be sent as `PUT /api/config?profile=<profile>` whose `config` holds only the changed key, for example `{"memory": {"write_approval": true}}`. At most one write per key SHALL be in flight; a change made meanwhile SHALL be sent after it with the latest value. When the server refuses the write or it fails, the control SHALL return to the last value the server confirmed and the screen SHALL say "Couldn't change <setting>. Try again."

#### Scenario: Switch saved

- **WHEN** the user turns on "Ask before saving" and the server answers with success
- **THEN** the body sent is `{"config": {"memory": {"write_approval": true}}, "profile": "<profile>"}` and the switch stays on

#### Scenario: Switch refused

- **WHEN** the user turns off "Keep agent notes" and the write fails
- **THEN** the switch returns to on and the screen says "Couldn't change Keep agent notes. Try again."

### Requirement: Memory provider row

The Memory screen SHALL show a Storage section with a Memory provider row read from `GET /api/memory?profile=<profile>`. When `active` is empty the row SHALL read "Built-in · MEMORY.md and USER.md"; otherwise it SHALL show the active provider's name and description. When the active provider's `status` is `missing`, the section SHALL show an error banner saying the provider is configured but not installed on the server. A `needs_config` or `unavailable` status SHALL add a warning line. A tap SHALL open the Plugins screen on its Providers tab for the same profile. A failed read SHALL show "Couldn't read the memory provider" with a retry, and SHALL NOT hide the rest of the screen.

#### Scenario: Built-in memory

- **WHEN** `GET /api/memory` answers `active: ""`
- **THEN** the row reads "Built-in · MEMORY.md and USER.md"

#### Scenario: Provider gone

- **WHEN** the active provider reports `status: missing`
- **THEN** an error banner says it is configured but not installed on the server

#### Scenario: Open providers

- **WHEN** the user taps the Memory provider row of profile "work"
- **THEN** the Plugins screen opens for "work" with the Providers tab selected

### Requirement: Resetting memory

The Memory screen SHALL offer "Reset memory…", which asks with an alert offering Reset agent notes, Reset about you, Reset both and Cancel, with the footnote "Erases the files on the server. Open chats keep what they started with. This can't be undone." The reset actions SHALL be destructive. Confirming SHALL send `POST /api/memory/reset?profile=<profile>` with `{"target": "memory"}`, `{"target": "user"}` or `{"target": "all"}`, always with the profile, and SHALL be counted as done only when the answer has `ok: true`. After a reset the screen SHALL read its entries and settings again. A refusal SHALL show the server's `detail` when it is text. A lost answer SHALL say the reset may have happened, read the entries again, and SHALL NOT repeat the request. Cancel SHALL send nothing.

#### Scenario: Reset about you

- **WHEN** the user confirms Reset about you for profile "work" and the server answers `{ok: true, deleted: ["USER.md"]}`
- **THEN** the request was `POST /api/memory/reset?profile=work` with `{"target": "user"}`, and About you is read again and shows "Nothing remembered yet"

#### Scenario: Cancelled

- **WHEN** the user picks Cancel
- **THEN** no request is sent

#### Scenario: Lost answer

- **WHEN** the connection drops before the reset is answered
- **THEN** the screen says the reset may have happened, reads the entries again and does not send the reset a second time

### Requirement: Memory settings backend contract

The settings SHALL rely on `GET /api/config?profile=` (defaults included), `PUT /api/config?profile=` with `ConfigUpdate` (`config` deep-merged into the saved file), `GET /api/memory?profile=` (`active`, `providers[]` with `name`, `description`, `status` of `ready`, `needs_config`, `unavailable` or `missing`, and `builtin_files`), and `POST /api/memory/reset?profile=` with `MemoryReset` (`target`) answering `{ok, deleted}`. `memory.write_approval` is read by Hermes at every write; the other keys when a session starts. These shapes were verified at Hermes `71d34bad`; earliest release support is unverified. A malformed answer SHALL be reported as unreadable, never as success.

#### Scenario: Malformed reset answer

- **WHEN** the reset answer is not an object with a boolean `ok`
- **THEN** the screen treats the outcome as uncertain and reads the entries again

### Requirement: Memory settings telemetry

The config read, each write, the provider read and the reset SHALL each be traced as a span (`memory.settings.fetch`, `memory.settings.write` with `key`, `memory.status.fetch` with `provider_status`, `memory.reset` with `target`), each with its `outcome`. Each write SHALL log `memory.setting_changed` (`key`, `outcome`) and each reset `memory.reset_outcome` (`target`, `outcome`, `deleted` count). A changed setting SHALL add a `memory.setting_toggled` breadcrumb (`key`) and a confirmed reset a `memory.reset_confirmed` breadcrumb (`target`). `key` and `target` SHALL be fixed slugs. None of them SHALL carry memory text, provider names, file names, ids or profile names.

#### Scenario: Reset logged

- **WHEN** a reset of both files succeeds
- **THEN** `memory.reset_outcome` is logged with `target: all`, `outcome: reset` and `deleted: 2`, and no file or profile name
