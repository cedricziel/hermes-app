## ADDED Requirements

### Requirement: The shell has three forms

The system SHALL choose the shell's form in one place, from the width, the platform and the Mac sidebar. Expanded, which keeps the sidebar, is 900 logical pixels or more, an iOS window of 700 or more whose shortest side is at least 600, and any Mac window. Medium is 600 to 899 and compact below 600, each only when not expanded. `isWideLayout` SHALL be true exactly when the form is expanded on non-Mac platforms.

#### Scenario: Width table

- **WHEN** the available width is 599, 600, 719, 720, 899 and 900 logical pixels on an Android tablet
- **THEN** the forms are compact, medium, medium, medium, medium and expanded

#### Scenario: iPad full screen and in Split View

- **WHEN** a full-screen iPad is 744 logical pixels wide, and later the same iPad is in Split View at 507
- **THEN** the first is expanded with today's sidebar and the second is compact with the tab bar

#### Scenario: iPhone in landscape

- **WHEN** an iPhone is 852 logical pixels wide and 393 high
- **THEN** it is medium, not expanded, because it is under 900 and its shortest side is under 600, and it shows the tab bar
- **AND WHEN** an iPhone is 932 logical pixels wide and 430 high
- **THEN** it is expanded, because it is 900 or more, and it shows the sidebar

### Requirement: Destination bar and rail

On iOS below 900 logical pixels when not expanded (iPhone, iPad Split View and Slide Over) and on Android below 600, the shell SHALL show a bottom bar whose items are Chats, then Bots, Kanban and Schedules while the server offers each, then More. On Android, Windows and Linux from 600 to 899 logical pixels it SHALL show a navigation rail with the same items.

#### Scenario: Server offers everything

- **WHEN** the server offers Bots, Kanban and Schedules and the width is 390 on iPhone
- **THEN** the bar shows five items: Chats, Bots, Kanban, Schedules and More

#### Scenario: Server offers nothing extra

- **WHEN** the server offers none of Bots, Kanban and Schedules
- **THEN** the bar shows Chats and More

#### Scenario: A destination goes off

- **WHEN** the server stops offering Kanban while it is selected
- **THEN** its item disappears and Chats is selected

### Requirement: Narrow desktop windows keep the drawer

On Windows and Linux below 600 logical pixels the shell SHALL keep today's drawers, with no More row: on Chats, the chat's own drawer with the destinations, the management entries and the account menu; on any other destination, the shell's drawer with the destinations and the account menu. A window whose server offers no destination beyond Chats SHALL keep the chat alone with the chat's own drawer and SHALL NOT gain a shell drawer.

#### Scenario: Narrow desktop window

- **WHEN** a Windows or Linux window is 500 logical pixels wide, the server offers Kanban, and the user opens the drawer on Chats
- **THEN** the drawer lists Chats and Kanban, then the management entries and the account menu, and has no More row
- **AND WHEN** the user opens the drawer on Kanban
- **THEN** it lists Chats and Kanban, then the account menu, and has no More row

### Requirement: Destination items are labelled and large enough

The Apple form SHALL be a tab bar and the Material form a navigation bar or rail with labels always shown. Every item SHALL have a visible label and an accessible name, the selected item SHALL differ by a filled icon and a bold label as well as colour, and every target SHALL be at least 44 points on iOS and 48 logical pixels on Android at any text size.

#### Scenario: Large text

- **WHEN** the system text scale is 2.0 and the width is 320
- **THEN** all five labels are shown whole on one line and every item keeps its target size

### Requirement: The bar yields to the conversation and the keyboard

The bottom bar SHALL be hidden while a conversation is open in the compact messenger navigator, while the on-screen keyboard is shown, and while Kanban is in selection mode, where Kanban's own bulk bar (`kanban_screen.dart:273`) takes the bottom edge. A page pushed over the shell SHALL cover the bar. Returning from a conversation SHALL show the bar with Chats selected.

#### Scenario: Open a conversation

- **WHEN** the user opens a conversation from the Chats list on a phone
- **THEN** the bar is not shown, and Back shows the list with the bar

#### Scenario: Kanban selection mode

- **WHEN** the user long-presses a card on a phone and Kanban enters selection mode
- **THEN** the destination bar is hidden and the bulk bar sits at the bottom edge, and the destination bar returns when selection mode ends

#### Scenario: Keyboard

- **WHEN** the keyboard opens on any page of the shell
- **THEN** the bar does not rise above it

### Requirement: More holds everything else

More SHALL be a page, not a menu. Its first group SHALL be Server. Its next group SHALL hold the management entries the chat sidebar and drawer list today, each under its present gate: Profiles, Skills, Memory (with its waiting count), Messaging, Plugins, MCP servers, Providers, Tools and Helper models. Picking an entry SHALL push its page over the shell.

#### Scenario: Gates are kept

- **WHEN** the server lacks the tools routes and has no Skills support
- **THEN** More shows no Tools, Skills or Memory entry and no error

### Requirement: More lists Server and Settings

The Server row SHALL show the needs-attention mark and its words. After the management entries, More SHALL show one Settings row that pushes a Settings page listing Appearance, Notifications, Dictation, Voice calls, Spotlight, App lock, Connection details and About. Its last group SHALL be Change server, then Sign out, where the account menu offers them.

#### Scenario: Server needs attention

- **WHEN** the server status reports a problem
- **THEN** the More item and the Server row show a mark and the words "needs attention" in their accessible names

### Requirement: Medium Chats shows list and detail

On Android, Windows and Linux at the medium form, Chats SHALL show the thread list beside the open conversation from 720 logical pixels, with the rail at the left, and below 720 the compact list and pushed conversation beside the rail.

#### Scenario: Tablet in portrait

- **WHEN** an Android tablet is 800 logical pixels wide
- **THEN** the rail, the thread list and the conversation are shown together

### Requirement: Medium Chats on iOS has no rail

On iOS at the medium form (an iPhone in landscape, an iPad in Split View) Chats SHALL be the compact list and pushed conversation with the tab bar, and SHALL NOT show a rail.

#### Scenario: iPhone in landscape

- **WHEN** an iPhone is 852 logical pixels wide and 393 high
- **THEN** Chats is the full-page list with the tab bar, a conversation is pushed over it, and no rail is shown

### Requirement: Resizing keeps the conversation

Resizing between forms SHALL keep the selected conversation, the unsent draft, queued prompts and an ongoing reply, and SHALL NOT build a second chat owner.

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

### Requirement: Android Back on a tab root returns to Chats

On Android, the system Back action on the root of a selected destination other than Chats SHALL select Chats. Back on the root of Chats SHALL leave the app, as today. This is the design pass's recommendation and awaits the owner; if the owner keeps today's behaviour, this requirement is replaced by the alternative in `design.md` (decision 11), where Back leaves the app from any tab root.

#### Scenario: Back from Kanban

- **WHEN** Kanban is selected on an Android phone with nothing pushed over it and the user presses Back
- **THEN** Chats is selected and the app stays open

#### Scenario: Back from Chats

- **WHEN** Chats is selected on an Android phone with no conversation open and the user presses Back
- **THEN** the app leaves the foreground

### Requirement: Navigation telemetry holds fixed values

Selecting a destination SHALL record the existing `nav.destination` breadcrumb with the destination name, the form (`compact`, `medium`, `expanded`) and a `via` value. Opening More SHALL record `nav.more.opened`. No breadcrumb, span or log event SHALL carry a title, a profile name, a server address or an id.

#### Scenario: Breadcrumb

- **WHEN** the user taps Schedules in the bar
- **THEN** the breadcrumb holds `destination: schedules`, `form: compact` and `via: bar` and nothing else

### Requirement: The via value says how a destination was reached

`via` SHALL be `bar`, `rail`, `drawer` or `sidebar` for a tap on that control, `link` for a deep link, a notification target or the share entry, and `fallback` when the selected destination went away and Chats was selected instead (that breadcrumb also keeps today's `gone: true`). More is a destination selected through the bar or rail, so `more` SHALL NOT be a `via` value.

#### Scenario: Selected by a link

- **WHEN** a Kanban link selects Kanban on a phone
- **THEN** the breadcrumb holds `destination: kanban`, `form: compact` and `via: link` and nothing else
