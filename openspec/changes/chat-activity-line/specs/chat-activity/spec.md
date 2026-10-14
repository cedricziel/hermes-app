# Spec Delta

## ADDED Requirements

### Requirement: Working activity folds into one line

Outside macOS, while the open chat has at least one Working item, the app SHALL show one activity line directly below the chat header and nowhere else. The line SHALL show the newest Working sentence on a single line, truncated at its end, and counters when known: the plan's completed and total tasks, the number of running processes, and mixture-of-agents references done and total. Counters SHALL use only reported values and SHALL be left out when unknown. Activating the line SHALL open the Activity panel. The line SHALL disappear when no Working item is left, and its height SHALL NOT change with its content.

#### Scenario: Memory recall during a planned turn

- **WHEN** status.update reports a memory recall while a plan with two of five tasks done is known
- **THEN** the line reads the recall sentence with a "2/5" plan counter

#### Scenario: The turn settles

- **WHEN** the reply completes, transient status clears, the plan has no open task left and no process runs
- **THEN** the line disappears

#### Scenario: Opening details from the line

- **WHEN** the user taps the line on a phone
- **THEN** the Activity panel opens as a sheet

### Requirement: macOS shows Working activity in the toolbar

On macOS, in the main window and in conversation windows, the app SHALL NOT show an activity line. While the chat has a Working item, the toolbar subtitle SHALL append the newest Working sentence, with a progress indicator, after the profile and model; it SHALL truncate before the profile and model do. When nothing is working the subtitle SHALL return to profile and model only. The quick panel SHALL show no Working status.

#### Scenario: A process runs in a conversation window

- **WHEN** a background process starts in a chat open in its own window
- **THEN** that window's toolbar subtitle shows the running sentence and the main window's subtitle is unchanged

### Requirement: Nothing stacks above the transcript

The app SHALL NOT draw activity cards between the chat header and the transcript. Working details SHALL be shown in the Activity panel (Now and Plan), Needs-you items in the docked card above the composer, and For reference items in the Activity panel. A Bot Chat banner is not activity and is unaffected.

#### Scenario: Every tier is busy

- **WHEN** a plan, a process, a usage snapshot and a pending billing verification exist together
- **THEN** only the activity line sits between the header and the transcript, the billing card is above the composer, and the rest is in the Activity panel
