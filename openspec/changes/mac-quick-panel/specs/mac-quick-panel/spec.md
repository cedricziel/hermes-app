## ADDED Requirements

### Requirement: User-recorded global shortcut

On macOS the app SHALL offer a Quick panel setting where the user records, changes or clears a global keyboard shortcut. There SHALL be no default shortcut. The recorder SHALL warn when the chord clashes with a system shortcut or a command in the app's menu bar. The shortcut SHALL work while Hermes is running, whether or not it is the frontmost app, and SHALL require no Accessibility or Input Monitoring permission. Other platforms SHALL NOT show the setting.

#### Scenario: Record a shortcut
- **WHEN** the user records Option-Space in Settings
- **THEN** pressing Option-Space in any app shows the quick panel

#### Scenario: Chord clashes with the menu bar
- **WHEN** the user records a chord that a menu bar command already uses
- **THEN** the recorder warns about the clash before the chord is kept

#### Scenario: Clear the shortcut
- **WHEN** the user clears the shortcut
- **THEN** no chord shows the panel until a new one is recorded

### Requirement: Floating non-activating panel

Pressing the shortcut SHALL show the panel above other apps' windows on the current Space, including over a full-screen app, with keyboard focus in its composer, without bringing Hermes' main or conversation windows forward. Pressing the shortcut while the panel is key SHALL hide it. Escape SHALL cancel an active dictation first and otherwise hide the panel. The panel SHALL not appear in the Window menu's window list or be restored at launch. Signing out SHALL close it.

#### Scenario: Summon over another app
- **WHEN** another app is frontmost and the user presses the shortcut
- **THEN** the panel appears with the cursor in its composer and the main window stays where it was

#### Scenario: Dismiss
- **WHEN** the panel is key and the user presses Escape
- **THEN** the panel hides and the previous app gets focus back

#### Scenario: Not signed in
- **WHEN** the app has no ready connection and the shortcut is pressed
- **THEN** the main window comes forward on its setup or sign-in screen instead of the panel

### Requirement: Send and stream in the panel

The panel composer SHALL offer text, attachments, dictation and the model pill as the chat composer does. Return SHALL send. The reply SHALL stream inside the panel, with tool calls and approval or clarify requests shown and answerable as in a chat. The chat SHALL be a saved session in the main window's current profile and SHALL appear in that profile's chat list.

#### Scenario: Ask a question
- **WHEN** the user types a prompt and presses Return
- **THEN** the reply streams below the prompt in the panel and the chat appears in the main window's history

### Requirement: Continue within five minutes

Showing the panel within 5 minutes of its last send or reply event, with the main window's current profile unchanged, SHALL show the same chat. Otherwise the panel SHALL start empty and the next send SHALL create a new chat.

#### Scenario: Quick follow-up
- **WHEN** the user hides the panel and shows it again 2 minutes later
- **THEN** the previous exchange is shown and a new prompt continues it

#### Scenario: Stale chat
- **WHEN** the panel is shown 6 minutes after its last activity, or after the current profile changed
- **THEN** the panel is empty

### Requirement: Open in Hermes

"Open in Hermes" (button and Command-O) SHALL open the panel's chat in a conversation window, or focus that window if one already shows the chat, and hide the panel. The next show SHALL start empty.

#### Scenario: Move to a window
- **WHEN** a reply is streaming and the user chooses Open in Hermes
- **THEN** a conversation window shows the chat with the reply still streaming and the panel hides

### Requirement: Backend contract

The panel SHALL use only what chat already relies on: the `/api/ws` gateway (`session.create`, `session.resume`, `prompt.submit` and their events), `GET /api/sessions/{id}/messages` for history, `GET /api/model/options` for the model pill, and `/api/audio/*` for Hermes dictation. No new route is needed. The minimum Hermes version is the one chat and conversation windows already require.

#### Scenario: Model options unavailable
- **WHEN** `GET /api/model/options` fails
- **THEN** the panel hides the model pill and sending still works

### Requirement: No user content in telemetry

Breadcrumbs and log events about the panel SHALL hold fixed names, flags and reasons only, never prompt text, titles, profile names, server addresses or ids.

#### Scenario: Shortcut change logged
- **WHEN** the user records or clears the shortcut
- **THEN** one log event records only whether a shortcut is set, never the chord or any user content
