## MODIFIED Requirements

### Requirement: Opening the oldest request

A `requests` link SHALL open the chat holding the open approval, question or input request raised first among the loaded chats, by when its reply began, else the stored-snapshot fallback of the `background-refresh` spec. When neither opens a chat it SHALL show the chat list: off the Mac below the expanded form it SHALL select Chats and close the open chat, unless the rail's list is beside it (from 720); a compact Mac window SHALL open its sidebar over the chat; otherwise nothing SHALL change.

#### Scenario: Two chats waiting

- **WHEN** chat A has had an approval open since 10:00 and chat B a question since 10:05, and the user opens `hermes://requests`
- **THEN** chat A is opened

#### Scenario: Nothing waiting

- **WHEN** no loaded chat has an open request, the stored snapshot lists no open request in another profile that the server still reports as waiting, and the user opens `hermes://requests`
- **THEN** the chat list is shown

#### Scenario: Stored request in another profile

- **WHEN** no loaded chat has an open request, the stored snapshot's oldest open request is in profile `work` while the app shows `default`, the server still reports it as waiting, and the user opens `hermes://requests`
- **THEN** the app switches to `work` and opens that chat, and the chat list is not shown
