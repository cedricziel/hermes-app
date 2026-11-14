# Spec Delta

## ADDED Requirements

### Requirement: Context row in the Activity panel

The app SHALL show a Context row under "For reference" in the Activity panel when the server reports `context_used`, `context_max` and `context_percent`: a thin bar, the percentage and "about <used> of <max>" ("about" only when `context_estimated` is true). The row SHALL be absent when those fields are absent, and in conversation windows and the quick panel. It SHALL read the Session usage card's snapshot and start no second poll.

#### Scenario: Normal context

- **WHEN** usage reports 62% of 200,000 tokens with an estimate
- **THEN** the row reads "Context 62% · about 124k of 200k tokens" and has a bar at 62%

#### Scenario: Not measured yet

- **WHEN** a resumed chat has had no turn in this server process and usage carries no context fields
- **THEN** no Context row is drawn and nothing says unsupported

#### Scenario: Old server

- **WHEN** the server has no `session.usage`, or the usage answer carries no context fields
- **THEN** no Context row is drawn and chat remains usable

#### Scenario: Stored chat without a live session

- **WHEN** a chat was opened from history and no usage has been read
- **THEN** no Context row is drawn and the app does not resume the session to fill it

#### Scenario: Disconnected

- **WHEN** the connection closes
- **THEN** the row keeps its last values marked "Not up to date" and its actions are disabled

### Requirement: The meter does not nag

The Context row SHALL be neutral below 80%, SHALL add the words "Nearly full" with a warning icon at 80% or more, SHALL be emphasised in the error colour at 95% or more, and SHALL say "Full" at 100% or when more is used than the window. It SHALL NOT add a dot to the Activity button, a line to the strip above the transcript, a banner, a toast, a notification, a haptic, a badge, a widget or an App Intent entry, at any percentage.

#### Scenario: Fill rises past 95%

- **WHEN** the context reaches 97% during a reply
- **THEN** only the row in the Activity panel changes its wording and emphasis, and no other surface changes

#### Scenario: Over the window

- **WHEN** usage reports 212,000 used of a 200,000 window (the percentage clamped at 100)
- **THEN** the row reads "Full", "100%" and "about 212k of 200k tokens", with no motion

#### Scenario: Reduced motion

- **WHEN** reduce motion is on
- **THEN** the bar changes without animation

### Requirement: Context details

Tapping the row SHALL open Context details: the model, the percentage and counts as text, and one line per `session.context_breakdown` category with a friendly name and token count, largest first. Rule file paths SHALL NOT be shown. Numbers SHALL be called estimates when `context_estimated` is true. The breakdown SHALL be requested when details open, after a turn, a compaction and a compress, never on a timer.

#### Scenario: Breakdown loads

- **WHEN** the details open and the server returns eight categories
- **THEN** each is listed with its tokens and the list order is by tokens descending

#### Scenario: Breakdown is loading

- **WHEN** the request is in flight
- **THEN** the details show the known total and a "Reading what fills the context…" skeleton

#### Scenario: Breakdown fails

- **WHEN** `session.context_breakdown` fails or answers 5000
- **THEN** the details show the total and "Couldn't read what fills the context. Try again." with a Try again action, and the row stays

#### Scenario: Breakdown unsupported

- **WHEN** `session.context_breakdown` answers method-not-found
- **THEN** the details show the total and Compress only, with no category list and no error

### Requirement: Compression is offered at the right moment

The app SHALL show a one-line suggestion on the Context row ("Compress to make room?", Compress… and Not now) only at 85% or more, with the chat idle and no request waiting, and not when the percentage is a local estimate below 95. After Not now or a compress it SHALL show again only after the percentage fell below 60 and rose again. State is per thread, in memory.

#### Scenario: First time at 86% while idle

- **WHEN** the percentage becomes 86 and the chat is idle
- **THEN** the suggestion appears once on the row, and no other surface changes

#### Scenario: Dismissed

- **WHEN** the user chooses Not now and the percentage stays above 85
- **THEN** the suggestion does not return

#### Scenario: Busy chat

- **WHEN** the percentage is 90 while a reply runs
- **THEN** no suggestion shows until the chat is idle

#### Scenario: Estimate only

- **WHEN** the percentage is 88 and `context_source` is `local_estimate`
- **THEN** no suggestion shows

### Requirement: Manual compression

Context details SHALL offer "Compress conversation…" while the chat is idle and its runtime session is confirmed. A confirmation SHALL say older messages are replaced by a summary, a helper model writes it at the user's token cost, it cannot be undone, and the chat reloads. It SHALL offer an optional "Focus on" field behind Advanced and refuse a focus starting with `-` or `here`. The app SHALL send `session.compress` and SHALL NOT store or log the focus.

#### Scenario: The confirmation's buttons

- **WHEN** the compress confirmation opens
- **THEN** Cancel is the default and Compress is an outlined button, neither filled nor red

#### Scenario: A reply starts while the confirmation is open

- **WHEN** the chat starts replying while the compress confirmation is open
- **THEN** Compress is disabled with "Wait for the reply to finish." and nothing is sent

#### Scenario: Compress succeeds

- **WHEN** the user confirms and the server answers `compressed` with 42 → 9 messages
- **THEN** a line "Conversation compressed · 42 → 9 messages" is added to the transcript, the chat is re-read, the usage is re-read, and the suggestion is cleared

#### Scenario: Compress in progress

- **WHEN** the request is in flight or `status.update` says `compressing`
- **THEN** Now lists "Compressing the conversation…" as working, the Compress action is disabled, and the transcript wording follows `compacting` and `compacted` status frames

#### Scenario: Nothing to compress

- **WHEN** the result is `noop`
- **THEN** the app says "There isn't enough to compress yet." and changes nothing

#### Scenario: Would not shrink

- **WHEN** the result is `refused_would_grow`
- **THEN** the app says "Compressing wouldn't make this chat smaller." and changes nothing

#### Scenario: Summary failed

- **WHEN** the result is `aborted`
- **THEN** the app says "Hermes couldn't write the summary, so nothing changed." and offers Try again

#### Scenario: Fallback summary

- **WHEN** the result reports `fallback_used`
- **THEN** the outcome line adds "Hermes couldn't summarize the older messages, so it dropped them."

#### Scenario: Chat is busy

- **WHEN** the chat starts replying before the request or the server answers 4009
- **THEN** the app says "Wait for the reply to finish, then try again." and changes nothing

#### Scenario: Another compression holds the lock

- **WHEN** the server answers `lock_held`
- **THEN** the app says "Hermes is already compressing this chat." and re-reads usage

#### Scenario: Answer lost

- **WHEN** no answer arrives within 90 seconds or the connection drops
- **THEN** the app says "Hermes didn't answer. The conversation may have been compressed.", re-reads the chat and usage, and does not send the request again

#### Scenario: Compute-host session

- **WHEN** the result is `pending`
- **THEN** the app says "Hermes is compressing this chat in the background." and re-reads the chat when the session reports it has settled

#### Scenario: Session id rotates

- **WHEN** the server rotates the stored session (legacy, `in_place: false`)
- **THEN** the thread follows the new id as for any rotation and the transcript line is added to the new thread

#### Scenario: Backgrounded or switched during compression

- **WHEN** the app is backgrounded or the user opens another chat while a compression is in flight
- **THEN** the request is not cancelled, and its outcome line and re-read land in the original chat

#### Scenario: Old server

- **WHEN** `session.compress` answers method-not-found
- **THEN** Compress is not offered, and the `/compress` slash command behaves as before

### Requirement: Context respects isolation and privacy

Context data SHALL be requested only for a confirmed runtime session and never create or resume one. Answers SHALL be dropped after a thread, profile or connection change and cleared on sign-out. Under App Lock the row SHALL show only the percentage, details SHALL be unreachable and Compress disabled. Telemetry SHALL hold outcomes, buckets and booleans only; `context_files` paths SHALL NOT be shown or logged.

#### Scenario: Profile switch during a read

- **WHEN** a breakdown answer arrives after the user switched profiles
- **THEN** it does not appear in the new chat

#### Scenario: App Lock

- **WHEN** App Lock covers the app
- **THEN** no category, model or file label is drawn and Compress is disabled

#### Scenario: Sign-out

- **WHEN** the user signs out
- **THEN** all context state is discarded

### Requirement: Context accessibility

Rows and actions SHALL have 44 pt (iOS, macOS) or 48 dp (Android) targets and SHALL meet WCAG AA contrast in both themes. The bar SHALL carry the label "Context, <n> percent used" with "estimated" when applicable, and meaning SHALL NOT depend on colour alone. Text SHALL wrap at the largest accessibility size without truncating the percentage. Outcomes SHALL be announced once in fixed words. Focus SHALL return to the row after a sheet or page closes.

#### Scenario: Largest text size

- **WHEN** text is scaled to the largest accessibility size
- **THEN** the row wraps to as many lines as needed and the percentage stays fully visible

#### Scenario: Screen reader

- **WHEN** a screen reader reads the row
- **THEN** it hears the percentage, whether it is estimated, and the state word at 80% or more
