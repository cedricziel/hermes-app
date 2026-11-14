# Spec Delta

## ADDED Requirements

### Requirement: Working activity folds into one line

Outside macOS and outside the quick panel, while the open chat has a Working item that reports a sentence, the app SHALL show one activity line directly below the chat header (above a Bot Chat banner) and nowhere else. The line SHALL show the newest Working sentence, truncated at its end (on one line; from a text scale of 2 it MAY use two lines). Activating the line SHALL open the Activity panel. The line SHALL disappear when no Working item is left, and while the Activity inspector is docked beside the chat or drawn over it; on a phone the sheet covers the chat and the line stays beneath it.

#### Scenario: Memory recall during a planned turn

- **WHEN** status.update reports a memory recall while a plan with two of five tasks done is known
- **THEN** the line reads the recall sentence with a "2/5" plan counter

#### Scenario: The turn settles

- **WHEN** the reply completes, is interrupted, fails or is stopped
- **THEN** the line disappears, even if a plan task is still open or a process card is still open

#### Scenario: Opening details from the line

- **WHEN** the user taps the line on a phone
- **THEN** the Activity panel opens as a sheet

#### Scenario: Only a plan is open

- **WHEN** a reply is in flight, a plan has an open task and no other Working item reports a sentence
- **THEN** the line reads "Working on the plan" with the plan counter

### Requirement: Working is scoped to the turn

The line and the macOS toolbar subtitle SHALL count as working only while a reply is in flight, a session resume is loading, or a mixture-of-agents card is live during a reply. Status, lifecycle, memory-recall, goal, loop, heartbeat and plan sentences, the plan counter and process cards SHALL count only while a reply is in flight. A status that arrived before the previous reply ended SHALL NOT return with a later reply, while one that arrives ahead of a server-started reply SHALL count. A loading resume SHALL stop counting when the connection drops or the session is reclaimed. Because the backend sends no process-exit signal, a process that is still running after the reply ended SHALL NOT be reported by the line. Goal, loop and heartbeat sentences SHALL come from the control state while its section is active, not from their status text.

#### Scenario: A plan is left open

- **WHEN** a reply is interrupted with a plan task still open
- **THEN** the line is gone and the plan stays in the Activity panel

#### Scenario: A status of an earlier turn

- **WHEN** a new reply starts after a reply that ended with a status sentence
- **THEN** the earlier status is not the line's sentence

#### Scenario: A resume is cut off

- **WHEN** the connection drops while a session resume is loading
- **THEN** the line no longer says the chat is being restored

### Requirement: Only Working sentences feed the line

The Bot screen card, Needs-you items and For reference items SHALL NOT feed the line or the macOS toolbar subtitle.

#### Scenario: A usage snapshot arrives

- **WHEN** a session usage snapshot arrives while nothing is working
- **THEN** no line is shown

### Requirement: The line shows only reported counters

The line SHALL show at most two counters at its trailing side, the most recently changed first, when their values are known: the plan's completed and total tasks while a task is open and a reply is in flight, the number of running processes, and mixture-of-agents references done and total. A counter that repeats the sentence SHALL be left out. Counters not shown SHALL stay in the Activity panel. Counters SHALL use only reported values and SHALL be left out when unknown. When the sentence does not fit beside the counters on one row, the counters SHALL become compact (icon and number only, their words kept in the accessible name), and if it still does not fit, one counter SHALL be shown, the one that changed last; a counter SHALL NOT be cut or overflow.

#### Scenario: Three counters are known

- **WHEN** a plan, a process and mixture-of-agents progress all report values
- **THEN** the line shows the two that changed last and the panel shows all three

#### Scenario: A long sentence

- **WHEN** a 90-character sentence and two counters do not fit on one row
- **THEN** the counters are compact, and if the sentence still does not fit one counter remains

#### Scenario: A counter is unknown

- **WHEN** mixture-of-agents progress reports no total
- **THEN** the line shows no references counter

### Requirement: The line is a touch target of constant height

The line SHALL be at least 44 pt tall on Apple platforms and 48 dp on Material and desktop Material, and its height SHALL NOT change while its sentence changes. It SHALL follow the selected text size with no cap; from a text scale of 1.5 it SHALL use two rows, the sentence over the counters, at a constant height for that scale (also when no counter is known), and from a text scale of 2 the sentence MAY use two lines. It SHALL be one button whose accessible name gives the sentence and the known counters, and sentence changes SHALL NOT be announced.

#### Scenario: The largest text size

- **WHEN** the text size is the largest and the sentence is long
- **THEN** the line shows the sentence on one row and its counters on a second row without cutting a counter

### Requirement: macOS shows Working activity in the toolbar

On macOS, in the main window and in conversation windows, the app SHALL NOT show an activity line. While the chat has a Working item that reports a sentence, the toolbar subtitle SHALL append the newest Working sentence, with a progress indicator, after the profile and model; it SHALL truncate before the profile and model do, and when too little room is left for a readable status the progress indicator, separator and status SHALL all be left out. When nothing is working the subtitle SHALL return to profile and model only. The quick panel SHALL show no Working status.

#### Scenario: A process runs in a conversation window

- **WHEN** a background process starts in a chat open in its own window
- **THEN** that window's toolbar subtitle shows the running sentence and the main window's subtitle is unchanged

### Requirement: Only the activity line sits above the transcript

Between the chat header and the transcript the app SHALL draw at most the activity line, and a Bot Chat banner, which is not activity. Working details SHALL be shown in the Activity panel (Now and Plan), Needs-you items in the card docked above the composer, and For reference items in the Activity panel.

#### Scenario: Every tier is busy

- **WHEN** a plan, a process, a usage snapshot and a pending billing verification exist together
- **THEN** only the activity line sits between the header and the transcript, the billing card is above the composer, and the usage snapshot is in the Activity panel

### Requirement: The Activity panel lists process output under Now

The Activity panel SHALL list open background process cards and the omission note under Now with the other Working items. Closed process cards SHALL be listed under This session. The session status SHALL be listed under Now while it holds control, a resume or a wait of the reply running now, and under This session otherwise.

#### Scenario: A process runs

- **WHEN** the panel is opened while a background process card is open
- **THEN** its output card is under Now

#### Scenario: A process card closes

- **WHEN** the backend closes a process card
- **THEN** the card is listed under This session
