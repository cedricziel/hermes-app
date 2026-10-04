## ADDED Requirements

### Requirement: Thread sections on macOS

On macOS the sidebar SHALL list the threads under section headers: Pinned (every pinned thread), Today, Previous 7 days, Previous 30 days and Older (by the thread's last activity, by calendar day). Empty sections SHALL be left out, and each section SHALL keep the sidebar's order. A click on a header SHALL fold its section away or open it again, and which sections are folded SHALL be remembered across launches. Thread rows SHALL be 28 pt high; under the pointer a row SHALL show an Archive button (for a thread the dashboard holds) and a More button. More and a secondary click SHALL open the thread's menu: "Open in New Window" (only where the app can open one), "Rename…", "Pin" or "Unpin", "Copy Transcript", "Archive" and "Delete…", in that order, with the shortcuts ⌥⌘O, ⇧⌘P and ⌘⌫ shown beside their items. A thread the dashboard does not hold SHALL offer only "Copy Transcript". Other platforms SHALL keep the flat list.

#### Scenario: Sections by recency

- **WHEN** the sidebar holds a pinned thread, threads active today and a thread active three months ago
- **THEN** they appear under Pinned, Today and Older, and no Previous 7 days or Previous 30 days header is shown

#### Scenario: A folded section stays folded

- **WHEN** the user clicks the Today header and relaunches the app
- **THEN** the threads of today are still hidden until the header is clicked again

#### Scenario: Archive from the row

- **WHEN** the user points at a row and clicks its Archive button
- **THEN** the thread is archived as from its menu

#### Scenario: Paging still works

- **WHEN** the user scrolls to the end of a sectioned list with more pages
- **THEN** the next page is loaded and its threads join their sections

### Requirement: Copying a transcript

The thread menu SHALL offer to copy a thread's transcript to the clipboard as Markdown: a `## You` or `## Hermes` heading above each turn that has text, turns with only attachments or tool calls left out. For a thread whose messages are not loaded, the system SHALL read its whole history from the dashboard first; for a loaded thread it SHALL use the loaded messages and read only the older pages not loaded yet. The user SHALL be told "Transcript copied", or "Could not copy the transcript" when the history cannot be read.

#### Scenario: A thread that is not open

- **WHEN** the user copies the transcript of a thread they have not opened
- **THEN** its messages are read from the dashboard and copied as Markdown

#### Scenario: The open thread

- **WHEN** the user copies the transcript of the open thread, whose messages are all loaded
- **THEN** nothing is read from the dashboard again
