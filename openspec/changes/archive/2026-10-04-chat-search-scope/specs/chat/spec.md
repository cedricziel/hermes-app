## ADDED Requirements

### Requirement: Searching from a Mac toolbar

On macOS the chat SHALL be searched from the window's toolbar instead of the sidebar: a field in a large window (1000 points and wider), a search button that opens the field in a narrower one. ⌘F SHALL open the search and put the cursor in the field; Escape and the field's clear button SHALL end it. While a search is open the sidebar SHALL show its results in place of the destinations and threads. The sidebar SHALL have no search field and no New chat row there; New Chat is a toolbar button.

The results SHALL offer two scopes, "This profile" and "All profiles", when the server lists profiles. All profiles SHALL search every profile with `GET /api/sessions/search?profile=<name>` at the same time and merge the results newest first; a profile whose search fails SHALL be left out, and the search SHALL fail only when every profile fails. Hits SHALL be grouped into Chats (the title holds the query) and Messages (the rest), each with its count, and each hit SHALL show its title, when it was last active and two lines of matched text with the matches emphasised. A hit from another profile SHALL name that profile before its text, and opening it SHALL switch to that profile and open the chat. With an empty field the results SHALL list the last five searches, which are kept across launches; opening a hit or pressing Return in the field SHALL add the query to them. No hits SHALL read "No results for “<query>”".

#### Scenario: Command-F

- **WHEN** the user presses ⌘F with the chat in front
- **THEN** the search field takes the cursor and the sidebar lists the recent searches

#### Scenario: Results replace the sidebar

- **WHEN** the user types a query and pauses
- **THEN** the sidebar shows the hits under Chats and Messages, and Escape brings the destinations and threads back

#### Scenario: All profiles with one failing

- **WHEN** the user picks All profiles and one profile's search fails
- **THEN** the hits of the other profiles are shown, newest first

#### Scenario: A hit from another profile

- **WHEN** the user opens a hit found in the profile "work" while "default" is active
- **THEN** the chat switches to "work" and opens that chat

### Requirement: Mac chat toolbar

On macOS the chat's toolbar SHALL show the open chat's title (or "Hermes") over a line "<profile> · <model>" (the chat's model choice, else the profile's default; parts that are unknown left out), then New Chat (⌘N), Copy Transcript, Connection Details and the search. In a window narrower than 760 points Copy Transcript and Connection Details SHALL be in a "…" menu.

#### Scenario: Compact toolbar

- **WHEN** the window is 680 points wide
- **THEN** the toolbar shows New Chat, a "…" menu holding Copy Transcript and Connection Details, and a search button

### Requirement: Sidebar of a compact Mac window

On macOS the sidebar SHALL stay beside the content down to a window width of 760 points. In a narrower window it SHALL not be docked; the toolbar's sidebar button and ⌃⌘S SHALL open it over the content, with a scrim that closes it, and picking a thread, a search hit or a destination SHALL close it. Opening a search in a compact window SHALL open the sidebar for the results. Whether the docked sidebar is hidden SHALL not change through a compact window.

#### Scenario: Overlay closes on a pick

- **WHEN** the user opens the sidebar in a 700 point window and picks a thread
- **THEN** the thread opens and the sidebar closes
