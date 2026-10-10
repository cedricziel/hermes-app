## ADDED Requirements

### Requirement: The app keeps running after its last window closes on macOS
On macOS, closing the last window SHALL leave the app running with its Dock icon. Cmd-Q, Hermes > Quit and the menu bar item's Quit SHALL end it. The app SHALL never switch to an accessory (Dock-less) mode.

#### Scenario: Close the main window with a reply running
- **WHEN** a reply is streaming and the user closes the main window, with no conversation window open
- **THEN** the app keeps running, the reply keeps streaming, and its completion posts a notification

#### Scenario: Reopen from the Dock
- **WHEN** no window is visible and the user clicks the Dock icon
- **THEN** the main window reappears with its earlier state

#### Scenario: Quit
- **WHEN** the user presses Cmd-Q with no window visible
- **THEN** the app terminates

### Requirement: Background checks continue without a window
While the app runs with no visible window on macOS, schedule checks SHALL keep their one-minute interval, and reply and request notifications SHALL be posted as for an unfocused app. Other platforms SHALL keep today's behaviour.

#### Scenario: Scheduled run while windowless
- **WHEN** no window is visible and a cron job finishes a run
- **THEN** a notification for the run is posted within about a minute

#### Scenario: Focused thread is still not notified
- **WHEN** the main window is focused on a chat whose reply completes
- **THEN** no notification is posted for it

### Requirement: Menu bar item shows the app's state
On macOS a menu bar item SHALL be shown by default. Its icon SHALL show needs attention when any followed chat has an open request, otherwise working when any followed chat is replying, otherwise idle. The icon SHALL adapt to light and dark menu bars.

#### Scenario: Approval raised
- **WHEN** a followed chat raises an approval
- **THEN** the icon changes to needs attention, and returns to working or idle once the approval is answered or withdrawn

### Requirement: Menu lists running replies and pending requests of followed chats
The menu SHALL list the chats this app is following live (replies sent from this Mac and follow-up turns on chats it listens to) that are replying, and their open requests. It SHALL make no server request to build the list. Each approval SHALL be a submenu showing its command and exactly the choices the request offers. A choice SHALL be answered as the chat card answers it. Other request kinds SHALL open their chat. The menu SHALL end with New Chat, Show Main Window and Quit. Replies running only in a separate conversation window are not listed.

#### Scenario: Open a running reply
- **WHEN** the user picks a replying chat in the menu
- **THEN** that chat is shown, in its conversation window if it has one, otherwise in the main window, which is brought forward

#### Scenario: Approve from the menu
- **WHEN** the user picks "Allow once" in an approval's submenu
- **THEN** the approval is answered with `once`, the chat card shows it answered, and the item leaves the menu

#### Scenario: Request expired meanwhile
- **WHEN** the server rejects the answer because the request was withdrawn
- **THEN** the card shows the request as expired and the item leaves the menu

#### Scenario: Signed out
- **WHEN** the user is signed out
- **THEN** the menu shows only New Chat, Show Main Window and Quit, and the icon is idle

### Requirement: The menu respects App Lock
While the app is locked, the menu SHALL show only counts of running replies and waiting requests, an Unlock Hermes entry, New Chat, Show Main Window and Quit. It SHALL NOT show a chat title or a command, and SHALL NOT answer an approval. Unlock Hermes SHALL bring the main window forward and ask the device to confirm.

#### Scenario: Locked with an approval waiting
- **WHEN** the app is locked and a followed chat has an approval waiting
- **THEN** the menu shows "1 request waiting" and "Unlock Hermes…", and no command or choice

#### Scenario: A pick made before the lock
- **WHEN** the user picked "Allow once" on a menu that was built before the app locked
- **THEN** nothing is sent

### Requirement: A pick does what its row said, once
A pick that no longer matches a row of the menu SHALL do nothing. An approval SHALL be answered at most once: its choices are not offered while an answer is on its way, and a request answered elsewhere while the "always" question was open SHALL NOT be answered again.

### Requirement: Setting hides the menu bar item
Settings SHALL offer a macOS-only switch to hide the menu bar item, kept across launches. Hiding it SHALL NOT change the stay-alive behaviour.

#### Scenario: Hide the item
- **WHEN** the user turns the switch off
- **THEN** the item disappears at once and stays hidden after a relaunch, and closing the last window still leaves the app running

### Requirement: Backend contract
The feature SHALL use only the existing gateway methods the chat already relies on: approval answers over `/api/ws` (`approval.respond`, as the chat card sends) and the existing cron routes (`GET /api/cron/jobs`) for schedule checks. It needs no new route and no Hermes version beyond the app's current minimum.

#### Scenario: No new traffic
- **WHEN** the menu is opened
- **THEN** no HTTP request or RPC is sent
