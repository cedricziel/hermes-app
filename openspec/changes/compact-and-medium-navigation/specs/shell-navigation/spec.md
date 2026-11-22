## ADDED Requirements

### Requirement: The shell has three forms

The system SHALL choose the shell's form from the available width. Expanded is 900 logical pixels or more, and also a full-screen iPad of 700 or more and any Mac window; it keeps the sidebar. Medium is 600 to 899 logical pixels that are not expanded. Compact is below 600. The form SHALL be decided in one place, and `isWideLayout` SHALL be true exactly when the form is expanded on non-Mac platforms.

#### Scenario: Width table

- **WHEN** the available width is 599, 600, 719, 720, 899 and 900 logical pixels on an Android tablet
- **THEN** the forms are compact, medium, medium, medium, medium and expanded

#### Scenario: iPad

- **WHEN** a full-screen iPad is 744 logical pixels wide, and later the same iPad is in Split View at 507
- **THEN** the first is expanded with today's sidebar and the second is compact with the tab bar

#### Scenario: iPhone in landscape

- **WHEN** an iPhone is 852 logical pixels wide and 393 high
- **THEN** it is not expanded, because its shortest side is under 600, and it shows the tab bar

### Requirement: Destination bar and rail

On iOS below 900 logical pixels when not expanded (iPhone, iPad Split View and Slide Over) and on Android below 600, the shell SHALL show a bottom bar whose items are Chats, then Bots, Kanban and Schedules while the server offers each, then More. On Android, Windows and Linux from 600 to 899 logical pixels it SHALL show a navigation rail with the same items. On Windows and Linux below 600 it SHALL keep a drawer.

#### Scenario: Server offers everything

- **WHEN** the server offers Bots, Kanban and Schedules and the width is 390 on iPhone
- **THEN** the bar shows five items: Chats, Bots, Kanban, Schedules and More

#### Scenario: Server offers nothing extra

- **WHEN** the server offers none of Bots, Kanban and Schedules
- **THEN** the bar shows Chats and More

#### Scenario: A destination goes off

- **WHEN** the server stops offering Kanban while it is selected
- **THEN** its item disappears and Chats is selected

### Requirement: Destination items are labelled and large enough

The Apple form SHALL be a tab bar and the Material form a navigation bar or rail with labels always shown. Every item SHALL have a visible label and an accessible name, the selected item SHALL differ by a filled icon and a bold label as well as colour, and every target SHALL be at least 44 points on iOS and 48 logical pixels on Android at any text size.

#### Scenario: Large text

- **WHEN** the system text scale is 2.0 and the width is 320
- **THEN** all five labels are shown whole on one line and every item keeps its target size

### Requirement: The bar yields to the conversation and the keyboard

The bottom bar SHALL be hidden while a conversation is open in the compact messenger navigator and while the on-screen keyboard is shown. A page pushed over the shell SHALL cover the bar. Returning from a conversation SHALL show the bar with Chats selected.

#### Scenario: Open a conversation

- **WHEN** the user opens a conversation from the Chats list on a phone
- **THEN** the bar is not shown, and Back shows the list with the bar

#### Scenario: Keyboard

- **WHEN** the keyboard opens on any page of the shell
- **THEN** the bar does not rise above it

### Requirement: More holds everything else

More SHALL be a page, not a menu, that lists the management entries the chat sidebar and drawer list today, each under its present gate: Profiles, Skills, Memory (with its waiting count), Messaging, Plugins, MCP servers, Providers, Tools and Helper models. Picking an entry SHALL push its page over the shell.

#### Scenario: Gates are kept

- **WHEN** the server lacks the tools routes and has no Skills support
- **THEN** More shows no Tools, Skills or Memory entry and no error

### Requirement: More lists Server and Settings

More SHALL also list Server, with the needs-attention mark and its words, and Settings: Appearance, Notifications, Dictation, Voice calls, Spotlight, App lock, Connection details and About, followed by Sign out and Change server where the account menu offers them.

#### Scenario: Server needs attention

- **WHEN** the server status reports a problem
- **THEN** the More item and the Server row show a mark and the words "needs attention" in their accessible names

### Requirement: Medium Chats shows list and detail

From 720 logical pixels on the medium form, Chats SHALL show the thread list beside the open conversation, with the rail at the left. Below 720 it SHALL use the compact list and pushed conversation beside the rail. Resizing between forms SHALL keep the selected conversation, the unsent draft, queued prompts and an ongoing reply, and SHALL NOT build a second chat owner.

#### Scenario: Tablet in portrait

- **WHEN** an Android tablet is 800 logical pixels wide
- **THEN** the rail, the thread list and the conversation are shown together

#### Scenario: Resize with a draft

- **WHEN** a conversation with an unsent draft goes from 800 to 500 and back to 1000 logical pixels wide
- **THEN** the draft and the conversation are still there at each size and only one chat owner exists

### Requirement: State survives a switch

Switching destinations SHALL keep every page that was opened alive, with its filters, search text, selection and scroll position, as the sidebar does today. A page is built on first open only. Opening More SHALL NOT keep any entry's content.

#### Scenario: Kanban filter kept

- **WHEN** the user filters Kanban, opens Chats and returns
- **THEN** the filter is still applied

### Requirement: Links and notifications select the same destination

Every `hermes://` link and notification target SHALL select the same destination in every form as in the sidebar, closing pushed pages first and honouring route guards, the capability gates and the server checks. A Kanban or Schedules link for a destination the server does not offer SHALL be ignored with the existing fixed breadcrumb. No new link kind is added by this change.

#### Scenario: Kanban link on a phone

- **WHEN** a Kanban link arrives while Skills is open over Chats on a phone and the server offers Kanban
- **THEN** Skills closes and the Kanban item is selected

#### Scenario: Conversation link

- **WHEN** a conversation link arrives while Kanban is selected
- **THEN** Chats is selected, the conversation opens, and Back shows the list with the bar

### Requirement: App Lock covers the navigation

While App Lock covers the app, the bar, rail and drawer SHALL be hidden and unreachable, no item SHALL show any title, count or name beyond the fixed destination words and the server attention mark, and a link or notification target SHALL wait as it does today.

#### Scenario: Locked

- **WHEN** App Lock covers the app
- **THEN** no tab or rail item is in the accessibility tree or focusable, and unlocking restores the same selected destination

### Requirement: Navigation telemetry holds fixed values

Selecting a destination SHALL record the existing `nav.destination` breadcrumb with the destination name, the form (`compact`, `medium`, `expanded`) and how it was reached (`bar`, `rail`, `drawer`, `sidebar`, `more`). Opening More SHALL record `nav.more.opened`. No breadcrumb, span or log event SHALL carry a title, a profile name, a server address or an id.

#### Scenario: Breadcrumb

- **WHEN** the user taps Schedules in the bar
- **THEN** the breadcrumb holds `destination: schedules`, `form: compact` and `via: bar` and nothing else
