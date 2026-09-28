# Spec Delta

## MODIFIED Requirements

### Requirement: Rendering of messages

The system SHALL render a message as its tool call cards, each after the reasoning that led to it, then the reasoning that followed the last call, then agent input request cards, then the text, then a thinking indicator, and SHALL render message text as markdown.

#### Scenario: Thinking indicator

- **WHEN** an assistant reply is pending with no text yet, no reasoning yet and no input request is waiting
- **THEN** a thinking indicator (three pulsing dots) is shown in place of text

#### Scenario: No indicator while the agent waits for the user

- **WHEN** a reply is still thinking and one of its input requests is pending
- **THEN** the thinking indicator is hidden

#### Scenario: No indicator once reasoning shows

- **WHEN** a reply is still thinking and has reasoning
- **THEN** the thinking indicator is hidden and the reasoning block is shown

#### Scenario: Failed reply

- **WHEN** a reply ended in error and has text
- **THEN** its text is drawn in the error colour

#### Scenario: Empty thread

- **WHEN** the open thread has no messages, or no thread is selected
- **THEN** the welcome view shows "Where should we begin?" (with the user's display name appended when known) and four starter prompts as defined by "Context-based starter prompts"

#### Scenario: Responsive layout

- **WHEN** the available width is at least 900 logical pixels
- **THEN** the thread rail is permanently shown beside the transcript, with the thread title above it
- **AND WHEN** the width is smaller
- **THEN** the rail opens as a drawer and the thread title is shown in the app bar

## ADDED Requirements

### Requirement: Context-based starter prompts

The system SHALL show four starter prompts in the welcome view. It SHALL build them on the device from the active profile's context, without calling a model, taking at most one prompt from each of these sources in this order:

1. Scheduled jobs: a job whose last run failed. The prompt reads "Why did the scheduled job '<name>' fail on its last run?".
2. Kanban, only while the dashboard reports the Kanban plugin as enabled: a task in the default board with status `blocked`, or else one with status `review`. The prompt reads "What's blocking the Kanban task '<title>'?" or "What's left before the Kanban task '<title>' is done?".
3. Recent chats: the most recently active chat of the profile that has a title and is not the chat on screen. The prompt reads "Pick up '<title>'".
4. Skills: the enabled skill with the highest use count, if its use count is above zero. The prompt reads "Use the <name> skill to ".

When several items of a source qualify, the system SHALL pick the most recent one (by last run time for jobs, by the board's order for tasks). The system SHALL fill the remaining slots with generic prompts that make sense on any server, in a fixed order. Each prompt SHALL show an icon for its source.

The system SHALL show the generic prompts immediately and SHALL replace them with the contextual prompts once, when every source has answered, failed or timed out. A source that fails, times out, or answers with rows it cannot parse SHALL be left out without showing an error. The context SHALL be loaded again when the active profile changes, and when the welcome view is shown and the last load is more than five minutes old.

Tapping a generic prompt SHALL send it as a message. Tapping a job, Kanban or skill prompt SHALL put its text into the composer without sending it, replacing any text already there. Tapping a recent-chat prompt SHALL open that chat.

The system SHALL rely on these dashboard routes, which the Schedules, Kanban and Skills screens already use: `GET /api/cron/jobs?profile=<name>` (a job's `name`, `last_run_at`, `last_status`, `state`), `GET /api/dashboard/plugins` (an entry with `name: kanban`), `GET /api/plugins/kanban/board` (tasks with `title` and `status`) and `GET /api/skills?profile=<name>` (`name`, `enabled`, `usage`). It needs no newer Hermes version than those screens.

#### Scenario: New install with no context

- **WHEN** the welcome view is shown and no source yields a prompt
- **THEN** four generic prompts are shown, and tapping one sends it as a message

#### Scenario: Every source yields a prompt

- **WHEN** a scheduled job's last run failed, the Kanban plugin is on and a task is blocked, the profile has an earlier titled chat, and an enabled skill has been used
- **THEN** the welcome view shows, in this order, the failed-job prompt, the blocked-task prompt, the recent-chat prompt and the skill prompt, each with its source icon, and no generic prompt

#### Scenario: Some sources yield a prompt

- **WHEN** only the recent-chat source yields a prompt
- **THEN** the recent-chat prompt is shown first, followed by three generic prompts

#### Scenario: Kanban plugin off

- **WHEN** the dashboard does not report the Kanban plugin as enabled
- **THEN** no Kanban prompt is shown and the Kanban board is not requested

#### Scenario: Review task when nothing is blocked

- **WHEN** the Kanban plugin is on, no task is blocked and a task is waiting for review
- **THEN** the Kanban prompt asks what is left before that task is done

#### Scenario: Source fails

- **WHEN** listing the scheduled jobs fails or times out
- **THEN** no job prompt is shown, the other sources still yield their prompts, and no error is shown

#### Scenario: Prompts swap once

- **WHEN** the welcome view is shown before the context has loaded
- **THEN** the generic prompts are shown, and they are replaced by the contextual prompts once, after every source has answered, failed or timed out

#### Scenario: Tapping a specific prompt fills the composer

- **WHEN** the user taps the failed-job, Kanban or skill prompt
- **THEN** its text is put into the composer, replacing what was there, and nothing is sent

#### Scenario: Tapping a recent-chat prompt opens the chat

- **WHEN** the user taps "Pick up '<title>'"
- **THEN** that chat is opened and nothing is sent

#### Scenario: Profile switch

- **WHEN** the user switches to another profile while the welcome view is shown
- **THEN** the prompts are rebuilt from the new profile's jobs, chats and skills
