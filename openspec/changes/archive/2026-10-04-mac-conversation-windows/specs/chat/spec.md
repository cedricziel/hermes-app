## ADDED Requirements

### Requirement: Conversation windows (macOS)

On macOS the system SHALL let the user open a chat the dashboard holds in a window of its own, from the thread's "Open in New Window" action (⌥⌘O) or by double-clicking the thread in the sidebar. The window SHALL show only that chat: a toolbar with the chat's title and "<profile> · <model>" below it, the messages and the composer, without the sidebar. Its toolbar SHALL offer Show in Main Window, Pin or Unpin (⇧⌘P), Share and a menu with Rename, Copy Transcript, Archive and Delete. The window SHALL stay on the profile the chat was opened from, whatever profile the main window switches to. Opening a chat that already has a window SHALL bring that window to the front. The Window menu SHALL list the open conversation windows and mark the key one; ⌘0 SHALL bring back the main window and ⌘W SHALL close the key conversation window. The open conversation windows SHALL be opened again, in their last frames, the next time the app connects to the same server. Signing out or changing server SHALL close them. On other platforms none of this is offered.

A conversation window SHALL NOT read stored tokens or refresh the session itself: it SHALL get the headers for each request from the main window, which stays the only part of the app that refreshes the session.

The system SHALL rely on the same routes as the main window: `GET /api/sessions`, `GET /api/sessions/{id}`, `GET /api/sessions/{id}/messages`, the session housekeeping routes and the `/api/ws` socket, all with `profile=<name>`.

#### Scenario: Open a chat in its own window

- **WHEN** the user picks "Open in New Window" for a chat in the sidebar
- **THEN** a new window shows that chat's messages and composer, with the chat's title and its profile and model in the toolbar, and no sidebar

#### Scenario: The window keeps its profile

- **WHEN** a chat from profile A is open in its own window and the user switches the main window to profile B
- **THEN** the conversation window still shows the chat from profile A and sends to profile A

#### Scenario: The same chat is not opened twice

- **WHEN** the user opens a chat in a new window while it already has one
- **THEN** the existing window comes to the front and no second window opens

#### Scenario: Show in main window

- **WHEN** the user picks Show in Main Window in a conversation window
- **THEN** the main window comes to the front with that chat selected, switching to the chat's profile if needed

#### Scenario: A reply sent in one window shows in the other

- **WHEN** the user sends a message in a conversation window and, after the reply, makes the main window key
- **THEN** the main window shows the message and the reply in that chat

#### Scenario: Deleted in its window

- **WHEN** the user deletes the chat from its conversation window
- **THEN** the window closes, and the chat is gone from the main window's list once that window is key again

#### Scenario: Windows come back after a relaunch

- **WHEN** the user quits the app with two conversation windows open and launches it again on the same server
- **THEN** both windows open again where they were, each on its own chat and profile

#### Scenario: Sign-out closes the windows

- **WHEN** the user signs out in the main window
- **THEN** every conversation window closes and none is opened again on the next launch

#### Scenario: A conversation window never refreshes the session

- **WHEN** a request from a conversation window gets a 401
- **THEN** the window asks the main window for new headers, naming the ones that failed, retries once with them, and the main window refreshes the session only if those were its current token
