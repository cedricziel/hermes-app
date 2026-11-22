## MODIFIED Requirements

### Requirement: Opening the oldest request

A `requests` link SHALL open the chat holding the open request (approval, question or input) raised first among the loaded chats, by when its reply began. With none open it SHALL show the chat list without opening a chat: with a bar or rail it SHALL select Chats and close the open chat, unless the list is beside it (the rail's Chats from 720), where the chat stays; under 600 on Windows or Linux it SHALL close the chat and open the chat drawer; with the sidebar it SHALL change nothing.

#### Scenario: Two chats waiting

- **WHEN** chat A has had an approval open since 10:00 and chat B a question since 10:05, and the user opens `hermes://requests`
- **THEN** chat A is opened

#### Scenario: Nothing waiting

- **WHEN** no loaded chat has an open request and the user opens `hermes://requests`
- **THEN** the chat list is shown
