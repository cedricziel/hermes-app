# Spec Delta

## Purpose

Describes the `hermes://` URL scheme: which links the app opens, what each one shows, how a link waits for sign-in and for the server's feature check, and which links are ignored.

## ADDED Requirements

### Requirement: The hermes URL scheme

The app SHALL register the `hermes` URL scheme on iOS, macOS and Android and SHALL open these links, where every query parameter is optional unless stated and percent-encoded values are decoded once:

- `hermes://chat?profile=<p>&id=<threadId>&prompt=<text>` (`id` required): the chat `id` in profile `p`, or in the current profile when `p` is absent;
- `hermes://new?profile=<p>&dictate=1&prompt=<text>`: a new chat;
- `hermes://requests`: the chat of the oldest open request;
- `hermes://kanban`: the Kanban tab;
- `hermes://schedules?profile=<p>&job=<id>`: the Schedules tab, with job `id` of profile `p` open when given.

The existing `hermes-activity` and `hermes-share` schemes SHALL keep their behaviour. A link SHALL close screens pushed over the current tab before it shows its target.

#### Scenario: Link while the app runs

- **WHEN** the app shows Kanban and the user opens `hermes://chat?profile=work&id=abc`
- **THEN** the app shows the chat tab with chat `abc` of profile `work` open

#### Scenario: Link that launches the app

- **WHEN** the app is not running and the user opens `hermes://schedules`
- **THEN** the app starts and, once signed in and the server reports schedules, shows the Schedules tab

#### Scenario: Encoded values

- **WHEN** the user opens `hermes://new?prompt=Plan%20a%20trip%20%26%20book`
- **THEN** the composer holds "Plan a trip & book"

### Requirement: Opening a chat

A `chat` link SHALL open that chat the same way opening a run of a scheduled task does: it SHALL switch to the link's profile when it differs, SHALL fetch the chat when the loaded pages do not hold it, and SHALL show "Could not open that chat." when the chat cannot be found or the profile cannot be loaded. A `prompt` SHALL be put into that chat's composer, cut to 4000 characters, and SHALL NOT be sent; when the chat cannot be opened the prompt SHALL be dropped.

#### Scenario: Older chat

- **WHEN** a `chat` link names a chat older than the loaded pages
- **THEN** the chat is fetched and opened

#### Scenario: Deleted chat

- **WHEN** a `chat` link names a chat that no longer exists
- **THEN** the open chat stays as it was and "Could not open that chat." is shown

#### Scenario: Prompt for an existing chat

- **WHEN** the user opens `hermes://chat?profile=work&id=abc&prompt=Yes%2C%20book%20it`
- **THEN** chat `abc` of profile `work` is open, its composer holds "Yes, book it", and nothing is sent

### Requirement: Starting a new chat

A `new` link SHALL start a new chat, in the link's profile when given. A `prompt` SHALL be put into the composer and SHALL NOT be sent; text longer than 4000 characters SHALL be cut to 4000. `dictate=1` (or `true`) SHALL start dictation when the composer offers the microphone for that profile and SHALL be ignored otherwise.

#### Scenario: Prompt prefilled, not sent

- **WHEN** the user opens `hermes://new?prompt=Summarize%20my%20day`
- **THEN** a new chat is shown with "Summarize my day" in the composer and no message is sent

#### Scenario: Dictation requested

- **WHEN** the user opens `hermes://new?dictate=1` and dictation is available
- **THEN** a new chat is shown with dictation running

#### Scenario: Dictation unavailable

- **WHEN** the user opens `hermes://new?dictate=1` and the profile offers no speech-to-text
- **THEN** a new chat is shown and no microphone starts

### Requirement: Opening the oldest request

A `requests` link SHALL open the chat holding the open approval, question or input request that was raised first among the chats the app has loaded. When the app knows of no open request it SHALL show the chat list without opening a chat.

#### Scenario: Two chats waiting

- **WHEN** chat A has had an approval open since 10:00 and chat B a question since 10:05, and the user opens `hermes://requests`
- **THEN** chat A is opened

#### Scenario: Nothing waiting

- **WHEN** no loaded chat has an open request and the user opens `hermes://requests`
- **THEN** the chat list is shown

### Requirement: Links wait for sign-in and feature checks

A link that arrives while nobody is signed in SHALL be kept and applied after sign-in completes; only the latest such link SHALL be kept, and signing out SHALL drop it. A `kanban` or `schedules` link that arrives before the app has learned whether the server offers that tab SHALL be applied once it knows. A link SHALL NOT bypass App Lock: its target SHALL be shown once the app is unlocked.

#### Scenario: Link on the sign-in screen

- **WHEN** the user opens a `chat` link while the sign-in screen is shown and then signs in
- **THEN** that chat opens after sign-in

#### Scenario: Locked app

- **WHEN** App Lock is on and the user opens a `chat` link
- **THEN** the lock screen is shown and the chat is open behind it after unlocking

### Requirement: Ignored links

The app SHALL ignore, without any message to the user, a link with an unknown host, a `chat` link without `id`, a link of another scheme reaching the handler, and a `kanban` or `schedules` link when the server does not offer that tab. Unknown query parameters SHALL be ignored and SHALL NOT make a link invalid.

#### Scenario: Unknown target

- **WHEN** the user opens `hermes://memory`
- **THEN** nothing changes on screen

#### Scenario: Kanban without the plugin

- **WHEN** the server does not have the Kanban plugin enabled and the user opens `hermes://kanban`
- **THEN** the current tab stays and nothing is shown

#### Scenario: Extra parameter

- **WHEN** the user opens `hermes://chat?id=abc&source=widget`
- **THEN** chat `abc` is opened

### Requirement: Nothing private in telemetry

Opening or ignoring a link SHALL record only a breadcrumb with the link kind, whether it launched the app, whether it waited, or the reason it was ignored. The URL, profile, chat or job id and prompt text SHALL NOT be recorded.

#### Scenario: Prompt link

- **WHEN** the user opens a `new` link with a prompt
- **THEN** the breadcrumb says `kind: new` and holds no prompt text

### Requirement: Backend contract

Deep links SHALL use only routes the app already calls to open their targets (`GET /api/sessions`, `GET /api/sessions/{session_id}` for a chat outside the loaded pages, `GET /api/dashboard/plugins` and `GET /api/cron/delivery-targets` for tab availability) and SHALL need no new Hermes route, RPC method or minimum version.

#### Scenario: Oldest supported Hermes

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** every link kind works as described
