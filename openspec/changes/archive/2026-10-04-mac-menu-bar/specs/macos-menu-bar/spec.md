## ADDED Requirements

### Requirement: Mac menu bar

On macOS the system SHALL set a native menu bar with these menus and items, in this order:

- Hermes: About Hermes; Settings… (⌘,); Services; Hide Hermes (⌘H), Hide Others (⌥⌘H), Show All; Quit Hermes (⌘Q).
- File: New Chat (⌘N), Open in New Window (⌥⌘O); Close Window (⌘W).
- Edit: Undo (⌘Z), Redo (⇧⌘Z); Cut (⌘X), Copy (⌘C), Paste (⌘V), Select All (⌘A).
- View: Show/Hide Sidebar (⌃⌘S), Show Inspector (⌥⌘I); Enter Full Screen.
- Chat: Find… (⌘F); Pin or Unpin (⇧⌘P), Rename…, Copy Transcript; Archive, Delete… (⌘⌫).
- Window: Minimize (⌘M), Zoom; Hermes (⌘0) followed by the open conversation windows; Bring All to Front.
- Help: Hermes Help, which opens the project's README in the browser.

An item SHALL be disabled while the screen in front offers no handler for it. On other platforms the system SHALL NOT set a menu bar. No backend route is involved.

#### Scenario: Menus on macOS

- **WHEN** the app runs on macOS
- **THEN** the menu bar shows the Hermes, File, Edit, View, Chat, Window and Help menus with the items and shortcuts above

#### Scenario: Not on other platforms

- **WHEN** the app runs on Windows, Linux, Android, iOS or the web
- **THEN** no menu bar is set and the app looks as before

#### Scenario: Unavailable command

- **WHEN** no screen offers a command, such as Open in New Window before conversation windows exist
- **THEN** its item is shown disabled

### Requirement: Chat commands in the menu bar

On macOS the chat screen SHALL offer New Chat, which starts a new chat; Find…, which shows the sidebar if it is hidden and puts the cursor in its search field; and, for the selected chat, Pin or Unpin (the label follows the chat's state), Rename…, Copy Transcript, Archive and Delete…, which do what the same actions in the chat's actions menu do, including asking before renaming or deleting. The thread actions SHALL be disabled while no chat is selected, and Pin, Rename…, Archive and Delete… also while the selected chat is not one the dashboard holds. A hidden chat screen, such as one behind the Kanban tab, SHALL offer nothing.

#### Scenario: Pin from the menu

- **WHEN** a chat is selected and the user picks Pin or presses ⇧⌘P
- **THEN** the chat is pinned and the item reads Unpin

#### Scenario: Delete asks first

- **WHEN** a chat is selected, no text field has focus, and the user presses ⌘⌫
- **THEN** the app asks to confirm before deleting the chat

#### Scenario: Find

- **WHEN** the user presses ⌘F with the sidebar hidden
- **THEN** the sidebar is shown and its search field has focus

### Requirement: Editing through the menu bar

On macOS the Edit menu's items SHALL act on the focused text: Undo and Redo on its edit history, Cut, Copy and Paste through the clipboard, Select All on its text, also in selectable message text. Their shortcuts SHALL keep working in every text field. While a text field has focus, Delete… (⌘⌫) SHALL delete from the cursor to the start of the line and SHALL NOT delete the chat.

#### Scenario: Copy and paste in the composer

- **WHEN** the user selects text in the composer and picks Copy, then Paste, from the Edit menu or with ⌘C and ⌘V
- **THEN** the text is copied and pasted as in any Mac text field

#### Scenario: Command-Delete in a text field

- **WHEN** the composer has focus and the user presses ⌘⌫
- **THEN** the text before the cursor on that line is deleted and the selected chat is kept

### Requirement: One owner per shortcut

Each menu shortcut SHALL run its command once. The sidebar SHALL NOT handle Control-Command-S itself; the View menu item does.

#### Scenario: Sidebar toggle

- **WHEN** the user presses ⌃⌘S
- **THEN** the sidebar hides or shows once, and the View menu item's label changes between Hide Sidebar and Show Sidebar
