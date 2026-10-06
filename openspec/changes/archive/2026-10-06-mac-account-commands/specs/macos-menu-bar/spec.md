## MODIFIED Requirements

### Requirement: Mac menu bar

On macOS the system SHALL set a native menu bar with these menus and items, in this order:

- Hermes: About Hermes; Settings… (⌘,); Connection Details, Sign Out…; Services; Hide Hermes (⌘H), Hide Others (⌥⌘H), Show All; Quit Hermes (⌘Q).
- File: New Chat (⌘N), Open in New Window (⌥⌘O); Close Window (⌘W).
- Edit: Undo (⌘Z), Redo (⇧⌘Z); Cut (⌘X), Copy (⌘C), Paste (⌘V), Select All (⌘A).
- View: Show/Hide Sidebar (⌃⌘S), Show Inspector (⌥⌘I); Enter Full Screen.
- Chat: Find… (⌘F); Pin or Unpin (⇧⌘P), Rename…, Copy Transcript; Archive, Delete… (⌘⌫).
- Window: Minimize (⌘M), Zoom; Hermes (⌘0) followed by the open conversation windows; Bring All to Front.
- Help: Hermes Help, which opens the project's README in the browser.

An item SHALL be disabled while the screen in front offers no handler for it. Connection Details SHALL open the connection page, and Sign Out… SHALL ask "Sign out of the dashboard?" before signing out; it SHALL be disabled when the server needs no sign-in. On other platforms the system SHALL NOT set a menu bar. No backend route is involved.

#### Scenario: Menus on macOS

- **WHEN** the app runs on macOS
- **THEN** the menu bar shows the Hermes, File, Edit, View, Chat, Window and Help menus with the items and shortcuts above

#### Scenario: Not on other platforms

- **WHEN** the app runs on Windows, Linux, Android, iOS or the web
- **THEN** no menu bar is set and the app looks as before

#### Scenario: Unavailable command

- **WHEN** no screen offers a command, such as Open in New Window before conversation windows exist
- **THEN** its item is shown disabled

#### Scenario: Sign Out from the menu

- **WHEN** the user chooses Sign Out… in the Hermes menu and cancels the question
- **THEN** the user stays signed in; confirming with Sign Out signs out
