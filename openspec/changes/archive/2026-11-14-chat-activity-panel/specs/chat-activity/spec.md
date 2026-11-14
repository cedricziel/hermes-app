# Spec Delta

## ADDED Requirements

### Requirement: Activity panel

The app SHALL offer an Activity panel for the open chat with three sections in this order: **Now** (Working items except the plan), **Plan** (the todo plan: its completed count and every supported task with its status), and **This session** (For reference items, plus the Verify billing access action while that action is offered). A section with no content SHALL be left out. When every section is empty the panel SHALL say that there is no activity for this chat. The panel SHALL follow the open chat: switching chats SHALL show the new chat's activity and never another chat's. Panel content SHALL follow the ownership, App Lock and retirement rules of each activity's own capability.

#### Scenario: A chat with a plan and usage

- **WHEN** the user opens the Activity panel on a chat with a plan of five tasks, two done, and a usage snapshot
- **THEN** the panel shows Plan · 2 of 5 with the tasks, and This session with the token total
- **AND** no Now section is drawn

#### Scenario: The user switches chats with the panel open

- **WHEN** the inspector is open and the user selects another chat
- **THEN** the inspector stays open and shows only the newly selected chat's activity

### Requirement: Activity panel placement per form factor

The Activity panel SHALL open as a bottom sheet in a phone layout (an Apple detent sheet that opens at medium height and can be dragged to full height on iOS; a Material modal bottom sheet on Android) and as an inspector on the right side of the chat in a window at least 760 logical pixels wide (a full-screen iPad, macOS, Windows, Linux). Below 760 logical pixels in a desktop or iPad layout the inspector SHALL be drawn over the chat instead of beside it. The inspector SHALL keep the chat column usable: beside the chat it SHALL NOT narrow the chat column below its readable minimum, and over the chat it SHALL close with Escape or a tap outside.

#### Scenario: Opening on an iPhone

- **WHEN** the user opens the Activity panel on an iPhone
- **THEN** a sheet rises at medium height above the chat

#### Scenario: A narrow Mac window

- **WHEN** the inspector is open and the Mac window is resized below 760 points
- **THEN** the inspector is drawn over the chat and Escape closes it

### Requirement: Activity button

The chat header SHALL show an Activity button whenever a chat is open, in every layout; on macOS it SHALL be a toolbar button. It SHALL open the panel, and in an inspector layout close it again, showing whether the inspector is open. On macOS, View > Inspector (⌥⌘I) SHALL toggle the inspector of the key window's chat, in the main window and in conversation windows. The quick panel SHALL NOT offer the Activity panel.

#### Scenario: Toggling from the menu bar

- **WHEN** a conversation window is key and the user chooses View > Inspector
- **THEN** that window's Activity inspector opens and the main window's is unchanged

#### Scenario: The quick panel

- **WHEN** the quick panel shows a chat
- **THEN** it offers no Activity button and no inspector

### Requirement: Reference activity lives only in the Activity panel

For reference items SHALL be shown only in the Activity panel's This session section and SHALL NOT take space between the chat header and the transcript. Settled and read-only connector operations, connection-wide connector activity, session usage, side results, session notices and keyed notifications, the session acknowledgement and the billing grant result SHALL appear there. Keyed notices SHALL keep their replacement, withdrawal and expiry rules inside the panel.

#### Scenario: A side answer arrives during a turn

- **WHEN** btw.complete arrives while the main reply streams
- **THEN** nothing is added above the transcript and the answer is listed under This session

#### Scenario: A keyed notice expires while the panel is closed

- **WHEN** a notice with a positive ttl expires before the user opens the panel
- **THEN** the panel does not list it
