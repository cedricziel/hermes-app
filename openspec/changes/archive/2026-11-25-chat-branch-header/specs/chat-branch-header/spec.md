# Spec Delta

## Purpose

Shows where a branched chat came from, lets the user open the original, and marks branches in the chat list.

## ADDED Requirements

### Requirement: Branch marker

The app SHALL treat a chat as a branch only when its session row (`GET /api/sessions`, `GET /api/sessions/{id}`) has a non-empty string `_branched_from` and no non-empty `_reset_from`. It SHALL NOT read `parent_session_id` to decide, because compression continuations and sub-agent runs carry it too. A chat made by the app's own branch action SHALL know its parent from the `parent` of the gateway result before any list read.

#### Scenario: A branch

- **WHEN** a row has `_branched_from: "p1"`
- **THEN** the chat's parent id is `p1`

#### Scenario: A continuation or a reset

- **WHEN** a row has `parent_session_id` but no `_branched_from`, or has `_reset_from`
- **THEN** the chat has no parent and shows no notice and no glyph

### Requirement: Branched-from notice

An open chat with a parent SHALL show one row between its header and its transcript: "Branched from <title>" with a chevron when the parent is in the loaded list, "Branched from another chat" when it is not. The row SHALL be one tap target of at least 44 pt (48 dp on Android, 32 pt on the Mac). Conversation windows and the quick panel SHALL show none, because only the main chat screen passes the notice.

#### Scenario: Title known

- **WHEN** the parent is in the loaded list
- **THEN** the row reads "Branched from" and its title, and a tap opens it

#### Scenario: Large text

- **WHEN** the text size is the largest
- **THEN** the row grows, wraps the title to two lines and ends in an ellipsis

### Requirement: Opening the original

A tap SHALL send one `GET /api/sessions/{id}/latest-descendant` with the chat's profile and then open the answered id through the open-by-id path that reads a chat not in the loaded list. It SHALL NOT change the parent or the branch.

#### Scenario: Parent compressed since

- **WHEN** the answer has `changed: true`
- **THEN** the chat that opens is the answered tip

#### Scenario: Parent deleted

- **WHEN** the server answers 404 `Session not found`
- **THEN** the row reads "The original chat was deleted.", has an info icon, is not a button and sends nothing on a later tap

#### Scenario: Hermes cannot be reached

- **WHEN** the request fails, answers 5xx or has no answer after 10 s
- **THEN** the row reads "Couldn't reach Hermes. Check your connection." with "Try again", and nothing is resent until the next tap

#### Scenario: The user selected another chat meanwhile

- **WHEN** the read finishes after the user selected a different chat, or the profile changed
- **THEN** nothing opens and the selection stays

#### Scenario: App Lock covers the app meanwhile

- **WHEN** the read finishes while the cover is up
- **THEN** the selection does not change and the row returns to its resting state

### Requirement: Chat list marker

A branch SHALL show a branch glyph before its title in the chat list, the Mac source list and search results, with "Branch" in its accessibility label. Rows SHALL NOT be nested under the parent and SHALL NOT show the parent's title.

#### Scenario: Branch row

- **WHEN** the list holds a branch
- **THEN** its row is one line with the glyph before the title, in the section its own recency or folder puts it in

### Requirement: No branch action on a prompt

The app SHALL offer branching on finished replies only, not on a user prompt.

#### Scenario: Prompt

- **WHEN** the user opens the actions of a user message
- **THEN** there is no Branch entry

### Requirement: One idempotency key per branch

Every branch request (`session.branch_whole`, or `session.branch` on an older gateway) SHALL carry an `idempotency_key`: a new random value for each branch the user asks for. A request SHALL be sent once; the app SHALL NOT resend it itself. When a branch's answer is lost (a timeout or a closed socket), the next tap on the same chat, branch point and last message SHALL send the same key, so that Hermes returns the branch it already made. Any answer, a refusal, an incomplete copy, another branch point or a changed chat SHALL give the next tap a new key. A gateway that refuses the field as a parameter SHALL get the same method once more without it.

#### Scenario: Two taps

- **WHEN** the user branches a chat twice and the first branch was answered
- **THEN** the two requests carry different keys

#### Scenario: Lost answer, then the same tap

- **WHEN** a branch gets no answer and the user taps the same Branch again with the chat unchanged
- **THEN** the second request carries the first one's key

### Requirement: Branch hidden where the server cannot branch

The reply action "Branch in new chat" and the Mac thread menu's "Branch in New Chat" SHALL NOT be offered once the gateway has answered that it knows neither branch method on the open connection. While that is not known, and once a branch worked, they SHALL be offered as before.

#### Scenario: Server without a branch method

- **WHEN** a branch found the gateway without `session.branch_whole` and `session.branch`
- **THEN** no reply offers Branch and the thread menu has no Branch entry, until a new connection

### Requirement: Privacy

The parent's id and title SHALL NOT reach a breadcrumb, span, log, the surface snapshot, a notification, Spotlight, Handoff, a Live Activity or the watch. The one breadcrumb, `chat.branch_parent.open`, SHALL carry `outcome` only.

#### Scenario: Breadcrumb

- **WHEN** the original chat is opened or fails to open
- **THEN** the breadcrumb's data is `{outcome: opened | deleted | unreachable | dropped}`
