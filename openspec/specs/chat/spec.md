# Chat Specification

## Purpose

The chat screen is the app's main destination once the user is connected and signed in. It lists the conversations ("threads") the Hermes dashboard holds, shows their messages, sends new messages to the agent over the dashboard's `/api/ws` JSON-RPC socket, streams the reply, and lets the user answer the agent when it stops to ask for approval or clarification. This spec describes the behaviour of the code as it is today.
## Requirements
### Requirement: Thread list loading

The system SHALL load the first page of the thread list from the dashboard when the chat screen opens, showing a progress indicator while it loads, and SHALL list threads with the most recently active first. Archived sessions SHALL be left out of the list.

#### Scenario: Threads are listed

- **WHEN** the dashboard returns sessions for the chat screen
- **THEN** each session with a non-empty string id appears as a thread in the sidebar with its title and a relative time of its last activity (or its start time when it has no recorded activity)

#### Scenario: Session rows that do not fit are skipped

- **WHEN** a session row has no string id, or an id that is empty
- **THEN** that row is left out and the other rows are still listed

#### Scenario: Title fallbacks

- **WHEN** a session has no non-blank title
- **THEN** its preview text is used as the title, and when there is no preview either the title is "Untitled chat"

#### Scenario: Loading fails

- **WHEN** the session list request fails
- **THEN** the screen shows "Could not load your chats" with a Retry button, and Retry loads the list again

#### Scenario: Active profile lookup fails

- **WHEN** the request for the active profile fails for any reason other than the server not having the route (404)
- **THEN** no session list is requested, the screen shows "Could not load your chats" with a Retry button, and no message can be sent until Retry has learned the profile, so nothing is listed or sent unscoped

#### Scenario: Account without sessions

- **WHEN** the dashboard returns no sessions
- **THEN** the chat shows the welcome view instead of a transcript

### Requirement: Thread list paging

The system SHALL request the thread list in pages of 50 and SHALL request the next page automatically when the end of the list scrolls into view. A "Show more" button SHALL be available at the end of the list for when the automatic request failed.

#### Scenario: Next page on scroll

- **WHEN** the user scrolls to the end of a list that has more sessions
- **THEN** the next page is requested once, at the offset following the previous page, and its threads are appended

#### Scenario: More pages are known from the total

- **WHEN** the dashboard reports a `total` in the list response
- **THEN** more pages are expected while the next offset is below that total

#### Scenario: More pages are guessed without a total

- **WHEN** the list response carries no `total`
- **THEN** more pages are expected while the page returned as many rows as were requested

#### Scenario: Pinned sessions repeat across pages

- **WHEN** a later page contains a thread that is already in the list (the dashboard appends pinned sessions to every page)
- **THEN** the duplicate is dropped and the list keeps one row per thread id

#### Scenario: Removal shifts the paging offset

- **WHEN** a thread is archived or deleted and the offset of the next page is above zero
- **THEN** the offset of the next page moves back by one, so the next page does not skip a session

#### Scenario: A page fails to load

- **WHEN** requesting a further page fails
- **THEN** the user is told "Could not load more chats" and the "Show more" button remains to retry

### Requirement: Thread ordering

The system SHALL order the sidebar with local drafts first, then pinned threads, then all others; within pinned and other server threads the most recently active SHALL come first.

#### Scenario: Pinned threads stay on top

- **WHEN** the dashboard lists pinned and unpinned sessions
- **THEN** the pinned threads appear above the unpinned ones, each with a pin marker

#### Scenario: A draft stays above server threads

- **WHEN** the user starts a new chat that the dashboard does not yet hold
- **THEN** it appears at the top of the list, above pinned threads

### Requirement: No thread search

The chat screen SHALL NOT offer searching or filtering the thread list. Every thread is reached by scrolling the paged list.

#### Scenario: No search control

- **WHEN** the sidebar is shown
- **THEN** it offers a "New chat" action, the thread list, the Profiles and Bots entries (when their repositories are available) and the account menu, and no search field

### Requirement: Opening a thread and loading messages

The system SHALL select a thread when the user taps it and SHALL load that thread's messages from the dashboard the first time it is opened, not before. When the list has loaded, no thread SHALL be selected and the welcome view for a new chat SHALL be shown, unless a notification that launched the app names a thread, which SHALL be opened.

#### Scenario: Welcome view on load

- **WHEN** the thread list has loaded
- **THEN** no thread is selected, the welcome view is shown, and no thread's messages are fetched

#### Scenario: Another thread is opened

- **WHEN** the user opens a thread whose messages were not loaded yet
- **THEN** its messages are fetched and shown

#### Scenario: Reopening does not refetch

- **WHEN** the user opens a thread whose messages were already loaded, or that was created in this session
- **THEN** its messages are shown from memory without another request

#### Scenario: Loading messages fails

- **WHEN** fetching the messages of a thread fails
- **THEN** the user is told "Could not load this chat", and opening the thread again tries the fetch again

#### Scenario: Only user and assistant turns are shown

- **WHEN** a session's messages contain rows with a role other than `user` or `assistant` (system rows, tool result rows)
- **THEN** those rows are not shown

#### Scenario: Assistant turns keep their tool calls

- **WHEN** an assistant row carries OpenAI-style `tool_calls`
- **THEN** each call with a function name appears as a completed tool call card on that message, with the call's arguments string as its summary, and a null content is treated as empty text

#### Scenario: Timestamps

- **WHEN** message or session rows carry timestamps
- **THEN** they are read as epoch seconds, and a missing timestamp is read as the epoch

### Requirement: Rendering of messages

The system SHALL render a message as tool call cards first, then agent input request cards, then the text, then a thinking indicator, and SHALL render message text as markdown.

#### Scenario: Thinking indicator

- **WHEN** an assistant reply is pending with no text yet and no input request is waiting
- **THEN** a thinking indicator (three pulsing dots) is shown in place of text

#### Scenario: No indicator while the agent waits for the user

- **WHEN** a reply is still thinking and one of its input requests is pending
- **THEN** the thinking indicator is hidden

#### Scenario: Failed reply

- **WHEN** a reply ended in error and has text
- **THEN** its text is drawn in the error colour

#### Scenario: Empty thread

- **WHEN** the open thread has no messages, or no thread is selected
- **THEN** the welcome view shows "Where should we begin?" (with the user's display name appended when known) and four starter prompts, and tapping a prompt sends it as a message

#### Scenario: Responsive layout

- **WHEN** the available width is at least 900 logical pixels
- **THEN** the thread rail is permanently shown beside the transcript, with the thread title above it
- **AND WHEN** the width is smaller
- **THEN** the rail opens as a drawer and the thread title is shown in the app bar

### Requirement: Starting and continuing threads

The system SHALL let the user start a local draft thread with "New chat" and SHALL bind it to the dashboard when the first message is sent. Sending to a thread the dashboard already holds SHALL continue that thread's session.

#### Scenario: New chat

- **WHEN** the user taps "New chat"
- **THEN** a draft thread titled "New chat" appears at the top of the list and is selected, and no request is made

#### Scenario: Sending without any thread selected

- **WHEN** the user sends a message while no thread is selected
- **THEN** a thread is created locally, titled after the message, and selected

#### Scenario: Draft is bound to the dashboard

- **WHEN** the transport reports the id the dashboard stored a new thread under
- **THEN** the draft takes that id, keeps its transcript, stays a single row in the list, and its next message continues that session

#### Scenario: Server thread continues

- **WHEN** the user sends a message in a thread the dashboard holds
- **THEN** the message is sent under that thread's id, and it appears after the messages already loaded

### Requirement: Sending a message

The system SHALL append the user's message and a thinking placeholder for the assistant reply to the transcript at once when the user sends, and SHALL clear the composer. Blank text with no attachments SHALL NOT be sent. The system SHALL NOT send on a thread that has a pending reply, meaning a reply that is thinking or streaming, including one that waits for the user to answer an approval or clarify request. It SHALL tell the user why with the message "Hermes is still replying. Wait for it to finish, or answer its request." and SHALL keep the composer text and attachments. Other threads SHALL NOT be affected.

#### Scenario: Send shows prompt and placeholder

- **WHEN** the user sends "hello"
- **THEN** the transcript shows "hello" and a thinking placeholder, and the composer is emptied

#### Scenario: Whitespace-only message

- **WHEN** the composer holds only whitespace and there are no attachments
- **THEN** nothing is sent

#### Scenario: Send button state

- **WHEN** the composer is empty and there are no attachments
- **THEN** the send button is disabled
- **AND WHEN** there are attachments, even with no text
- **THEN** it is enabled

#### Scenario: Overlapping sends

- **WHEN** the user sends in several threads while an earlier reply in another thread is still streaming
- **THEN** every reply streams into its own place beside its own prompt

#### Scenario: Blocked while the reply streams

- **WHEN** the user sends again in a thread whose reply is still streaming
- **THEN** nothing is sent and the user is told "Hermes is still replying. Wait for it to finish, or answer its request."
- **AND** the composer keeps its text

#### Scenario: Blocked while a request is pending

- **WHEN** the reply waits on an approval or clarify request that is not answered yet
- **AND WHEN** the user sends again in that thread
- **THEN** nothing is sent and the user is told "Hermes is still replying. Wait for it to finish, or answer its request."

#### Scenario: Allowed after completion

- **WHEN** the reply in a thread has completed
- **AND WHEN** the user sends again in that thread
- **THEN** the message is sent

#### Scenario: Allowed after a broken stream

- **WHEN** the reply stream of a thread broke and the reply is marked failed
- **AND WHEN** the user sends again in that thread
- **THEN** the message is sent

#### Scenario: Other thread unaffected

- **WHEN** a thread has a pending reply
- **AND WHEN** the user switches to another thread and sends
- **THEN** the message is sent under that other thread

### Requirement: Streaming the reply

The system SHALL stream the assistant reply into the transcript as it arrives and SHALL keep streaming into the reply's own thread when the user switches to another thread.

#### Scenario: Deltas stream in

- **WHEN** reply text chunks arrive
- **THEN** they are appended to the reply, which moves from thinking to streaming

#### Scenario: Completion

- **WHEN** the reply completes with a final text
- **THEN** the reply shows that text in full, replacing what had streamed, and is finished
- **AND WHEN** the final text is empty
- **THEN** the text that had streamed is kept

#### Scenario: Reply completes while the user looks elsewhere

- **WHEN** the user switches to another thread before the reply finishes
- **THEN** the reply lands in its own thread, and opening that thread shows the reply so far

#### Scenario: Thread title from the dashboard

- **WHEN** the dashboard names or renames the thread while the reply streams
- **THEN** the new title replaces the thread's title in the sidebar and in the top bar

### Requirement: Local thread titling

The system SHALL title a thread that has no messages after its first message, cut to 48 characters followed by an ellipsis when longer, until the dashboard supplies a title.

#### Scenario: Long first message

- **WHEN** the first message of a thread is longer than 48 characters
- **THEN** the thread is titled with its first 48 characters followed by an ellipsis

#### Scenario: Short first message

- **WHEN** the first message is 48 characters or shorter
- **THEN** the thread is titled with the message

### Requirement: Tool call cards

The system SHALL show each tool the agent runs as a card in the reply with the tool name, a summary, and a status of running, completed or failed.

#### Scenario: Tool runs and completes

- **WHEN** a tool starts
- **THEN** a running card with the tool's name and context summary appears
- **AND WHEN** that tool finishes
- **THEN** the card shows completed

#### Scenario: Tool fails

- **WHEN** a tool finishes and its result carries a non-empty `error`
- **THEN** its card shows failed

#### Scenario: Matching by name

- **WHEN** a tool finishes
- **THEN** the first still-running card with that name is settled and other cards are untouched
- **AND WHEN** no running card has that name
- **THEN** nothing changes

#### Scenario: Tools that never report back

- **WHEN** the reply completes, or the stream breaks, while a tool is still running
- **THEN** that card is settled, as completed after a successful reply and as failed after a failed reply or a broken stream

### Requirement: Reply error handling

The system SHALL end a reply that failed or whose stream broke as an error, and SHALL let the user send again.

#### Scenario: Failed completion

- **WHEN** the gateway completes a turn with status `error`
- **THEN** the reply is marked as an error and shows the message text the gateway supplied

#### Scenario: Failed completion without text

- **WHEN** the gateway completes a turn with status `error` and supplies no message text
- **THEN** the reply is marked as an error, keeps any text that had already streamed, and otherwise shows "Something went wrong. Try sending it again."

#### Scenario: Stream drops or ends without completion

- **WHEN** the socket drops, the gateway answers a request with an error, or the stream ends before a completion
- **THEN** the reply is marked as an error, keeps any text that had already streamed, and otherwise shows "Something went wrong. Try sending it again."
- **AND** the user is notified that the reply failed when a notification is warranted, as for a failed completion (see the notifications spec)

#### Scenario: The selected profile no longer exists

- **WHEN** the gateway answers `session.create` or `session.resume` with the JSON-RPC error 4064 because the profile the chat is showing was deleted or never existed
- **THEN** the reply is marked as an error and shows "That profile is no longer available. Pick another one." instead of the generic message
- **AND** the request is not retried, the user's message stays in the thread, and the text the gateway put in the error is never shown
- **AND** the user is notified that the reply failed when a notification is warranted, as for any other failed reply

#### Scenario: Sending again after a failure

- **WHEN** a reply failed
- **THEN** the user can send another message in the thread

### Requirement: Gateway session handling

The system SHALL send a message by starting a new gateway session (`session.create`) when the thread is not yet known to the dashboard, or resuming the thread's stored session (`session.resume` with its id) otherwise, then submitting the text to the resulting runtime session with `prompt.submit`; the reply SHALL arrive as events of that runtime session. Right after opening a connection and before any session call, the system SHALL tell the gateway that it answers server-to-client requests (`client.capabilities` with `server_requests: true`); a gateway that does not know the method answers with an error, which the system SHALL ignore. When the chat is showing a Hermes profile, the system SHALL pass that profile's name as the `profile` param of `session.create` and `session.resume`, so the session is created in and resumed from that profile rather than the dashboard's own.

#### Scenario: New thread

- **WHEN** a message is sent without a thread id
- **THEN** `session.create` is requested, the stored session id it returns is reported as the thread's id, and `prompt.submit` is requested with the runtime session id and the text

#### Scenario: Existing thread

- **WHEN** a message is sent with a thread id
- **THEN** `session.resume` is requested with `session_id` set to that id and `prompt.submit` is requested on the runtime session id it returns

#### Scenario: New thread in a profile

- **WHEN** a message is sent without a thread id while the chat shows the profile "work"
- **THEN** `session.create` is requested with `profile` set to "work"

#### Scenario: Existing thread in a profile

- **WHEN** a message is sent with a thread id while the chat shows the profile "work"
- **THEN** `session.resume` is requested with `session_id` set to that id and `profile` set to "work"

#### Scenario: Profile changes between sends

- **WHEN** the user switches the chat to another profile and sends a message
- **THEN** the session is created or resumed under the newly shown profile, not the previous one

#### Scenario: No profile known

- **WHEN** the server has no active-profile route (404), so it reports none
- **THEN** `session.create` and `session.resume` are requested without a `profile` param, and the dashboard uses its own profile

#### Scenario: Events of other sessions

- **WHEN** an event arrives for another runtime session, or of a type the app does not model
- **THEN** it is ignored

#### Scenario: Prompt is rejected

- **WHEN** `prompt.submit` is answered with a JSON-RPC error
- **THEN** the send fails instead of hanging, and the reply is marked as an error

#### Scenario: Connection is opened lazily and reused

- **WHEN** no message has been sent yet
- **THEN** no socket is opened
- **AND WHEN** several messages are sent
- **THEN** one connection is reused, and a new one is opened when the previous one has closed or when an earlier connection attempt failed

#### Scenario: Credentials for the socket

- **WHEN** the dashboard requires sign-in
- **THEN** each connection first requests a fresh single-use ticket and joins with it as the `ticket` query parameter
- **AND WHEN** the dashboard does not require sign-in
- **THEN** the connection joins with the session token embedded in the dashboard's start page as the `token` query parameter, and fails if the page carries none

#### Scenario: Socket URL

- **WHEN** the socket URL is derived from the server address
- **THEN** it uses `ws` for `http` and `wss` for `https`, keeps any path prefix the dashboard is served under, and appends `/api/ws`

#### Scenario: Capability is announced once per connection

- **WHEN** a connection is opened
- **THEN** `client.capabilities` is requested with `server_requests` set to true before `session.create` or `session.resume`, and not again on that connection

#### Scenario: Gateway does not know the capability call

- **WHEN** `client.capabilities` is answered with a JSON-RPC error
- **THEN** the connection is used as usual and the send does not fail

#### Scenario: Requests of other sessions

- **WHEN** a server-to-client request arrives for another runtime session
- **THEN** it is not shown in this reply and it is not answered by it

### Requirement: Thread actions

The system SHALL offer rename, pin or unpin, archive, and delete on threads the dashboard holds, from a menu on each row, a long press and a secondary click. Local drafts and mock threads SHALL have no actions until the dashboard stores them. Only one action per thread SHALL run at a time, and every action SHALL be sent for the profile the thread was listed under.

#### Scenario: Rename

- **WHEN** the user chooses Rename
- **THEN** a dialog offers the current title to edit, and Save sends the trimmed new title
- **AND** the new title is shown at once and then replaced by the title the dashboard stored

#### Scenario: Rename not saved

- **WHEN** the user cancels, leaves the title empty, or leaves it unchanged
- **THEN** no request is sent

#### Scenario: Rename fails

- **WHEN** the dashboard refuses the rename
- **THEN** the old title comes back and the user is told "Could not rename this chat", followed by the dashboard's explanation when it answered with status 400 and a `detail` text

#### Scenario: Pin

- **WHEN** the user pins a thread
- **THEN** it moves into the pinned group at the top of the list at once and the pinned flag is sent; the menu then offers "Unpin"
- **AND WHEN** the dashboard refuses
- **THEN** the thread moves back and the user is told "Could not pin this chat" or "Could not unpin this chat"

#### Scenario: Archive

- **WHEN** the user archives a thread
- **THEN** the archived flag is sent, and the thread is removed from the list only after the dashboard accepted it
- **AND WHEN** the dashboard refuses
- **THEN** the thread stays and the user is told "Could not archive this chat"

#### Scenario: Delete needs confirmation

- **WHEN** the user chooses Delete
- **THEN** a dialog "Delete this chat?" asks for confirmation, and cancelling deletes nothing
- **AND WHEN** the user confirms
- **THEN** the session is deleted and the thread is removed from the list only after the dashboard accepted it; a refusal keeps the thread and reports "Could not delete this chat"

#### Scenario: The open thread is removed

- **WHEN** the open thread is archived or deleted
- **THEN** the first remaining thread is opened and its messages loaded
- **AND WHEN** none remain
- **THEN** the welcome view is shown

### Requirement: Approval requests

The system SHALL show an approval request the agent raises during a turn as a card in the reply, with the request's description, its command in a monospace block, and one button per choice the agent allows (Allow once, Allow for session, Always allow, Deny). When the request names no choices, the card SHALL offer Allow once and Deny only.

#### Scenario: Approval card appears

- **WHEN** an approval request arrives
- **THEN** a card titled "Approval needed" is added to the reply, only the offered choices are shown as buttons, and the thinking indicator is hidden

#### Scenario: Request without choices

- **WHEN** an approval request arrives with an empty or missing choice list
- **THEN** the card shows "Allow once" and "Deny" as buttons, and no others

#### Scenario: Answering

- **WHEN** the user taps a choice
- **THEN** the choice is sent for that request, the buttons are disabled while it is in flight, and once accepted the card shows the outcome ("Allowed once", "Allowed for this session", "Always allowed" or "Denied") with no buttons

#### Scenario: Always allow is confirmed

- **WHEN** the user taps "Always allow"
- **THEN** a dialog "Always allow this?" asks first, and cancelling sends nothing and leaves the card usable

#### Scenario: Answer fails

- **WHEN** sending the answer throws
- **THEN** the card stays open with "Could not send your answer. Try again." and the user can retry

#### Scenario: Request no longer pending

- **WHEN** the gateway reports that nothing was waiting on the request, or the request is no longer known to the app
- **THEN** the card is locked as expired with "This request timed out"

#### Scenario: Expiry

- **WHEN** an expire event names the request
- **THEN** only that pending card is locked as expired
- **AND WHEN** the reply completes or its stream breaks
- **THEN** every card still pending is locked as expired

#### Scenario: Expiry during an in-flight answer

- **WHEN** the request expires while an answer is being sent
- **THEN** the late acceptance does not overwrite the expired state

#### Scenario: No handler

- **WHEN** the screen has no transport to answer through
- **THEN** the buttons are disabled

### Requirement: Clarify requests

The system SHALL show a clarify request as a card "Hermes has a question" with one question, or a batch of questions, each answered by choosing from choices (one, or several when multi-select) or by typing when it has no choices.

#### Scenario: Single question

- **WHEN** a single question with choices is raised
- **THEN** it shows its choices, "Send" is disabled until one is picked, picking another choice replaces the first, and the answer is sent without a question id

#### Scenario: Open-ended question

- **WHEN** a question has no choices
- **THEN** a text field is shown, the trimmed text is sent as the answer, and Send stays disabled while it is empty

#### Scenario: Multi-select

- **WHEN** a question allows several choices
- **THEN** tapping a picked choice again drops it, and the answer is sent as a JSON array in a string

#### Scenario: Batch

- **WHEN** a batch of questions is raised
- **THEN** answers stay on the card until every question has one, and "Confirm" then sends them one question at a time, each with its question id

#### Scenario: Skip

- **WHEN** the user taps Skip
- **THEN** one empty answer without a question id is sent, which cancels the whole request, and the card then shows "Skipped"

#### Scenario: Answered

- **WHEN** every answer was accepted
- **THEN** the card lists each question with its answer and has no controls

#### Scenario: Partial failure in a batch

- **WHEN** sending one question of a batch fails after earlier ones were accepted
- **THEN** the card stays open with "Could not send your answer. Try again.", and retrying sends the whole batch again from its first question

#### Scenario: Expired request

- **WHEN** the gateway answers a `clarify.respond` with status `expired`, or an expire event arrives, or the reply ends unanswered
- **THEN** the card shows "This request timed out" and has no controls

### Requirement: Requests the app cannot answer

The system SHALL show a request for a secret value or a sudo password, whether it arrives as the events `secret.request` and `sudo.request` or as the server-to-client requests `secret` and `sudo`, as a card "Hermes needs something else" in the reply, saying that Hermes asked for "a secret value, such as an API key" or "your sudo password", that this app cannot ask for it yet, and that it can be answered in the Hermes terminal or dashboard, with a "Skip" button. The system SHALL NOT ask the user for, collect, store or send a secret or password, and SHALL NOT show the request's prompt, variable name, metadata or command. It SHALL answer a secret or sudo request only when the user taps "Skip", and then only with an empty value, which tells Hermes to carry on without it.

#### Scenario: Sudo request

- **WHEN** a `sudo.request` event or a `sudo` server-to-client request arrives
- **THEN** a card titled "Hermes needs something else" is added to the reply, saying Hermes asked for your sudo password, that the app cannot ask for it yet, and to answer it in the Hermes terminal or dashboard

#### Scenario: Secret request

- **WHEN** a `secret.request` event or a `secret` server-to-client request arrives with a prompt and a variable name
- **THEN** the card says Hermes asked for a secret value, such as an API key, and shows neither the prompt nor the variable name

#### Scenario: Nothing is collected

- **WHEN** the card is shown
- **THEN** it has no text field and one button, "Skip", and nothing is sent until the user taps it

#### Scenario: Skipping

- **WHEN** the user taps "Skip" on a pending card
- **THEN** an empty answer is sent for that request, the button is disabled while it is in flight, and once sent the card reads "You skipped this request" with no button

#### Scenario: Skipping a request that already ended

- **WHEN** the user taps "Skip" and the gateway no longer waits for the request
- **THEN** the card is locked and shows "This request timed out"

#### Scenario: Skip fails

- **WHEN** sending the empty answer throws
- **THEN** the card shows "Could not send your answer. Try again." and the button is usable again

#### Scenario: No thinking indicator

- **WHEN** the request is pending
- **THEN** the thinking indicator is hidden

#### Scenario: Expiry

- **WHEN** a `secret.expire` or `sudo.expire` event, or a `request.cancel` event, names the request
- **THEN** only that pending card is locked and shows "This request timed out" instead of where to answer
- **AND WHEN** the reply completes or its stream breaks
- **THEN** every such card still pending is locked as expired

### Requirement: Shared content

The system SHALL accept content shared into the app while the chat is open or before it opens: shared text SHALL go into the composer and shared files SHALL be listed as removable attachments above it.

#### Scenario: Shared text prefills the composer

- **WHEN** text is shared and the composer is empty
- **THEN** the text fills the composer
- **AND WHEN** the composer already holds a draft
- **THEN** the shared text is appended on a new line

#### Scenario: Shared files become chips

- **WHEN** files are shared
- **THEN** each shows as a chip with its name and a remove control, and attachments alone are enough to send

#### Scenario: Files are named, not uploaded

- **WHEN** the user sends with attachments
- **THEN** the message text is the typed text followed by a blank line and "Files (names only, contents not sent):" with the file names, and the attachments are cleared; file contents are not sent, and the composer says so under the chips

### Requirement: Opening a thread from a notification

The system SHALL open the thread named by a tapped notification, or by the notification that launched the app, when it belongs to the profile the chat is showing. A tap that arrives while the thread list is loading SHALL be held and applied once the list has loaded, ahead of the launching notification. When the thread cannot be opened, the system SHALL show "Could not open that chat." Opening a thread this way SHALL close the thread drawer when it is open and SHALL NOT close any other screen. The behaviour of notifications themselves is specified in the notifications spec.

#### Scenario: Tap opens the thread

- **WHEN** a notification for a listed thread is tapped
- **THEN** that thread is opened

#### Scenario: Other profile

- **WHEN** the notification carries another profile than the chat's
- **THEN** the open thread does not change and "Could not open that chat." is shown
- **AND WHEN** it carries no profile
- **THEN** it still matches on the thread id alone

#### Scenario: Thread not listed

- **WHEN** the thread is not in the list
- **THEN** a tap changes nothing and a launch stays on the welcome view
- **AND** "Could not open that chat." is shown

#### Scenario: Tap while threads load

- **WHEN** a notification is tapped while the thread list is loading
- **THEN** its thread is opened when the list has loaded

#### Scenario: Another screen is open

- **WHEN** a notification is tapped while Profiles or Bots is open over the chat
- **THEN** the thread is selected and that screen stays open

### Requirement: Mock data fallback

The system SHALL show built-in sample threads when the chat screen has no repository, and SHALL answer sends with a canned reply when there is no transport.

#### Scenario: No repository

- **WHEN** the chat screen has no repository (no signed-in API client and none supplied)
- **THEN** it shows three sample threads with the first selected, including a sample tool call card, and offers no rename, pin, archive or delete actions

#### Scenario: No transport

- **WHEN** a message is sent and there is no transport
- **THEN** a placeholder reply quoting the user's message appears after 900 ms and the reply is finished

#### Scenario: Transport present

- **WHEN** a transport is present
- **THEN** no canned reply is produced

### Requirement: Backend contract

The system SHALL use the following dashboard routes, JSON-RPC methods and events for chat, and SHALL parse session rows leniently, skipping rows that do not fit.

#### Scenario: REST routes

- **WHEN** the chat reads or changes threads
- **THEN** it uses `GET /api/sessions` (`limit`, `offset`, `order=recent`, `archived=exclude`, `profile`; response `sessions` and optionally `total`), `GET /api/sessions/{id}/messages` (`profile`; response `messages`), `PATCH /api/sessions/{id}` (body with `title`, `pinned` or `archived`, and `profile`) and `DELETE /api/sessions/{id}` (`profile`)
- **AND** it uses `GET /api/profiles/active` to learn which profile to list, `POST /api/auth/ws-ticket` (response `ticket`) and `GET /` (the `__HERMES_SESSION_TOKEN__` value) to obtain socket credentials

#### Scenario: Row fields

- **WHEN** a session row is parsed
- **THEN** `id`, `title`, `preview`, `last_active`, `started_at` and `pinned` are read
- **AND** a message row's `id`, `role`, `content`, `timestamp` and `tool_calls` are read, and a loaded message's id is `<session id>-<row id>`

#### Scenario: JSON-RPC methods

- **WHEN** the chat talks over `/api/ws`
- **THEN** it requests `session.create` (optional `profile`), `session.resume` (`session_id`, optional `profile`), `prompt.submit` (`session_id`, `text`), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), `client.capabilities` (`server_requests`) and `clarify.lock` (`request_id`, `question_id`, `answer`; a `status` of `expired` means not accepted) and `session.interrupt` (`session_id`; a `status` of `interrupted` means a running turn was stopped), as JSON-RPC 2.0 with integer ids
- **AND** the gateway binds a session to the profile it was created or resumed under, so `prompt.submit` and the answer calls carry no profile
- **AND** it answers a secret or a sudo request only to skip it: `sudo.respond` (`request_id`, `password` empty) or `secret.respond` (`request_id`, `value` empty), where a `status` of `expired` means not accepted

#### Scenario: Unknown profile

- **WHEN** `session.create` or `session.resume` carries a `profile` that names no profile on the host
- **THEN** a Hermes newer than the ref pinned for the contract test answers with the JSON-RPC error 4064 and a message naming the profile; the system treats that code as "the selected profile no longer exists" and reads nothing else from the error
- **AND** an older Hermes may drop the socket instead, which the system treats as any other socket drop

#### Scenario: Server-to-client requests

- **WHEN** the gateway sends a JSON-RPC request with a string id and a `method`
- **THEN** `approval` (`session_id`, `command`, `description`, `choices`) shows an approval card, and `clarify` (`session_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`) shows a clarify card, both keyed by the request's `id`
- **AND** `secret` and `sudo` show the card for requests the app cannot answer, reading nothing but the `id` and the session
- **AND** any other method is answered at once with the JSON-RPC error -32601 "method not found" when its `session_id` is a runtime session this app has a reply in flight for
- **AND** an unhandled request for any other session is neither shown nor answered, because another client attached to that session may answer it, and the first response settles it for all of them
- **AND** a request whose `session_id` is not the reply's runtime session is left alone

#### Scenario: Answering a server-to-client request

- **WHEN** the user answers an approval
- **THEN** a response frame `{id, result: {choice}}` is sent with the request's id
- **AND WHEN** the user answers a single clarify question
- **THEN** a response frame `{id, result: {answer}}` is sent, the answer being the JSON-encoded list for a multi-select question
- **AND WHEN** the user answers one question of a batch
- **THEN** `clarify.lock` is requested with the request's id as `request_id`, and its result decides whether the answer was accepted
- **AND WHEN** the user skips a `secret` or `sudo` request
- **THEN** a response frame `{id, result: {value: ''}}` is sent with the request's id
- **AND WHEN** the user skips a whole batch
- **THEN** a response frame with an empty result is sent with the request's id, and `clarify.lock` is not requested

#### Scenario: Events

- **WHEN** the gateway pushes an `event` notification
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`; `error` marks a failed reply and `interrupted` a stopped one), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), `secret.request` and `sudo.request` (`request_id` only; the prompt, variable name and metadata are not read), and `approval.expire`, `clarify.expire`, `secret.expire` or `sudo.expire` (`request_id`), and `request.cancel` (`id`, the id of a server-to-client request)
- **AND** other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored

### Requirement: Stopping a reply

The system SHALL, while a reply is in flight in the open thread, show a bar above the composer saying "Hermes is replying…" with a "Stop" button, and SHALL ask the gateway to interrupt that thread's running turn when the user taps it. The reply SHALL end as a completed reply that keeps what had streamed, or reads "Stopped." when nothing had, and SHALL NOT be shown as failed. The bar SHALL NOT be shown when no reply is in flight, and sending SHALL work again once the reply has ended.

#### Scenario: Stop while replying

- **WHEN** a reply is in flight in the open thread and the user taps "Stop"
- **THEN** the running turn of that thread is interrupted and the button is disabled while the request is in flight

#### Scenario: The reply ends as stopped

- **WHEN** the gateway completes the turn with the status `interrupted`
- **THEN** the reply keeps its streamed text, or reads "Stopped." when it had none, and the bar disappears

#### Scenario: Sending again

- **WHEN** a reply was stopped and the user sends another prompt in that thread
- **THEN** the prompt is sent

#### Scenario: Nothing is replying

- **WHEN** no reply is in flight in the open thread
- **THEN** no bar and no "Stop" button are shown

#### Scenario: Nothing is running any more

- **WHEN** the gateway reports that no turn was running
- **THEN** nothing changes and no error is shown

#### Scenario: Stop fails

- **WHEN** sending the interrupt fails
- **THEN** "Could not stop the reply. Try again." is shown and "Stop" stays available

