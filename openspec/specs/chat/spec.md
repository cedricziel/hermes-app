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

### Requirement: Thread search

The sidebar SHALL offer a search field above the thread list. While it holds text, the system SHALL search the active profile's sessions on the dashboard once the user has stopped typing for a short pause, and SHALL show the results in place of the thread list. Each result SHALL show the chat's title and the text that matched, with the matched words emphasised. Tapping a result SHALL open that chat, including one the loaded pages of the thread list do not hold. Clearing the field SHALL show the thread list again, and switching profile SHALL clear the search.

The system SHALL rely on `GET /api/sessions/search?q=<text>&limit=<n>&profile=<name>`, which answers `{"results": [...]}`. Each row carries `session_id` (and usually `id`), and may carry `title`, `preview`, `snippet` (FTS5 text with matches wrapped in `>>>` and `<<<`), `last_active` and `session_started` (epoch seconds). Rows without a usable id SHALL be skipped. The route exists in the Hermes version the real-backend contract test is pinned to.

#### Scenario: Results replace the list

- **WHEN** the user types a query and pauses
- **THEN** the dashboard is searched once for it on the active profile and the matching chats are shown instead of the thread list, each with its title and matched text

#### Scenario: Typing does not search on every key

- **WHEN** the user types several characters in quick succession
- **THEN** only the text present after the pause is searched

#### Scenario: No match

- **WHEN** the search returns no rows
- **THEN** the sidebar says that no chat matches the query

#### Scenario: Search fails

- **WHEN** the search request fails
- **THEN** the sidebar says the search failed, and the thread list is unchanged

#### Scenario: Opening a result not in the loaded list

- **WHEN** the user taps a result for a chat older than the loaded pages
- **THEN** that chat is fetched, added to the list and opened

#### Scenario: Clearing the search

- **WHEN** the user clears the field
- **THEN** the thread list is shown again

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

#### Scenario: Tool results are put on their calls

- **WHEN** a `tool` row carries a `tool_call_id` and string content
- **THEN** that content is the result of the call with that id, shown on its card, and the row itself is not shown

#### Scenario: A long thread opens on its newest rows

- **WHEN** a thread's messages are fetched
- **THEN** the newest rows are requested (`order=latest`, a `limit` of 100, `offset` 0), not the whole session

#### Scenario: Scrolling to the top reads older rows

- **WHEN** the user scrolls to the top of a thread whose last page came back full
- **THEN** the next older page is fetched and put above the messages already shown, without moving what the user is looking at
- **AND** the page rereads the newest rows just after it, so a call at the page edge still gets its result, and a message already held is not added twice
- **AND** once a page comes back short, scrolling to the top asks for nothing more

#### Scenario: Loading older rows fails

- **WHEN** fetching an older page fails
- **THEN** the user is told "Could not load earlier messages", and scrolling to the top again tries again

#### Scenario: Timestamps

- **WHEN** message or session rows carry timestamps
- **THEN** they are read as epoch seconds, and a missing timestamp is read as the epoch

### Requirement: Rendering of messages

The system SHALL render a message as its tool call cards, each after the reasoning that led to it, with each agent input request card right after the tool call that was running when it arrived, then the reasoning that followed the last call, then the text, then a thinking indicator, and SHALL render message text as markdown.

#### Scenario: What follows an input request renders below it

- **WHEN** a reply reasons, writes text or starts tool calls after an input request arrived
- **THEN** those render below the request's card, and the request's card stays below the tool call that asked it

#### Scenario: Thinking indicator

- **WHEN** an assistant reply is pending with no text yet, no reasoning yet and no input request is waiting
- **THEN** a thinking indicator (three pulsing dots) is shown in place of text

#### Scenario: No indicator while the agent waits for the user

- **WHEN** a reply is still thinking and one of its input requests is pending
- **THEN** the thinking indicator is hidden

#### Scenario: No indicator once reasoning shows

- **WHEN** a reply is still thinking and has reasoning
- **THEN** the thinking indicator is hidden and the reasoning block is shown

#### Scenario: Failed reply

- **WHEN** a reply ended in error and has text
- **THEN** its text is drawn in the error colour

#### Scenario: Empty thread

- **WHEN** the open thread has no messages, or no thread is selected
- **THEN** the welcome view shows "Where should we begin?" (with the user's display name appended when known) and four starter prompts as defined by "Context-based starter prompts"

#### Scenario: Responsive layout

- **WHEN** the available width is at least 900 logical pixels
- **THEN** the thread rail is permanently shown beside the transcript, with the thread title above it
- **AND WHEN** the width is smaller
- **THEN** the rail opens as a drawer and the thread title is shown in the app bar

### Requirement: Context-based starter prompts

The system SHALL show four starter prompts in the welcome view. It SHALL build them on the device from the active profile's context, without calling a model, taking at most one prompt from each of these sources in this order:

1. Scheduled jobs: a job whose last run failed. The prompt reads "Why did the scheduled job '<name>' fail on its last run?".
2. Kanban, only while the dashboard reports the Kanban plugin as enabled: a task in the default board with status `blocked`, or else one with status `review`. The prompt reads "What's blocking the Kanban task '<title>'?" or "What's left before the Kanban task '<title>' is done?".
3. Recent chats: the most recently active chat of the profile that has a title and is not the chat on screen. The prompt reads "Pick up '<title>'".
4. Skills: the enabled skill with the highest use count, if its use count is above zero. The card reads "Use the <name> skill to…" and puts "Use the <name> skill to " into the composer for the user to finish.

When several items of a source qualify, the system SHALL pick the most recent one (by last run time for jobs, by the board's order for tasks). The system SHALL fill the remaining slots with generic prompts that make sense on any server, in a fixed order. Each prompt SHALL show an icon for its source.

The system SHALL show the generic prompts immediately and SHALL replace them with the contextual prompts once, when every source has answered, failed or timed out. A source that fails, times out, or answers with rows it cannot parse SHALL be left out without showing an error. The context SHALL be loaded again when the active profile changes, and when the welcome view is shown again, by a change in the chat or by the app coming back to the front, and the last load is more than five minutes old.

Tapping a generic prompt SHALL send it as a message. Tapping a job, Kanban or skill prompt SHALL put its text into the composer without sending it, replacing any text already there. Tapping a recent-chat prompt SHALL open that chat.

The system SHALL rely on these dashboard routes, which the Schedules, Kanban and Skills screens already use: `GET /api/cron/jobs?profile=<name>` (a job's `name`, `last_run_at`, `last_status`, `state`), `GET /api/dashboard/plugins` (an entry with `name: kanban`), `GET /api/plugins/kanban/board` (tasks with `title` and `status`) and `GET /api/skills?profile=<name>` (`name`, `enabled`, `usage`). It needs no newer Hermes version than those screens.

#### Scenario: New install with no context

- **WHEN** the welcome view is shown and no source yields a prompt
- **THEN** four generic prompts are shown, and tapping one sends it as a message

#### Scenario: Every source yields a prompt

- **WHEN** a scheduled job's last run failed, the Kanban plugin is on and a task is blocked, the profile has an earlier titled chat, and an enabled skill has been used
- **THEN** the welcome view shows, in this order, the failed-job prompt, the blocked-task prompt, the recent-chat prompt and the skill prompt, each with its source icon, and no generic prompt

#### Scenario: Some sources yield a prompt

- **WHEN** only the recent-chat source yields a prompt
- **THEN** the recent-chat prompt is shown first, followed by three generic prompts

#### Scenario: Kanban plugin off

- **WHEN** the dashboard does not report the Kanban plugin as enabled
- **THEN** no Kanban prompt is shown and the Kanban board is not requested

#### Scenario: Review task when nothing is blocked

- **WHEN** the Kanban plugin is on, no task is blocked and a task is waiting for review
- **THEN** the Kanban prompt asks what is left before that task is done

#### Scenario: Source fails

- **WHEN** listing the scheduled jobs fails or times out
- **THEN** no job prompt is shown, the other sources still yield their prompts, and no error is shown

#### Scenario: Prompts swap once

- **WHEN** the welcome view is shown before the context has loaded
- **THEN** the generic prompts are shown, and they are replaced by the contextual prompts once, after every source has answered, failed or timed out

#### Scenario: Tapping a specific prompt fills the composer

- **WHEN** the user taps the failed-job, Kanban or skill prompt
- **THEN** its text is put into the composer, replacing what was there, and nothing is sent

#### Scenario: Tapping a recent-chat prompt opens the chat

- **WHEN** the user taps "Pick up '<title>'"
- **THEN** that chat is opened and nothing is sent

#### Scenario: Profile switch

- **WHEN** the user switches to another profile while the welcome view is shown
- **THEN** the prompts are rebuilt from the new profile's jobs, chats and skills

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

### Requirement: Streaming the reply

The system SHALL stream the assistant reply into the transcript as it arrives and SHALL keep streaming into the reply's own thread when the user switches to another thread.

#### Scenario: Deltas stream in

- **WHEN** reply text chunks arrive
- **THEN** they are appended to the reply, which moves from thinking to streaming

#### Scenario: Completion

- **WHEN** the reply completes with a final text
- **THEN** the reply shows that text in full, replacing what had streamed since the last text sealed before a tool call or by an interim message, and is finished
- **AND WHEN** the final text is empty
- **THEN** the text that had streamed is kept

#### Scenario: Final already shown as an interim message

- **WHEN** the completion is marked `response_previewed` or `response_reused`
- **AND WHEN** its text equals the text last sealed by an interim message, or the text that streamed since
- **THEN** the reply is finished without showing that text a second time
- **AND WHEN** its text appears nowhere in the reply
- **THEN** it is shown as for any other completion

#### Scenario: Final rewritten after streaming

- **WHEN** the completion is marked `response_transformed`
- **THEN** its text replaces what had streamed since the last seal, even when it shares no prefix with it

#### Scenario: Interim message for text that already streamed

- **WHEN** an interim message arrives with `already_streamed` true
- **THEN** the text that streamed since the last seal is sealed in the interim message's form, and nothing is added twice
- **AND WHEN** an interim message arrives with `already_streamed` false
- **THEN** any text that had streamed since the last seal is sealed as it is, and the interim message's text is sealed after it

#### Scenario: Thinking text is not reply text

- **WHEN** a `thinking.delta` event arrives
- **THEN** nothing is added to the reply text or its reasoning (an explained provider wait may update the status line, see "Reply status line")

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

#### Scenario: Failed completion with a partial answer

- **WHEN** the gateway completes a turn with status `error` and `partial` true
- **THEN** the completion's text is kept as the reply's answer, and the reply is marked as an error showing the completion's `error` as the explanation

#### Scenario: Failed completion without text

- **WHEN** the gateway completes a turn with status `error` and supplies no message text
- **THEN** the reply is marked as an error, keeps any text that had already streamed, and otherwise shows "Something went wrong. Try sending it again."

#### Scenario: Error event without a completion

- **WHEN** an `error` event arrives for the reply's runtime session while the turn runs, and no completion follows before the session settles
- **THEN** the reply is marked as an error showing the event's `message`, and keeps any text that had already streamed
- **AND WHEN** a failed completion arrives after the `error` event
- **THEN** the reply shows one error, not two

#### Scenario: Stream drops or ends without completion

- **WHEN** the socket drops and the reply cannot be picked up again (see "Reconnecting a live reply"), the gateway answers a request with an error, or the stream ends before a completion
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

#### Scenario: Events that arrive before the resume answer

- **WHEN** the gateway pushes events of the resumed runtime session before it answers `session.resume`
- **THEN** those events are kept and delivered in order once the runtime session is known, not dropped

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
- **AND** resending an answer the gateway already accepted is harmless, because the gateway stores batch answers per `question_id` and overwrites them in place until the last question is answered (`clarify.lock`, and `clarify.respond` with a `question_id` on gateways from before server-to-client requests)

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

The system SHALL use the following dashboard routes, JSON-RPC methods and events for chat, and SHALL parse session rows leniently, skipping rows that do not fit. The minimum Hermes is the ref pinned for the contract test (`7b3c7aef`); behaviour that needs a newer Hermes SHALL degrade to the pinned behaviour.

#### Scenario: REST routes

- **WHEN** the chat reads or changes threads
- **THEN** it uses `GET /api/sessions` (`limit`, `offset`, `order=recent`, `archived=exclude`, `profile`; response `sessions` and optionally `total`), `GET /api/sessions/{id}/messages` (`profile`, `limit`, `offset`, `order`; response `messages`), `PATCH /api/sessions/{id}` (body with `title`, `pinned` or `archived`, and `profile`) and `DELETE /api/sessions/{id}` (`profile`)
- **AND** it uses `GET /api/profiles/active` to learn which profile to list, `POST /api/auth/ws-ticket` (response `ticket`) and `GET /` (the `__HERMES_SESSION_TOKEN__` value) to obtain socket credentials

#### Scenario: Row fields

- **WHEN** a session row is parsed
- **THEN** `id`, `title`, `preview`, `last_active`, `started_at` and `pinned` are read
- **AND** a message row's `id`, `role`, `content`, `timestamp` and `tool_calls` are read, and a loaded message's id is `<session id>-<row id>`

#### Scenario: JSON-RPC methods

- **WHEN** the chat talks over `/api/ws`
- **THEN** it requests `session.create` (optional `profile`), `session.resume` (`session_id`, optional `profile`; the result's `session_id`, `running`, `inflight.assistant`, `open_requests` and `messages` are read), `prompt.submit` (`session_id`, `text`, optional `queued`; the result's `status` is read), `session.events.since` (`session_id`, `last_seen`; result `events`, `latest_seq`, `truncated`, `epoch`, `open_requests`), `session.active_list`, `gateway.ping` (any answer counts), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), `client.capabilities` (`server_requests`) and `clarify.lock` (`request_id`, `question_id`, `answer`; a `status` of `expired` means not accepted) and `session.interrupt` (`session_id`; a `status` of `interrupted` means a running turn was stopped), as JSON-RPC 2.0 with integer ids
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
- **THEN** a response frame `{id, result: {choice}}` is sent with the request's id, on whichever connection is open; the gateway matches answers by id, not by connection
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
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `message.interim` (`text`, `already_streamed`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`, `error`, `partial`, `response_previewed`, `response_reused`, `response_transformed`; status `error` marks a failed reply and `interrupted` a stopped one), `error` (`message`), `session.info` (`running`, `stored_session_id`), `status.update` (`kind`, `text`), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), `secret.request` and `sudo.request` (`request_id` only; the prompt, variable name and metadata are not read), `approval.expire`, `clarify.expire`, `secret.expire` or `sudo.expire` (`request_id`), `request.cancel` (`id`, the id of a server-to-client request), and the session-less broadcast `approval.cancelled` (`payload.session_id`, `payload.request_ids`)
- **AND** the event's `seq` (in `params`, rising per runtime session) is read when present
- **AND** `thinking.delta` (`text`) is read only for the status line, and other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored

### Requirement: Stopping a reply

The system SHALL, while a reply is in flight in the open thread, show a bar above the composer saying "Hermes is replying…" with a "Stop" button, and SHALL ask the gateway to interrupt that thread's running turn when the user taps it. The reply SHALL end as a completed reply that keeps what had streamed, or reads "Stopped." when nothing had, and SHALL NOT be shown as failed. A stopped reply that kept streamed text SHALL be marked "Stopped" under it, so it does not read as a finished answer. The bar SHALL NOT be shown when no reply is in flight, and sending SHALL work again once the reply has ended.

#### Scenario: Stop while replying

- **WHEN** a reply is in flight in the open thread and the user taps "Stop"
- **THEN** the running turn of that thread is interrupted and the button is disabled while the request is in flight

#### Scenario: The reply ends as stopped

- **WHEN** the gateway completes the turn with the status `interrupted`
- **THEN** the reply keeps its streamed text, or reads "Stopped." when it had none, and the bar disappears

#### Scenario: A stopped reply with text is marked

- **WHEN** the user stops a reply after some text had streamed
- **THEN** the reply keeps that text and shows "Stopped" under it
- **AND WHEN** a reply completes without being stopped
- **THEN** no such mark is shown

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

### Requirement: Shared content is attached and sent

The system SHALL accept content shared into the app while the chat is open or before it opens: shared text SHALL go into the composer and shared files SHALL be listed as removable attachments above it. Attachments SHALL be sent to Hermes with the message, as the `chat-attachments` spec describes, and SHALL then be cleared from the composer.

#### Scenario: Shared text prefills the composer

- **WHEN** text is shared and the composer is empty
- **THEN** the text fills the composer
- **AND WHEN** the composer already holds a draft
- **THEN** the shared text is appended on a new line

#### Scenario: Shared files become chips

- **WHEN** files are shared
- **THEN** each shows as a chip with its name and a remove control, and attachments alone are enough to send

#### Scenario: Files are sent with the message

- **WHEN** the user sends with attachments
- **THEN** the attachments are sent to Hermes with the message and cleared from the composer

### Requirement: Reasoning

The system SHALL show the model's reasoning, when there is any, as blocks in the order it happened: the reasoning before each tool call sits above that call's card, and the reasoning after the last call sits below the cards and above the text. Each block SHALL be folded by default and open and close when tapped. A block SHALL read "Thinking…" while the reply is pending and "Reasoning" once it has ended. A reply without reasoning SHALL have no block.

#### Scenario: Reasoning streams in

- **WHEN** the gateway sends `reasoning.delta` events for the running turn
- **THEN** their `text` is appended to the reasoning after the last tool call, or before the first when there is none, in order
- **AND WHEN** it sends `reasoning.available`, a preview of the reply text sent after the model answered
- **THEN** its `text` is shown as that reasoning only when no reasoning and no reply text streamed since the last tool call, and never replaces reasoning that streamed

#### Scenario: A tool call ends a block of reasoning

- **WHEN** a tool starts after reasoning arrived
- **THEN** that reasoning stays above the tool's card, and reasoning that arrives after it opens a new block below the card

#### Scenario: Reasoning does not end the wait

- **WHEN** reasoning arrives and no reply text has
- **THEN** the reply is still pending, and no reply text is shown

#### Scenario: Loaded thread

- **WHEN** a session message row carries a `reasoning` string
- **THEN** that message shows it in a reasoning block, above its first tool call when the row has tool calls, and a `reasoning` that is not a string is read as none

#### Scenario: Spinner text is not reasoning

- **WHEN** the gateway sends `thinking.delta`
- **THEN** nothing is shown for it

### Requirement: Reply actions

The system SHALL show an action bar below the text of a finished assistant reply, and none below a reply that is still being written or below a message of the user. The bar SHALL offer Copy, which puts the reply's text on the clipboard and shows a tick in place of its icon for two seconds, and, on the latest reply of the open thread only, Try again, which sends the text of the thread's last prompt again as a new turn, without its files, and is not offered when that prompt had no text. A failed reply SHALL offer Try again but not Copy. Try again SHALL NOT be offered while a reply is being written, and SHALL NOT touch the composer or its attachments.

#### Scenario: Copy

- **WHEN** the user taps Copy under a reply
- **THEN** the reply's text is on the clipboard and the icon shows a tick until two seconds have passed

#### Scenario: Try again

- **WHEN** the user taps Try again under the latest reply
- **THEN** the text of the thread's last prompt is sent again to the same thread without its files, and what the user had typed and attached in the composer is kept

#### Scenario: Only the latest reply

- **WHEN** a newer reply has finished in the thread
- **THEN** the earlier replies offer Copy only

#### Scenario: Still being written

- **WHEN** a reply is streaming
- **THEN** no action bar is shown under it, and no reply offers Try again

#### Scenario: Failed reply

- **WHEN** a reply ended in error
- **THEN** it offers Try again and no Copy

### Requirement: Follow-up chips

The system SHALL show three chips below the action bar of the latest reply of the open thread, reading "Explain in more detail", "Give an example" and "Summarize this", and SHALL send the chip's text as a prompt in that thread when the user taps one. The chips SHALL NOT be shown under an earlier reply, under a reply that is still being written or under a failed reply, and SHALL NOT change with the reply.

#### Scenario: Tapping a chip

- **WHEN** the user taps "Give an example"
- **THEN** "Give an example" is sent as a new turn in the open thread

#### Scenario: Only the latest reply

- **WHEN** a newer reply finishes, or the latest one failed
- **THEN** the earlier reply shows no chips

### Requirement: Sending a message and queueing

The system SHALL append the user's message and a thinking placeholder for the assistant reply to the transcript at once when the user sends, and SHALL clear the composer. Blank text with no attachments SHALL NOT be sent. On a thread that has a pending reply, meaning a reply that is thinking or streaming, including one that waits for the user to answer an approval or clarify request, the system SHALL queue the message instead of sending it (see "Queued messages"). Other threads SHALL NOT be affected.

#### Scenario: Send shows prompt and placeholder

- **WHEN** the user sends "hello"
- **THEN** the transcript shows "hello" and a thinking placeholder, and the composer is emptied

#### Scenario: Enter sends

- **WHEN** the user presses Enter in the composer
- **THEN** the message is sent
- **AND WHEN** the user presses Shift+Enter
- **THEN** a line break is added and nothing is sent

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

#### Scenario: Queued while the reply streams

- **WHEN** the user sends again in a thread whose reply is still streaming
- **THEN** nothing is sent yet, the message is queued and the composer is emptied

#### Scenario: Queued while a request is pending

- **WHEN** the reply waits on an approval or clarify request that is not answered yet
- **AND WHEN** the user sends again in that thread
- **THEN** nothing is sent yet and the message is queued

#### Scenario: Allowed after completion

- **WHEN** the reply in a thread has completed
- **AND WHEN** the user sends again in that thread
- **THEN** the message is sent

#### Scenario: Allowed after a broken stream

- **WHEN** the reply stream of a thread broke and the reply is marked failed
- **AND WHEN** the user sends again in that thread with nothing queued
- **THEN** the message is sent

#### Scenario: Other thread unaffected

- **WHEN** a thread has a pending reply
- **AND WHEN** the user switches to another thread and sends
- **THEN** the message is sent under that other thread

### Requirement: Queued messages

The system SHALL hold the messages queued on a thread, text and attachments, in the order they were sent, and SHALL show those of the open thread above the composer, each with a control to remove it. While the thread's reply is pending the composer's hint SHALL read "Queue a message…". When a reply ends normally, whether it answered a prompt or was a turn Hermes started on its own, and no reply is pending, the system SHALL send the first queued message as a new turn and remove it from the queue, once the gateway reports the session settled (`session.info` with `running` false) or 2 seconds after the completion when no such report comes. A queued message SHALL be submitted with `queued: true`. When a reply is stopped by the user or fails, the queue SHALL pause: nothing more is sent on its own, and the queue SHALL offer "Send now", which sends its first message. A message sent on a thread whose queue is paused SHALL join the end of the queue, and the first queued message SHALL be sent. An attachment that cannot be sent SHALL be refused when the message is queued, as for a direct send. The queue SHALL be held in memory only, and SHALL be dropped when the threads are loaded again, for example on a profile switch. The queue SHALL NOT use any backend route or RPC method beyond those of a direct send (`session.resume`, `prompt.submit`).

#### Scenario: Queued message shown

- **WHEN** the user sends "next" while the reply is streaming
- **THEN** "next" is listed above the composer and is not in the transcript yet

#### Scenario: Sent when the reply completes

- **WHEN** two messages are queued and the reply completes
- **THEN** the first queued message is sent and moves into the transcript with a thinking placeholder
- **AND** the second stays queued until that reply completes, and is then sent

#### Scenario: Sent only once the session settled

- **WHEN** a message is queued and the reply completes
- **THEN** nothing is submitted until the gateway reports the session not running, or 2 seconds have passed
- **AND** the message is then submitted with `queued` set to true

#### Scenario: Waits for a turn Hermes starts

- **WHEN** Hermes runs a turn of its own after a reply, such as a goal continuation
- **AND WHEN** the user sends in that thread during it
- **THEN** the message is queued and sent once that turn completes

#### Scenario: Paused by stop

- **WHEN** a message is queued and the user stops the reply
- **THEN** the message is not sent and the queue offers "Send now"
- **AND WHEN** the user taps "Send now"
- **THEN** the message is sent

#### Scenario: Paused by a failure

- **WHEN** a message is queued and the reply fails
- **THEN** the message is not sent and the queue offers "Send now"
- **AND WHEN** a stop of that reply is still unanswered and the gateway then answers that nothing was running
- **THEN** the queue stays paused

#### Scenario: A stop that finds nothing running

- **WHEN** a message is queued, the user stops the reply, and the turn ends on its own before the stop is answered
- **AND** the gateway answers that nothing was running
- **THEN** the queued message is sent as after a normal settle
- **AND WHEN** an earlier stop of the same reply was confirmed, or the reply failed
- **THEN** the queue stays paused

#### Scenario: Send on a paused queue

- **WHEN** the queue is paused with "first" queued
- **AND WHEN** the user sends "second"
- **THEN** "first" is sent and "second" stays queued

#### Scenario: Removed from the queue

- **WHEN** the user removes a queued message
- **THEN** it is no longer listed and is never sent

#### Scenario: Queue belongs to its thread

- **WHEN** a thread has queued messages and the user opens another thread
- **THEN** the other thread shows no queue, and the first thread's queue is sent there when its reply completes

#### Scenario: A sent queued message comes into view

- **WHEN** the user is at the bottom of the thread and a queued message is sent after a long reply
- **THEN** the transcript shows the new message and follows its reply

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

### Requirement: Searching from a Mac toolbar

On macOS the chat SHALL be searched from the window's toolbar instead of the sidebar: a field in a large window (1000 points and wider), a search button that opens the field in a narrower one. ⌘F SHALL open the search and put the cursor in the field; Escape and the field's clear button SHALL end it. While a search is open the sidebar SHALL show its results in place of the destinations and threads. The sidebar SHALL have no search field and no New chat row there; New Chat is a toolbar button.

The results SHALL offer two scopes, "This profile" and "All profiles", when the server lists profiles. All profiles SHALL search every profile with `GET /api/sessions/search?profile=<name>` at the same time and merge the results newest first; a profile whose search fails SHALL be left out, and the search SHALL fail only when every profile fails. Hits SHALL be grouped into Chats (the title holds the query) and Messages (the rest), each with its count, and each hit SHALL show its title, when it was last active and two lines of matched text with the matches emphasised. A hit from another profile SHALL name that profile before its text, and opening it SHALL switch to that profile and open the chat. With an empty field the results SHALL list the last five searches, which are kept across launches; opening a hit or pressing Return in the field SHALL add the query to them. No hits SHALL read "No results for “<query>”".

#### Scenario: Command-F

- **WHEN** the user presses ⌘F with the chat in front
- **THEN** the search field takes the cursor and the sidebar lists the recent searches

#### Scenario: Results replace the sidebar

- **WHEN** the user types a query and pauses
- **THEN** the sidebar shows the hits under Chats and Messages, and Escape brings the destinations and threads back

#### Scenario: All profiles with one failing

- **WHEN** the user picks All profiles and one profile's search fails
- **THEN** the hits of the other profiles are shown, newest first

#### Scenario: A hit from another profile

- **WHEN** the user opens a hit found in the profile "work" while "default" is active
- **THEN** the chat switches to "work" and opens that chat

### Requirement: Mac chat toolbar

On macOS the chat's toolbar SHALL show the open chat's title (or "Hermes") over a line "<profile> · <model>" (the chat's model choice, else the profile's default; parts that are unknown left out), then New Chat (⌘N), Copy Transcript, Connection Details and the search. In a window narrower than 760 points Copy Transcript and Connection Details SHALL be in a "…" menu.

#### Scenario: Compact toolbar

- **WHEN** the window is 680 points wide
- **THEN** the toolbar shows New Chat, a "…" menu holding Copy Transcript and Connection Details, and a search button

### Requirement: Sidebar of a compact Mac window

On macOS the sidebar SHALL stay beside the content down to a window width of 760 points. In a narrower window it SHALL not be docked; the toolbar's sidebar button and ⌃⌘S SHALL open it over the content, with a scrim that closes it, and picking a thread, a search hit or a destination SHALL close it. Opening a search in a compact window SHALL open the sidebar for the results. Whether the docked sidebar is hidden SHALL not change through a compact window.

#### Scenario: Overlay closes on a pick

- **WHEN** the user opens the sidebar in a 700 point window and picks a thread
- **THEN** the thread opens and the sidebar closes


### Requirement: Conversation windows (macOS)

On macOS the system SHALL let the user open a chat the dashboard holds in a window of its own, from the thread's "Open in New Window" action (⌥⌘O) or by double-clicking the thread in the sidebar. The window SHALL show only that chat: a toolbar with the chat's title and "<profile> · <model>" below it, the messages and the composer, without the sidebar. Its toolbar SHALL offer Show in Main Window, Pin or Unpin (⇧⌘P), Share and a menu with Rename, Copy Transcript, Archive and Delete. The window SHALL stay on the profile the chat was opened from, whatever profile the main window switches to. Opening a chat that already has a window SHALL bring that window to the front. The Window menu SHALL list the open conversation windows; while one is key, the menu bar's window and chat commands SHALL act on it, ⌘0 SHALL bring back the main window and ⌘W SHALL close the conversation window. A chat that has a window SHALL be followed there only: selecting it or sending in it from the main window SHALL bring its window up instead. The open conversation windows SHALL be opened again, in their last frames, the next time the app connects to the same server. Signing out or changing server SHALL close them and forget them; a session that expires SHALL close them and open them again after the next sign-in. On other platforms none of this is offered.

A conversation window SHALL NOT read stored tokens or refresh the session itself: it SHALL get the headers for each request from the main window, which stays the only part of the app that refreshes the session.

The system SHALL rely on the same routes as the main window: `GET /api/sessions`, `GET /api/sessions/{id}`, `GET /api/sessions/{id}/messages`, the session housekeeping routes and the `/api/ws` socket, all with `profile=<name>`.

#### Scenario: Open a chat in its own window

- **WHEN** the user picks "Open in New Window" for a chat in the sidebar
- **THEN** a new window shows that chat's messages and composer, with the chat's title and its profile and model in the toolbar, and no sidebar

#### Scenario: The window keeps its profile

- **WHEN** a chat from profile A is open in its own window and the user switches the main window to profile B
- **THEN** the conversation window still shows the chat from profile A and sends to profile A

#### Scenario: The same chat is not opened twice

- **WHEN** the user opens a chat in a new window while it already has one
- **THEN** the existing window comes to the front and no second window opens

#### Scenario: Show in main window

- **WHEN** the user picks Show in Main Window in a conversation window
- **THEN** the main window comes to the front with that chat selected, switching to the chat's profile if needed

#### Scenario: A reply sent in one window shows in the other

- **WHEN** the user sends a message in a conversation window and, after the reply, makes the main window key
- **THEN** the main window shows the message and the reply in that chat

#### Scenario: Deleted in its window

- **WHEN** the user deletes the chat from its conversation window
- **THEN** the window closes, and the chat is gone from the main window's list once that window is key again

#### Scenario: Windows come back after a relaunch

- **WHEN** the user quits the app with two conversation windows open and launches it again on the same server
- **THEN** both windows open again where they were, each on its own chat and profile

#### Scenario: Sign-out closes the windows

- **WHEN** the user signs out in the main window
- **THEN** every conversation window closes and none is opened again on the next launch

#### Scenario: Handoff follows the key window

- **WHEN** a conversation window is the key window
- **THEN** Handoff offers that window's chat, and once the main window is key again it offers the main window's chat

#### Scenario: A handed-over chat that has a window

- **WHEN** another device hands over a chat that is open in a conversation window
- **THEN** that window comes to the front and the main window does not open the chat

#### Scenario: The main window leaves a windowed chat to its window

- **WHEN** the user selects, in the main window's sidebar, a chat that is open in a conversation window
- **THEN** that window comes to the front and the main window does not open the chat

#### Scenario: Windows come back after the session expires

- **WHEN** the session expires while conversation windows are open and the user signs in again
- **THEN** the windows close, and open again once the user is signed in

#### Scenario: Only the current server's windows get credentials

- **WHEN** a window opened for another server, or one the main window does not know, asks for request headers
- **THEN** it gets none and is closed

#### Scenario: A conversation window never refreshes the session

- **WHEN** a request from a conversation window gets a 401
- **THEN** the window asks the main window for new headers, naming the ones that failed, retries once with them, and the main window refreshes the session only if those were its current token

### Requirement: Turn settling

The system SHALL end a reply's turn on whichever comes first: `message.complete`, an `error` event with no completion before the session settles, or `session.info` with `running` false. A live turn with no frame for 45 seconds SHALL be checked with `session.active_list` and ended only when the session is no longer listed as running.

#### Scenario: Settled without a completion

- **WHEN** a reply has started and `session.info` arrives with `running` false before any completion
- **THEN** the reply ends keeping its streamed text, empty placeholders are removed, open input requests are locked as expired, and running tools are settled
- **AND WHEN** a completion for that turn arrives later
- **THEN** it lands on the same reply and does not create a second one

#### Scenario: Stale report before the turn began

- **WHEN** `session.info` with `running` false arrives within 15 seconds of `prompt.submit` and before `message.start`
- **THEN** the reply is not ended

#### Scenario: A silent live turn

- **WHEN** a reply in flight receives no frame for 45 seconds
- **THEN** `session.active_list` is requested, and the reply is ended as for a broken stream only when its session is not listed as running
- **AND WHEN** the session is still listed as running
- **THEN** the reply keeps waiting

### Requirement: Submit outcome

The system SHALL read the `status` of `prompt.submit`. On `streaming` and `queued` the reply waits for its turn's events. On `redirected` or `steered` the server folded the text into the running turn, so the system SHALL end the new reply's placeholder without an error and leave the user's message in place.

#### Scenario: Folded into the running turn

- **WHEN** `prompt.submit` is answered with status `redirected` or `steered`
- **THEN** no thinking placeholder stays behind for that message, nothing is marked failed, and the running turn's reply goes on streaming

#### Scenario: Queued by the server

- **WHEN** `prompt.submit` is answered with status `queued`
- **THEN** the reply stays thinking until the server starts that turn with `message.start`

#### Scenario: The reply arrives before the submit answer

- **WHEN** `message.start` and deltas arrive before `prompt.submit` is answered
- **THEN** they stream into the reply as usual

### Requirement: Reconnecting a live reply

The system SHALL record the highest `seq` seen for each runtime session. When the socket drops while a reply is in flight, the system SHALL reconnect, rebind with `session.resume`, and replay missed events with `session.events.since`. Events at or below the recorded `seq` SHALL NOT be delivered twice. When replay cannot cover the gap, the reply SHALL be rebuilt from the server's state.

#### Scenario: Replay fills the gap

- **WHEN** the socket drops after event 7 of a running turn and the server's ring holds events 8 to 12
- **THEN** the system reconnects, rebinds the session, delivers events 8 to 12 once each, and goes on with live events from 13

#### Scenario: Live events overlap the replay

- **WHEN** live events arrive after rebinding while the replay is still being read
- **THEN** they are held until the replay is delivered, and any event whose `seq` was already delivered is dropped

#### Scenario: Replay truncated or server restarted

- **WHEN** `session.events.since` reports `truncated`, or its `epoch` differs from the one the recorded seqs were seen under
- **THEN** no replayed event is delivered, the reply's text is replaced by the resume result's `inflight.assistant` while the turn runs, or by the thread's stored messages read over REST once it ended
- **AND** live events the server sent after its `inflight` snapshot are still delivered on top of it, so no text streamed during the reconnect is lost; text the snapshot may already hold is delivered at most twice, never dropped

#### Scenario: Turn ended while disconnected

- **WHEN** the resume result reports `running` false after a drop
- **THEN** the replayed events up to the completion are delivered, and when the completion is not among them, the reply ends with the last stored assistant message, as before

#### Scenario: Requests open across the drop

- **WHEN** the resume or replay result lists `open_requests`
- **THEN** each is shown once, keyed by its id, and a card already shown for that id is not duplicated

#### Scenario: Backoff

- **WHEN** reconnecting fails
- **THEN** the system waits a jittered, growing delay (300 ms base, 15 s cap) between attempts, and after 5 attempts or 60 seconds marks the reply as broken

### Requirement: Connection heartbeat

The system SHALL send `gateway.ping` every 15 seconds on an open connection while a reply is in flight or a thread is listened to, and SHALL treat the connection as dead when no frame of any kind has arrived for 45 seconds.

#### Scenario: Quiet but alive

- **WHEN** no event arrives for 30 seconds but each ping is answered
- **THEN** the connection stays open

#### Scenario: Dead socket

- **WHEN** no frame arrives for 45 seconds
- **THEN** the connection is closed, which starts a reconnect for any reply in flight

#### Scenario: Gateway without ping

- **WHEN** `gateway.ping` is answered with a JSON-RPC error
- **THEN** that answer counts as a sign of life

### Requirement: Turns the user did not submit

The system SHALL show a turn Hermes runs on a thread without a prompt from this app, such as a crash auto-continue after a resume or a goal continuation, as a reply in that thread, while the thread is open or listened to.

#### Scenario: Auto-continue after resume

- **WHEN** a resume reports `auto_continue` and a turn starts that the app did not submit
- **THEN** a new reply appears in the thread and streams as any other
- **AND** while that turn runs ahead of a prompt the user sent, the approvals and questions it raises are shown on the reply in front and can be answered, and that reply says Hermes is finishing the interrupted turn until the turn ends
- **AND** the turn's text appears in a reply of its own when the send ends

#### Scenario: Missed start of a chained turn

- **WHEN** after a completed reply the session's deltas or tool events arrive without a `message.start`
- **THEN** a new reply is opened for them instead of dropping them

#### Scenario: Two starts for one continuation

- **WHEN** a goal continuation sends `message.start` twice before its completion
- **THEN** one reply is shown

### Requirement: Thread moved by compression

The system SHALL follow a thread to its new stored session when `session.info` reports a `stored_session_id` different from the thread's id, so later sends, history reads and stops use the new id.

#### Scenario: Compression rotates the stored id

- **WHEN** `session.info` reports `stored_session_id` "stored-2" for a thread known as "stored-1", whether `running` is true or false
- **THEN** the thread keeps its place, title and transcript, and the next send resumes "stored-2"
- **AND** a reply still streaming is not ended by that report

### Requirement: Withdrawn approvals

The system SHALL lock an approval card as expired when an `approval.cancelled` broadcast names its request, or names its session without listing request ids. A broadcast for another session SHALL change nothing.

#### Scenario: Approvals cancelled by an interrupt

- **WHEN** `approval.cancelled` arrives with the reply's session id and the request's id in `request_ids`
- **THEN** that card is locked as expired

#### Scenario: Another session

- **WHEN** `approval.cancelled` names another session
- **THEN** no card changes

### Requirement: Reply status line

The system SHALL show what a thinking reply waits on in place of "Thinking…": "Compacting the conversation…" for `status.update` of kind `compacting`, and the text of a `thinking.delta` that is an explained provider wait (it starts with ⏳, ⚠, ↻ or ⚙ followed by a phrase such as "waiting on", "loading", "no output", "rate limited" or "provider overloaded"). The next delta, tool event, completion or error SHALL clear it.

#### Scenario: Compacting

- **WHEN** a reply is thinking and `status.update` arrives with kind `compacting`
- **THEN** the indicator reads "Compacting the conversation…" until the next delta, tool event or completion

#### Scenario: Explained provider wait

- **WHEN** `thinking.delta` arrives with "⏳ waiting on local-model — 30s with no output yet"
- **THEN** the indicator shows that text
- **AND WHEN** a `message.delta`, `reasoning.delta`, `tool.start`, `message.complete` or `error` follows
- **THEN** the indicator reads "Thinking…" again, or is gone with the placeholder

#### Scenario: Spinner noise

- **WHEN** `thinking.delta` arrives with text that is not an explained wait, such as "◉_◉ cogitating..."
- **THEN** the indicator is unchanged, and an explained wait shown before is cleared

#### Scenario: Other status kinds

- **WHEN** `status.update` arrives with a kind other than `compacting`
- **THEN** the indicator is unchanged
