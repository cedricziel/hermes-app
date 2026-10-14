# Watch Specification

## Purpose

Describes the watchOS companion app and what it asks of the phone: how the watch lists chats, reads a chat and sends a message by relaying every request through the paired phone, which holds the session and the dashboard connection; how chats are identified across Hermes profiles; the limits and timeouts of the relay; what happens when the agent asks for something the watch cannot answer; and how a failure is worded. The watch has no network of its own and holds no token. Notifications for a turn sent from the watch are described in the notifications spec.

## Requirements

### Requirement: Relay through the phone

The system SHALL let the watch app read and send chats by asking the paired phone, which holds the signed-in session and the connection to the Hermes dashboard. The watch SHALL NOT hold tokens, and SHALL hold the server address only to pass it on for Handoff, never to connect to it. The phone SHALL serve the watch from whoever is signed in on the phone at that moment. A request is a `threads`, `messages`, `send` or `transcribe` operation, and the answer is either success or one of the error codes in "Watch errors". The relay SHALL exist on iOS only.

#### Scenario: Signed out on the phone

- **WHEN** the watch asks for anything while nobody is signed in on the phone
- **THEN** the phone answers `signed_out` and the watch tells the user to sign in on the iPhone first

#### Scenario: Unknown or malformed request

- **WHEN** the phone gets an operation it does not know, or one missing what it needs (a `messages` request without a thread id, a `send` with blank text, a `transcribe` without audio)
- **THEN** it answers `bad_request`

### Requirement: Watch relay diagnostics

When iPhone telemetry is enabled, the system SHALL export `watch.request.started` and `watch.request.completed` events for each request received by the Dart relay. Both events SHALL include the operation and current phone authentication state. The completion event SHALL include the result code and elapsed milliseconds, and for a transcribed voice message the engine that transcribed it (`device` or `hermes`). Unknown operations SHALL be recorded as `unknown`. Events SHALL NOT include message text, audio, locale, thread identifiers, tokens, or request payloads. A telemetry failure SHALL NOT prevent the relay from replying.

The watch SHALL write local Apple logs for activation, reachability changes, request starts, reply results, and delivery failures. The native iPhone relay SHALL write local Apple logs for activation, background-task expiry, a missing Dart handler, and invalid Dart replies. These local logs SHALL NOT contain request payloads or exception messages.

When the phone cannot read its saved session from secure storage, it SHALL export `auth.session.read_failed` through its configured event logger, with the exception type only. The stored session SHALL remain untouched.

#### Scenario: Signed-out relay reply

- **WHEN** the phone answers a watch request with `signed_out` while telemetry is enabled
- **THEN** the completion event records `signed_out`, the phone authentication state, and elapsed milliseconds

#### Scenario: Voice message transcribed on the phone

- **WHEN** the phone transcribes a watch voice message with the on-device recognizer while telemetry is enabled
- **THEN** the completion event records `transcribe`, `ok` and the engine `device`, without the text or the audio

#### Scenario: Secure storage unavailable

- **WHEN** secure storage throws while the phone restores its session
- **THEN** the phone records `auth.session.read_failed` without token contents or exception details

#### Scenario: Watch cannot deliver a request

- **WHEN** WatchConnectivity fails to deliver a request to the phone
- **THEN** the watch writes a local delivery-failure log with the operation and numeric error code

### Requirement: Watch thread list

The system SHALL answer a `threads` request with at most 20 of the most recent chats of the active Hermes profile, in the order the dashboard lists them. Each carries an id, a title, the time it was last active (whole seconds) and whether it is pinned. The watch SHALL show each title on up to two lines, mark pinned chats with a pin, refresh on pull, and offer a control to start a new chat. It SHALL show "No chats yet." for an empty list.

#### Scenario: Recent chats

- **WHEN** the watch app opens and the profile has chats
- **THEN** the chats appear most recent first, with pinned ones marked

#### Scenario: More chats than fit

- **WHEN** the dashboard returns more than 20 chats, for example because it appends every pinned chat to a page
- **THEN** only the first 20 are sent to the watch

#### Scenario: Row without an id or title

- **WHEN** a row the watch receives has no id or no title
- **THEN** the watch skips that row and shows the rest

### Requirement: Profile-scoped thread ids

The system SHALL bind each watch thread ID to an opaque phone-issued context, the Hermes profile, and session ID. The context SHALL identify the canonical server and verified account owner without exposing either value to the watch. The watch SHALL treat thread IDs as opaque and return them unchanged. Historical-profile threads SHALL remain valid within the same current context; active-profile changes SHALL affect new chats and listings, not redirect existing chats. A malformed ID SHALL return `bad_request`. A stale context SHALL return `context_changed`, and no read or send SHALL reach Hermes. IDs in the old `<percent-encoded profile>/<session id>` format SHALL be rejected rather than rebound to the current owner.

#### Scenario: Profile switched since the list was loaded

- **WHEN** the active profile changes and the watch opens a chat listed under the previous profile in the current context
- **THEN** the phone reads or continues the chat under its original profile
- **AND** a new chat uses the current active profile

#### Scenario: Same session ID in different owners

- **WHEN** two servers or accounts contain the same profile and session ID
- **THEN** their watch IDs differ
- **AND** an ID from the previous context cannot read or send in the new context

#### Scenario: Legacy unbound thread

- **WHEN** the phone receives a profile-only thread ID from an older watch
- **THEN** it rejects the request before backend access
- **AND** the updated watch refreshes its context and list rather than retrying the legacy ID

#### Scenario: Same session id in two profiles

- **WHEN** two profiles each have session `s1` under the same context
- **THEN** the watch sees different IDs and each request reads or writes its original profile

### Requirement: Reading a chat on the watch

The system SHALL answer a `messages` request with the last 20 messages of the chat, oldest first, each with an id, a role (user or assistant), its text and its time. A text longer than 4000 characters SHALL be cut there and end with an ellipsis. The watch SHALL show the messages in order and show an indicator while they load.

#### Scenario: Long chat

- **WHEN** a chat holds 30 messages
- **THEN** the watch receives the last 20, in order

#### Scenario: Very long message

- **WHEN** a message holds 5000 characters
- **THEN** the watch receives its first 4000 characters and an ellipsis

### Requirement: Sending from the watch

The system SHALL send a message the user dictates or types on the watch into the chosen chat, or into a new chat when none is chosen, in the active Hermes profile. The text SHALL be trimmed and a blank text SHALL NOT be sent. The phone SHALL answer once the reply is complete, with the chat's thread id, the final text and whether the turn ended in failure; the reply SHALL NOT stream to the watch. When a turn that did not fail completes with a blank final text, the phone SHALL answer with the text that had streamed, or, when nothing streamed either, with "Hermes replied without any text.", so the watch never shows an empty reply; such a reply is not a failure, as for its notification. While waiting the watch SHALL show the user's message and "Hermes is thinking…", and SHALL NOT send another message. The phone SHALL give up and answer `failed` when no event arrives for 60 seconds. When a send fails the watch SHALL remove the message it showed, keep its text, show the reason and offer "Try again", which sends the same text.

#### Scenario: New chat

- **WHEN** the user sends "Hello" from the new chat control
- **THEN** the phone starts a chat, answers with its thread id and the reply, and the watch shows both messages and sends the next one into that chat

#### Scenario: Reply without text

- **WHEN** a turn completes without failure, its final text is blank and nothing streamed
- **THEN** the phone answers success with `failed` false and the text "Hermes replied without any text."

#### Scenario: Final text empty after streaming

- **WHEN** a turn completes without failure with a blank final text after "Hi there" streamed
- **THEN** the phone answers with "Hi there"

#### Scenario: Failed turn

- **WHEN** the reply ends in failure with the message "Model unavailable"
- **THEN** the watch shows that message as the reply

#### Scenario: Connection drops

- **WHEN** the connection to the dashboard drops or the stream ends before a reply
- **THEN** the phone answers `failed` and the watch offers to try again with the same text

#### Scenario: Silent gateway

- **WHEN** no event arrives for 60 seconds
- **THEN** the phone gives up and answers `failed`

### Requirement: Requests the watch cannot answer

The system SHALL keep a send going when the agent asks for an approval or a question's answer during a turn sent from the watch. The phone SHALL post the actionable notification of the notifications spec, which watchOS mirrors, so the user can answer on the watch or the phone. When the watch's request says it can be answered this way (`waits: true`) and an answerable notification was posted, the phone SHALL answer the send at once with success, the chat's thread id and `waiting` set to `approval` or `question`, without the command or the question. Otherwise (an older watch, notifications off or not allowed, App Lock on) the send SHALL end as for a request the watch cannot answer; the notification is posted for an older watch all the same. The watch SHALL then show "Waiting for your approval" or "Hermes has a question" in place of "Hermes is thinking…" and send the same request again with the same send id, the chat's thread id and `retry` set, for at most 20 minutes. A phone that no longer knows a send asked with `retry` (for example because iOS ended the app meanwhile) SHALL NOT send the prompt again: it SHALL answer with the chat's latest reply, or "Hermes is still replying. Open the chat again in a moment." when it has none, and `failed` when the retry names no chat. A retry of a waiting send SHALL be answered with the final reply once the turn completes, at once with the new state when it differs from the one the watch was told last (`working` once the turn goes on), and otherwise with the same waiting answer after 20 seconds. The send SHALL wait while any of the turn's requests is open: an expired or withdrawn request leaves the others, and the turn going on closes a request only when it is the only one open. When a retry fails, the watch SHALL keep the message and offer "Try again", which asks again with `retry` instead of sending the message again. While it waits the watch SHALL offer "Stop waiting", which ends the wait on the watch, keeps the message and lets the user send again. While the send waits the phone SHALL give up only after 15 minutes without an event, instead of 60 seconds. Any event that continues the turn SHALL end the waiting state.

The system SHALL end a send at once when the agent asks for something the app cannot answer (a secret value, a sudo password or a vault prompt) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include anything about what is asked for. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the phone answers with `waiting` set to `approval`, the watch shows "Waiting for your approval", and no command text reaches the watch's reply

#### Scenario: Approved from the notification

- **WHEN** the user picks "Allow once" on the mirrored notification and the turn completes with "Done."
- **THEN** the watch's next retry of the send gets "Done." as the reply

#### Scenario: Still waiting

- **WHEN** a waiting send is retried and nothing happens for 20 seconds
- **THEN** the phone answers with the same waiting state and the watch keeps waiting

#### Scenario: Phone app ended while waiting

- **WHEN** iOS ends the phone app while a watch send waits, and the watch asks again with `retry`
- **THEN** the phone reads the chat instead of sending the prompt again

#### Scenario: Stop waiting

- **WHEN** the user picks "Stop waiting" while the watch shows "Waiting for your approval"
- **THEN** the message stays, the watch asks the phone no more, and the user can send another message

#### Scenario: Older watch

- **WHEN** a watch that does not send `waits` sends a message and the agent asks for approval
- **THEN** the send ends with the fixed text, as before

#### Scenario: Question during a watch turn

- **WHEN** the agent asks a clarifying question during a turn sent from the watch
- **THEN** the watch shows "Hermes has a question"

#### Scenario: Sudo password during a watch turn

- **WHEN** the agent asks for a sudo password during a turn sent from the watch
- **THEN** the send ends at once with the fixed text and the connection is closed

### Requirement: Watch errors

The system SHALL report a failed request with one of these codes and the watch SHALL word each for the user. `signed_out`: "Sign in to Hermes on your iPhone first." with no retry. `unavailable`, answered by the iOS app when Dart has not registered its handler yet: "Open Hermes on your iPhone, then try again." `phoneUnreachable`, raised on the watch when its connection to the phone is not active within about three seconds, the phone cannot be reached, or delivery fails: "Can't reach your iPhone." `failed`, for any other failure, including a request whose reply is malformed: "Something went wrong." `bad_request` reaches the watch as `failed`. Every error except `signed_out` SHALL offer "Try again".

#### Scenario: Phone out of reach

- **WHEN** the watch is not connected to its phone
- **THEN** it shows "Can't reach your iPhone." with a "Try again" control

#### Scenario: Phone app not ready

- **WHEN** the phone's Hermes app has not registered its handler
- **THEN** the phone answers `unavailable` and the watch asks the user to open Hermes on the iPhone

### Requirement: Handoff from a watch chat

The phone SHALL add `serverUrl` (the canonical server address), `profile` and `sessionId` (the raw session id, not the bound thread id) to each chat of a `threads` answer and to every `send` answer that names a thread, and SHALL leave all three out when it has no server address or no profile. While a chat that has them is open, the watch SHALL advertise an activity of the Handoff type the apps declare (`HERMES_HANDOFF_TYPE`) whose user info is the apps' version 1 payload (`version`, `serverUrl`, `profile`, `threadId` = the session id), and SHALL withdraw it when the chat closes. The activity SHALL carry no title text beyond the generic one, no message text and no credentials. A chat without the fields SHALL NOT be advertised.

#### Scenario: Open a listed chat

- **WHEN** the user opens a chat that the phone listed with its server address and profile
- **THEN** the watch advertises a Handoff activity with that address, profile and the chat's raw session id, and an iPhone or Mac signed in to that server can continue it

#### Scenario: Chat started on the watch

- **WHEN** the user's first message starts a new chat and the phone answers it
- **THEN** the answer carries the fields and the watch advertises the chat without reloading the list

#### Scenario: Close the chat

- **WHEN** the user leaves the chat
- **THEN** the activity is withdrawn

#### Scenario: Phone cannot name the server or profile

- **WHEN** the phone's answer has no `serverUrl` or no `profile`
- **THEN** the watch advertises nothing for that chat

### Requirement: Quick replies and double tap

The watch SHALL show the fixed quick replies "Continue", "Yes", "No" and "Summarize" above the reply field of a chat. Tapping one SHALL send its text as a message under the rules of "Sending from the watch", and the quick replies SHALL be disabled whenever the field is, in particular while a reply is pending. They SHALL NOT be shown while a voice message is being recorded. On watchOS 11 and later, the double-tap gesture SHALL start a voice message when the chat is idle, and stop and send the recording while one is being made; it SHALL do nothing while the voice button is disabled.

#### Scenario: Tap a quick reply

- **WHEN** the user taps "Yes" in an idle chat
- **THEN** the watch sends "Yes" into that chat and shows "Hermes is thinking…"

#### Scenario: Reply pending

- **WHEN** a reply is pending
- **THEN** the quick replies are disabled and a tap sends nothing

#### Scenario: Double tap while idle

- **WHEN** the user double taps in an idle chat
- **THEN** a voice message starts recording

#### Scenario: Double tap while recording

- **WHEN** the user double taps while recording
- **THEN** the recording stops and is sent as a voice message

### Requirement: Watch voice messages

The system SHALL let the user record a voice message of up to 30 seconds on the watch and send what was heard in it as the next message. The watch SHALL send the recording to the phone as a `transcribe` request. While the phone's Dictation setting uses the on-device recognizer, the phone SHALL transcribe the recording with it in the device language, and the recording SHALL NOT reach the Hermes server. When the Dictation setting is Hermes, or the on-device recognizer cannot transcribe the recording (the language has no on-device recognition, its model is not installed, or recognition fails), the phone SHALL send the recording to the active profile's speech-to-text provider. When nothing was heard, the watch SHALL report that no speech was heard and SHALL send nothing.

#### Scenario: Transcribed on the phone

- **WHEN** the phone's Dictation setting is "On this device", the model for the device language is installed, and the user records "Remind me to call Sam" on the watch
- **THEN** the watch sends "Remind me to call Sam" and the Hermes server receives no `/api/audio/` request

#### Scenario: Model not installed

- **WHEN** the phone's Dictation setting is "On this device" but the model for the device language is not installed
- **THEN** the phone sends the recording to the active profile's speech-to-text provider

#### Scenario: Hermes engine chosen

- **WHEN** the phone's Dictation setting is "Hermes"
- **THEN** the phone sends the recording to the active profile's speech-to-text provider without trying the on-device recognizer

#### Scenario: Phone app woken by the watch

- **WHEN** the watch's request starts the phone app before it has read the saved Dictation setting
- **THEN** the phone reads the setting first and transcribes with the engine it names

### Requirement: Complications and Smart Stack widget

The watch app SHALL offer a Voice Chat complication in the `accessoryCircular` and `accessoryCorner` families, and a chat status complication in the `accessoryRectangular` family, which is also the Smart Stack widget. Voice Chat SHALL open the watch app on a new voice message. The chat status SHALL show the title of the latest chat and one of "Working", "Waiting for you", "Reply ready" and "Failed", and a tap SHALL open that chat; with nothing to show it SHALL say "No recent chat" and a tap SHALL open the app.

The phone SHALL send the watch the latest turn's status when a turn starts, waits for the user (an approval, a question, a request only the phone can answer), or ends, for a reply sent from the phone and for a turn sent from the watch. It SHALL send it with `transferCurrentComplicationUserInfo` while the day's budget lasts, and with `updateApplicationContext` otherwise, and only when the status changed. The status SHALL consist of the state, a timestamp, an ordering number, the chat's title and the watch's thread id for the chat. The title SHALL be one the gateway or the server gave the chat, never one made from the prompt, a file name, a command or the first message. It SHALL NOT contain message, command, question or reply text. A chat that finished SHALL show the next turn it opens, or a request it raises, as working or waiting. A request the watch cannot answer in a turn it sent SHALL leave the chat waiting. The watch SHALL ignore a message older than the newest it applied, and the phone SHALL spend `transferCurrentComplicationUserInfo` on a change of state (a stop, a removed chat and a sign-out included) and on taking a title off for App Lock, but not on a new title or chat id. A chat that keeps a name SHALL keep it when a retry or an edit empties its messages. A working or waiting turn that was not renewed for 30 minutes SHALL not be shown, and a new turn on a chat SHALL replace the earlier ones of that chat. A turn waiting for the user SHALL be the one shown, before any other. A reply the user stopped SHALL NOT be shown. Signing out SHALL clear the status. While App Lock is on, the status SHALL carry the state and timestamp only.

The watch app SHALL keep the received status in an App Group shared with the widget extension and reload the widget timelines when a status arrives. The widget SHALL raise its Smart Stack relevance while the turn waits for the user and for ten minutes after a turn ends, SHALL lower it afterwards, and SHALL treat a working or waiting status that was not renewed for 30 minutes as nothing to show, since a suspended phone app cannot report the end of a turn.

#### Scenario: Reply working

- **WHEN** the user sends a prompt in chat "Backup" from the phone
- **THEN** the watch's chat status shows "Backup" and "Working"

#### Scenario: New chat not yet named

- **WHEN** the user starts a chat with the prompt "my tax return" from the phone
- **THEN** the status carries no title until the gateway names the chat, and no payload contains the prompt

#### Scenario: Follow-up turn

- **WHEN** a chat shows "Reply ready" and Hermes continues it on its own
- **THEN** the chat status shows "Working" again

#### Scenario: Retry of a single-turn chat

- **WHEN** the user retries the only turn of a chat the server has named "Run failure"
- **THEN** the status still carries "Run failure", never the prompt

#### Scenario: Watch turn left waiting

- **WHEN** a turn sent from the watch ends because the watch cannot answer its request, and a later turn starts on the same chat
- **THEN** the chat status shows the later turn

#### Scenario: Messages out of order

- **WHEN** the watch receives a status after a newer one
- **THEN** it keeps the newer one

#### Scenario: Waiting for an approval

- **WHEN** the agent asks for approval to run `rm -rf build` in a turn
- **THEN** the chat status shows "Waiting for you", ranks first in the Smart Stack, and neither the command nor any other text is sent to the watch

#### Scenario: Turn sent from the watch

- **WHEN** the user sends a message from the watch and the reply completes
- **THEN** the chat status shows "Reply ready" for that chat

#### Scenario: App Lock on

- **WHEN** App Lock is on and a reply starts
- **THEN** the phone sends the state and timestamp, and the chat status shows "Working" without a title

#### Scenario: Phone never reported the end

- **WHEN** the status says "Working" and was last renewed 40 minutes ago
- **THEN** the chat status shows "No recent chat"

#### Scenario: Circular complication

- **WHEN** the user taps the circular or corner complication
- **THEN** the watch app opens a new chat ready to record a voice message

#### Scenario: Signed out

- **WHEN** the user signs out on the phone
- **THEN** the phone clears the status and the chat status shows "No recent chat"

### Requirement: Watch local send-attempt isolation

After the user stops waiting, the watch SHALL ignore every subsequent response belonging to that stopped local attempt. A stale response SHALL NOT append messages, replace the thread or Handoff target, change the current phase, restore retry content, or start another poll. Stop waiting SHALL preserve the accepted user message and SHALL NOT cancel the server turn. Reloading the chat can show its eventual answer through the normal history request.

This behavior SHALL use the existing phone `send` relay, including `threadId`, `text`, `sendId`, `retry`, and `waits`, and existing complete or `waiting` replies. It SHALL require no additional Hermes RPC, REST route, response field, or backend version beyond the existing watch relay requirements.

#### Scenario: Completion after Stop waiting

- **WHEN** the user stops an approval wait and its pending poll later returns a successful reply
- **THEN** the watch leaves messages, metadata, and the current phase unchanged and sends no further poll

#### Scenario: Old reply after a new send

- **WHEN** a new send starts after Stop waiting and the old attempt then returns a completion, failure, or waiting state
- **THEN** only the new attempt can update the conversation

#### Scenario: Answer available in history

- **WHEN** the user reloads the chat after the stopped server turn completes
- **THEN** the watch shows the answer returned by history without resuming the stopped local polling attempt

### Requirement: Watch context handshake and isolation

A content-free `session` relay operation SHALL return `ok`, `protocolVersion: 2`, a durable session `revision`, and an opaque `contextId` only after the phone is ready. Auth restoration SHALL return `unavailable` until ready; confirmed absence SHALL return `signed_out`. The watch SHALL obtain this context before its first content operation. Every `threads`, `messages`, `send`, and `transcribe` request and every success reply SHALL carry `contextId` and the session `revision`. A missing or mismatched context SHALL return `context_changed` before private data access, remembered-reply lookup, transcription, or gateway submission. The watch SHALL clear private state upon a new context or `context_changed`, obtain a fresh handshake, and offer fresh navigation without automatically resubmitting a draft.

The context SHALL survive normal phone restarts and token refresh for the same verified owner. Sign-out, confirmed expiry, server departure, or a verified owner change SHALL rotate the context before accepting new work. Without an authenticated account, an ungated dashboard SHALL use a separate context tied to the canonical server. Unknown owner identity on a gated server SHALL NOT authorize a context. The watch SHALL scope saved lists, messages, drafts, audio, send state, status, and navigation to the context. Late results or invalidations for a previous context SHALL NOT replace the current context or its data. Each context publication SHALL carry a durable monotonically increasing revision so native delivery order cannot roll state backward.

#### Scenario: New-chat send crosses an account switch

- **WHEN** a draft for a new chat was prepared under context A and the phone now serves context B
- **THEN** the phone returns `context_changed` without submitting the draft
- **AND** the watch clears the draft and reloads the current context

#### Scenario: Refresh and restart retain ownership

- **WHEN** the phone refreshes tokens or restarts with the same verified owner and no intervening departure
- **THEN** the context remains stable and valid retries retain their owner

#### Scenario: Delayed context update

- **WHEN** the watch has accepted revision 8 and receives revision 7
- **THEN** it ignores revision 7 without restoring previous data or clearing revision 8 data

#### Scenario: Cold offline launch

- **WHEN** the watch cannot handshake but has previously verified cached data for one context
- **THEN** it may display that context's saved data with existing offline behavior
- **AND** it cannot submit requests until a current context handshake succeeds

#### Scenario: Upgrade with existing files

- **WHEN** an updated watch starts with caches that have no context
- **THEN** it removes those caches before displaying them and requests a new handshake

### Requirement: Watch identity uses the existing Hermes contract

The context protocol SHALL add no Hermes route or RPC method and SHALL retain the existing minimum supported Hermes version. Gated account identity SHALL use the current `GET /api/auth/me` identity fields `user_id`, `org_id`, and provider as parsed by the app, together with its canonical server URL. Ungated readiness SHALL use the existing `GET /api/status` `auth_required: false` response. No watch context SHALL authorize backend work independently of current phone authentication. Diagnostics SHALL NOT contain contexts, revisions, thread IDs, owner fields, URLs, or credentials.

#### Scenario: Existing backend with protocol version 2 watch

- **WHEN** the watch completes the version 2 handshake against a phone connected to an already supported Hermes server
- **THEN** normal chat reads and sends require no backend upgrade

### Requirement: Durable phone watch send journal

For a context-valid protocol-version-2 send with a nonempty `sendId`, the phone SHALL persist a protected record before any gateway call for that send. Records SHALL be keyed by context, revision, and send identity and SHALL bind the original profile, optional thread, and payload fingerprint. Reusing an identity with a different payload, original timestamp, or target SHALL return `bad_request` without dispatch. Concurrent identical requests SHALL join one live attempt. Persistence failure SHALL prevent new dispatch.

The phone SHALL persist the exact completed reply before acknowledging completion to the watch. After restart, an existing nonterminal dispatch record SHALL NOT authorize a new submission. A missing, expired, or damaged record on a status-only retry SHALL NOT authorize submission either. Authentication and current context validation SHALL precede journal access. Logout and context departure SHALL purge records and prevent late callbacks from restoring them. Failed deletion SHALL leave a persistent invalidation tombstone that prevents retained private records from being reloaded.

#### Scenario: Phone restarts after dispatch

- **WHEN** Hermes may have accepted a send and the phone restarts before saving completion
- **THEN** repeating its identity checks status and does not submit the prompt again

#### Scenario: Completion saved before lost reply

- **WHEN** the phone saves a completed result but its reply to the watch is lost
- **THEN** a status request for that identity returns only that saved result

#### Scenario: Journal write fails

- **WHEN** the phone cannot persist the dispatch record
- **THEN** it returns a non-dispatch failure and sends nothing to the gateway

#### Scenario: Reused identity changes payload

- **WHEN** a request reuses an existing send identity with different text or a different target
- **THEN** the phone returns `bad_request` and does not submit either request again

### Requirement: Safe watch send-state protocol

The protocol-version-2 session handshake SHALL advertise `sendState: true` when durable send-state lookup is supported. A `send` request with `retry: true` SHALL be status-only and SHALL never create a new gateway submission. A normal completed response SHALL carry the exact saved text, failure flag, optional tools, and bound thread metadata for that identity. Nonterminal responses SHALL contain `recoveryState` set to `pending`, `uncertain`, or `not_sent`, without assistant reply text. `pending` SHALL mean the phone still owns a live attempt. `uncertain` SHALL mean completion or delivery cannot be established, including a recovered dispatch record or missing record. `not_sent` SHALL be returned only when the phone proves it did not dispatch. Existing approval/question `waiting` replies SHALL retain their meaning and polling timing.

The phone SHALL NOT identify a send's answer by selecting the latest assistant history row, matching prompt text, or using timestamps. A saved result from the original attempt is sufficient proof. An optional accepted prompt row receipt is not proof of its final answer. The journal SHALL retain completed payloads for at most seven days and SHALL evict the oldest terminal payloads first under storage pressure. Active attempts SHALL remain retained. Detached uncertain records SHALL expire after seven days or explicit Forget recovery. The journal SHALL bound full records to 100 per context and compact identity tombstones to 1000 per context. A context-valid `forgetSend` request carrying sendId SHALL release a detached recovery record while retaining any still-valid non-dispatch tombstone. It SHALL NOT cancel an active server turn; a still-active record SHALL be retained until detached or complete. A genuinely full journal SHALL refuse new dispatch with a retryable capacity explanation. Status queries for expired or forgotten identities SHALL remain uncertain and SHALL never dispatch.

A first-dispatch request SHALL contain its original `createdAt` timestamp as UTC Unix milliseconds. A missing or malformed createdAt SHALL be rejected before dispatch. The phone SHALL accept first dispatch only when that timestamp is no more than ten minutes old and no more than sixty seconds ahead of phone time. Repeated requests SHALL retain the same timestamp with the same identity. Evicting or forgetting a record SHALL retain a compact non-dispatch tombstone until its first-dispatch validity window expires. Capacity pressure SHALL NOT remove a still-valid tombstone. An expired normal request SHALL be rejected without dispatch. Status-only requests SHALL remain valid regardless of age. These limits SHALL be client relay protections, not backend delivery guarantees. Clock disagreement SHALL explain that the user must check device time; the client SHALL NOT refresh the original timestamp and automatically redispatch.

The existing backend contract SHALL remain `session.create`, `session.resume`, and `prompt.submit` on `/api/ws`, with final streamed completion events. `prompt.submit` accepts session and text and can return `status` and optional `user_row_id`; the optional row ID SHALL be recorded only when present. No new Hermes route or RPC, idempotency key, or numeric minimum Hermes version SHALL be assumed. The minimum supported Hermes version SHALL remain unchanged, and missing receipt fields SHALL use the uncertain fallback. Existing history access through `GET /api/sessions/{sessionId}/messages` SHALL be navigation only, never inferred completion.

#### Scenario: Forgotten identity has an older assistant message

- **WHEN** a status request names an unknown identity in a chat whose latest message is an assistant reply
- **THEN** the phone returns `uncertain` without returning that message as the send's answer

#### Scenario: Live send remains pending

- **WHEN** a status request names a live send whose result is not complete
- **THEN** the phone returns pending or its current approval/question waiting state without submitting another prompt

#### Scenario: Optional receipt absent

- **WHEN** a supported Hermes backend returns no `user_row_id`
- **THEN** the send can complete normally and unresolved recovered delivery remains uncertain

#### Scenario: Journal full

- **WHEN** 100 active or young unresolved records leave no terminal payload to evict
- **THEN** the phone refuses a new dispatch and preserves existing recovery records

#### Scenario: Delayed normal request after eviction

- **WHEN** a normal request arrives for an evicted identity within its initial validity window
- **THEN** its compact tombstone prevents dispatch
- **AND** after the window expires the original timestamp still prevents dispatch

#### Scenario: Terminal payload makes room

- **WHEN** a new dispatch would exceed full-record capacity and an old terminal payload exists
- **THEN** the phone evicts that payload, preserves any still-valid identity tombstone, and admits the new send

#### Scenario: Detached uncertainty expires

- **WHEN** an unresolved detached record reaches seven days or the user forgets its recovery
- **THEN** the phone releases its full-record slot and later status checks remain uncertain without dispatch

### Requirement: Persistent watch pending-send identity

The watch SHALL persist the pending send's identity, context, revision, target profile/thread when known, text, original `createdAt`, and delivery state before attempting delivery. The same identity SHALL always retain its original timestamp. A restored send SHALL retain its original identity and SHALL issue only status requests after a fresh context handshake. The watch SHALL NOT turn a delivery error, sleep/wake, restart, or missing result into an automatic resend. Persistence failure SHALL prevent submission. Signed-out or departed-context pending data SHALL be purged, and stale asynchronous results SHALL NOT restore it.

The watch SHALL use the protocol-version-2 handshake and require `sendState: true` for this recovery flow. Every request and success response SHALL include the current context and revision. Missing recovery capability, unsupported protocol, or legacy unscoped pending records SHALL NOT authorize resubmission. An unsupported phone SHALL show an update-required state without presenting an unsafe Try again action. A normal restoration delay SHALL retain the current context's pending data without permitting delivery until readiness is established. Expired first-dispatch validity or device-clock disagreement SHALL show actionable guidance and SHALL NOT refresh the original timestamp or automatically dispatch a new identity.

#### Scenario: Watch restarts before acknowledgement

- **WHEN** the watch restarts after attempting to deliver a message and has no completed result
- **THEN** it restores the same identity and offers Check result without submitting the message again

#### Scenario: Context changes while checking

- **WHEN** a status response arrives for a context or revision that is no longer current
- **THEN** the watch discards it before displaying content or updating pending state

#### Scenario: Older phone lacks recovery capability

- **WHEN** the current handshake lacks `sendState: true`
- **THEN** the watch explains that the phone app needs updating and does not replay a restored send

### Requirement: User-controlled watch uncertain-delivery recovery

A send with pending or uncertain delivery SHALL remain visible as the user's outgoing message. The watch SHALL offer Check result using its original send identity and `retry: true`. A `pending` result SHALL display that Hermes is still working without inserting an assistant bubble. An `uncertain` result SHALL explain that delivery or completion cannot be confirmed, and SHALL offer Open chat when a bound thread is known. A missing thread SHALL not prevent the uncertainty explanation or explicit resend decision. Repeated status checks SHALL remain status-only.

Only a proven completed response for the original send identity SHALL become its assistant answer. Approval/question waiting replies SHALL remain actionable through the existing waiting workflow. A `not_sent` result SHALL offer retry using a new send identity because the original identity is terminal. An uncertain send SHALL enable Send again only after the user has attempted Check result in the current context. It SHALL submit only after a confirmation that the original message may already have reached Hermes and another submission can run the request twice. Confirmation SHALL create a new send identity and a new local attempt; cancellation SHALL dispatch nothing. The original uncertain message SHALL NOT be edited in place. A separate new draft can contain edited text, but submitting it as a replacement SHALL require the same duplicate-risk confirmation and a new identity. Forget recovery SHALL remove the local pending record and request release of its detached phone recovery record when reachable. It SHALL NOT cancel server work. The phone SHALL retain any still-valid non-dispatch tombstone.

This flow SHALL rely on the journal's existing `/api/ws` send contract and status-only phone relay. It SHALL add no Hermes route, RPC, or minimum backend version beyond existing watch support. The watch SHALL never interpret a latest assistant history message or the fixed still-replying placeholder as proof of this send's completion.

#### Scenario: Check result while still working

- **WHEN** the user checks a send and the phone returns `recoveryState: pending`
- **THEN** the outgoing message remains pending and no completed assistant bubble appears

#### Scenario: Uncertain resend confirmed

- **WHEN** the user chooses Send again for an uncertain message and confirms the duplicate-risk warning
- **THEN** the watch persists a new identity and submits one new request

#### Scenario: Uncertain resend cancelled

- **WHEN** the user cancels the duplicate-risk confirmation
- **THEN** no new request is dispatched and the original message remains available for status checking

#### Scenario: Proven saved completion

- **WHEN** Check result returns the journal's completed reply for the original identity
- **THEN** the watch displays that reply once and clears the corresponding pending send

#### Scenario: History contains another answer

- **WHEN** the user opens chat history during uncertain recovery and it contains a newer assistant message
- **THEN** the history remains ordinary chat content and does not silently mark the pending send completed

### Requirement: Watch session invalidation clears private state

The phone SHALL check current session availability before serving every relay operation, including remembered send replies. With no usable session it SHALL return `signed_out`, or `unavailable` while restoration is still pending, without returning private content. On confirmed sign-out or expiry it SHALL invalidate remembered sends and send a content-free invalidation to the watch. The watch SHALL process invalidation received through either application context or user info, and `signed_out` received through any operation, as the same cleanup event. Cleanup SHALL remove visible chats, messages, drafts, retry payloads, audio, handoff targets, persisted chat caches, and private status. Cleanup SHALL invalidate asynchronous work before deleting data so late replies cannot restore content or send a transcription. Session-state publications SHALL carry a durable monotonically increasing revision. The watch SHALL persist the last accepted revision, apply each revision once, and ignore older or equal publications. A usable session re-established after sign-out SHALL publish a newer revision before content replies. Cleanup SHALL persist a tombstone before disk deletion and refuse cache reads until deletion succeeds. Transient disconnection, pending restoration, and recoverable refresh failures SHALL NOT count as confirmed sign-out.

#### Scenario: Remembered reply after logout

- **WHEN** the watch retries a previously completed send after the phone signs out
- **THEN** the phone returns `signed_out` without the remembered reply
- **AND** the watch clears private state and shows sign-in guidance without retry

#### Scenario: Open cached conversation receives sign-out

- **WHEN** a conversation displays saved messages and its refresh returns `signed_out`
- **THEN** all private state disappears from memory and persistent cache
- **AND** the conversation displays only sign-in guidance

#### Scenario: Sign-out during transcription

- **WHEN** the watch learns of sign-out while recording or transcription is active
- **THEN** the watch stops recording, removes temporary audio, and discards any later transcription result
- **AND** no send occurs from that transcription

#### Scenario: Delayed reply after cleanup

- **WHEN** a request begun before invalidation completes after cleanup
- **THEN** neither the phone nor the watch returns, displays, or caches its private result

#### Scenario: Phone unreachable at logout

- **WHEN** the phone signs out while the watch cannot receive the invalidation
- **THEN** the phone retains the latest invalidation for eventual WatchConnectivity delivery
- **AND** the watch clears data when invalidation or `signed_out` arrives
- **AND** immediate remote erasure is not promised

#### Scenario: Foreground after queued invalidation

- **WHEN** the watch reopens with a queued session invalidation
- **THEN** it applies that invalidation before showing saved content
- **AND** it checks the phone session when reachable

### Requirement: Session cleanup preserves the existing backend contract

Session cleanup SHALL add no Hermes Agent route, RPC method, or required response field. It SHALL use the existing phone authentication state and watch property-list relay. The minimum supported Hermes version SHALL remain unchanged from the application's existing baseline. Cleanup diagnostics SHALL contain only fixed operation and reason names, flags, counts, and result codes, never content, identifiers, addresses, or credentials.

#### Scenario: Existing supported server

- **WHEN** the phone connects to a server supported before this change
- **THEN** session cleanup requires no backend update

#### Scenario: Previous logout arrives after sign-in

- **WHEN** the watch has accepted a newer usable-session revision and an earlier logout publication arrives
- **THEN** it ignores the earlier publication and keeps current-session data
