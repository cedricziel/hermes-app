## MODIFIED Requirements

### Requirement: Opening the oldest request

A `requests` link SHALL open the chat holding the open approval, question or input request raised first among the loaded chats, judged by when its reply began. With no open request it SHALL show the chat list without opening a chat: with a destination bar or rail it SHALL select Chats and close the open chat; in a Windows or Linux window under 600 logical pixels it SHALL close the open chat and open the chat drawer; where the list is always on screen it SHALL leave things as they are.

#### Scenario: Two chats waiting

- **WHEN** chat A has had an approval open since 10:00 and chat B a question since 10:05, and the user opens `hermes://requests`
- **THEN** chat A is opened

#### Scenario: Nothing waiting

- **WHEN** no loaded chat has an open request and the user opens `hermes://requests`
- **THEN** the chat list is shown
