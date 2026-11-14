# Spec Delta

## ADDED Requirements

### Requirement: Working activity folds into one line

Outside macOS, while the open chat has a Working item that reports a sentence, the app SHALL show one activity line directly below the chat header and nowhere else. The line SHALL show the newest Working sentence on a single line, truncated at its end. Activating the line SHALL open the Activity panel. The line SHALL disappear when no Working item is left, and while the Activity inspector is open.

#### Scenario: Memory recall during a planned turn

- **WHEN** status.update reports a memory recall while a plan with two of five tasks done is known
- **THEN** the line reads the recall sentence with a "2/5" plan counter

#### Scenario: The turn settles

- **WHEN** the reply completes, transient status clears, the plan has no open task left and no process runs
- **THEN** the line disappears

#### Scenario: Opening details from the line

- **WHEN** the user taps the line on a phone
- **THEN** the Activity panel opens as a sheet

#### Scenario: Only a plan is open

- **WHEN** a plan has an open task and no other Working item reports a sentence
- **THEN** the line reads "Working on the plan" with the plan counter

### Requirement: Only Working sentences feed the line

The Bot screen card, Needs-you items and For reference items SHALL NOT feed the line or the macOS toolbar subtitle.

#### Scenario: A usage snapshot arrives

- **WHEN** a session usage snapshot arrives while nothing is working
- **THEN** no line is shown

### Requirement: The line shows only reported counters

The line SHALL show at most two counters at its trailing side, the most recently changed first, when their values are known: the plan's completed and total tasks while a task is open, the number of running processes, and mixture-of-agents references done and total. Counters not shown SHALL stay in the Activity panel. Counters SHALL use only reported values and SHALL be left out when unknown.

#### Scenario: Three counters are known

- **WHEN** a plan, a process and mixture-of-agents progress all report values
- **THEN** the line shows the two that changed last and the panel shows all three

#### Scenario: A counter is unknown

- **WHEN** mixture-of-agents progress reports no total
- **THEN** the line shows no references counter

### Requirement: The line is a touch target of constant height

The line SHALL be at least 44 pt tall on Apple platforms and 48 dp on Material and desktop Material, and its height SHALL NOT change while its sentence changes. It SHALL follow the selected text size with no cap; from a text scale of 1.5 it SHALL use two rows, the sentence over the counters, at a constant height for that scale. It SHALL be one button whose accessible name gives the sentence and the known counters, and sentence changes SHALL NOT be announced.

#### Scenario: The largest text size

- **WHEN** the text size is the largest and the sentence is long
- **THEN** the line shows the sentence on one row and its counters on a second row without cutting a counter

### Requirement: macOS shows Working activity in the toolbar

On macOS, in the main window and in conversation windows, the app SHALL NOT show an activity line. While the chat has a Working item that reports a sentence, the toolbar subtitle SHALL append the newest Working sentence, with a progress indicator, after the profile and model; it SHALL truncate before the profile and model do. When nothing is working the subtitle SHALL return to profile and model only. The quick panel SHALL show no Working status.

#### Scenario: A process runs in a conversation window

- **WHEN** a background process starts in a chat open in its own window
- **THEN** that window's toolbar subtitle shows the running sentence and the main window's subtitle is unchanged

### Requirement: Only the activity line sits above the transcript

Between the chat header and the transcript the app SHALL draw at most the activity line, and a Bot Chat banner, which is not activity. Working details SHALL be shown in the Activity panel (Now and Plan), Needs-you items in the card docked above the composer, and For reference items in the Activity panel.

#### Scenario: Every tier is busy

- **WHEN** a plan, a process, a usage snapshot and a pending billing verification exist together
- **THEN** only the activity line sits between the header and the transcript, the billing card is above the composer, and the usage snapshot is in the Activity panel

### Requirement: The Activity panel lists process output under Now

The Activity panel SHALL list background process output and its omission note under Now with the other Working items, not under This session.

#### Scenario: A process runs

- **WHEN** the panel is opened while a background process runs
- **THEN** its output card is under Now
