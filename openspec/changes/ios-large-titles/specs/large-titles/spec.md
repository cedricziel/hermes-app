## ADDED Requirements

### Requirement: List and overview pages show a large title on iPhone

On a compact iOS layout, a page that is a list or an overview with one vertical scroll view and no tabs SHALL show its title at 34 points as the first element of its content, left aligned, with its subtitle under it. The navigation bar above SHALL be 44 points tall and show no title while the large title is on screen. The pages are listed in the design of this change and SHALL be switched on one by one.

#### Scenario: Server overview at rest

- **WHEN** the Server page opens on an iPhone
- **THEN** "Server" is shown large at the top of the list and the bar shows its back or menu button and its actions but no title

#### Scenario: Long title at large text

- **WHEN** the system text scale is 2.0 and a page's title is longer than one line
- **THEN** the large title wraps and is shown whole, and nothing is cut with an ellipsis

### Requirement: The large title collapses into the bar

While the content scrolls up, the large title SHALL leave with it and the bar's own title SHALL fade in over the last 24 points of the header's travel. When Reduce Motion is on, the bar title SHALL appear without a fade. Scrolling back to the top SHALL restore the large title. Content too short to scroll SHALL keep the large title.

#### Scenario: Scroll past the title

- **WHEN** the user scrolls the list by the height of the large title
- **THEN** the bar shows the title at 17 points and the large title is out of view

#### Scenario: Short page

- **WHEN** a page's content fits without scrolling
- **THEN** the large title stays and the bar shows no title

### Requirement: A page reads as one heading

The accessibility tree SHALL contain one heading for the page title at every scroll position. While the large title is on screen the bar's title SHALL be excluded from the tree, and once the large title has left the screen the large one SHALL be.

#### Scenario: Screen reader at rest

- **WHEN** a screen reader reads a page with a large title at rest
- **THEN** it announces the title once, as a heading

### Requirement: Pages that keep a small title

The following SHALL keep the 44 point bar and its centred 17 point title: pages with tabs in the bar, the open conversation, the Kanban board, Files and the file preview, detail pages, forms with Cancel or Save, the Server sub-pages, any page shown in a detail pane, any page at regular width, and every page on Android, macOS, Windows and Linux.

#### Scenario: Form

- **WHEN** a form opens with Cancel and Save in its bar
- **THEN** its title is the bar's centred title and no large title is shown

#### Scenario: iPad regular width

- **WHEN** a page that has a large title on iPhone opens on a full-screen iPad
- **THEN** it looks as it does today

### Requirement: The bar keeps its controls

Turning a large title on SHALL NOT change the bar's back button, menu button, actions, form actions or 44 point targets.

#### Scenario: Actions stay

- **WHEN** a page with a large title has two bar actions
- **THEN** both are in the bar at 44 points at every scroll position and text size

### Requirement: Search sits under the large title

On a page with a large title and a search field, the search field SHALL sit in the content directly under the large title and its subtitle, not in the bar. While the field is empty and unfocused it SHALL scroll away with the large title. While it is focused or holds a query it SHALL stay pinned under the bar. Collapsing or restoring the large title SHALL keep the query, the focus and the keyboard.

#### Scenario: Search at rest

- **WHEN** the Chats list opens on an iPhone
- **THEN** the search field is shown under the large "Chats" title and its subtitle, and the bar holds no search field

#### Scenario: Empty search scrolls away

- **WHEN** the user scrolls the list up with the search field empty and unfocused
- **THEN** the field leaves the screen with the large title

#### Scenario: Focused or holding a query

- **WHEN** the search field is focused or holds a query and the user scrolls the results up
- **THEN** the field stays pinned under the bar, and the query and the keyboard are kept

### Requirement: Titles carry no user content in telemetry

Showing, collapsing or hiding a large title SHALL NOT record a breadcrumb, span or log event.

#### Scenario: Scroll

- **WHEN** the user scrolls a page with a large title
- **THEN** no telemetry is recorded for the title
