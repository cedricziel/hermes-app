# Live Activities Specification

## Purpose

TBD - created by archiving change live-activity-turn-ends. Update Purpose after archive.

## Requirements

### Requirement: Turns that end without the activity hearing a completion

The activity SHALL NOT stay in the working or a waiting state once its turn can no longer end it. The system SHALL end an activity that has not finished, at once, when:

- the user's stop found nothing left on the server to stop;
- the turn it follows can no longer be followed because the chat's profile went out of view and no reply sent from this app is still feeding it;
- the chat is closed while the reply runs.

It SHALL show "Reply failed" when a prompt that the server folded into the running turn loses its connection before that turn is followed to its end. A finished activity SHALL be left to end after its usual 15 minutes in all these cases. A reply sent from this app SHALL keep its activity when the chat's profile goes out of view, since the send still finishes it.

#### Scenario: Stop with nothing left to stop

- **WHEN** the user stops a reply whose turn the server already ended, and the app missed its completion
- **THEN** the activity disappears

#### Scenario: Folded prompt loses its connection

- **WHEN** the connection of a folded prompt breaks
- **THEN** the activity shows "Reply failed"

#### Scenario: Profile changes while a turn is followed

- **WHEN** the user switches profile while the activity follows a turn the app did not send
- **THEN** the activity disappears

#### Scenario: Profile changes while a reply sent here runs

- **WHEN** the user switches profile while a reply sent from this app runs, and the reply completes
- **THEN** the activity shows "Reply ready"

#### Scenario: Chat closed mid-reply

- **WHEN** the chat is closed while its reply runs
- **THEN** the activity disappears

### Requirement: The turn ahead of a prompt does not end the prompt's activity

When Hermes runs a turn of its own before the prompt's turn (after a resume that continues a goal), the end of that turn, completed or failed, SHALL NOT change the prompt's activity to "Reply ready" or "Reply failed". A request raised inside that turn SHALL still show the activity as waiting. A follow-up turn that no prompt of this app submitted SHALL NOT change an activity that already finished, which stays as it is until the next send.

#### Scenario: Resumed turn completes

- **WHEN** the turn Hermes ran ahead of the prompt completes while the prompt's reply waits
- **THEN** the activity still shows "Working", and "Reply ready" once the prompt's own reply completes

#### Scenario: Resumed turn fails

- **WHEN** the turn Hermes ran ahead of the prompt completes with a failure
- **THEN** the activity still shows "Working"

#### Scenario: Resumed turn asks

- **WHEN** the turn Hermes ran ahead of the prompt asks for approval
- **THEN** the activity shows "Waiting for your approval"

#### Scenario: Follow-up after the reply

- **WHEN** Hermes chains another turn onto a chat whose activity shows "Reply ready"
- **THEN** the activity keeps showing "Reply ready"

### Requirement: Starting an activity

The system SHALL start a Live Activity on iOS when the user sends a prompt from the iPhone app over the agent connection. It SHALL NOT start one for a canned local reply without an agent connection, for a turn sent from the watch, or for a turn the user did not submit (goal continuations, the turn Hermes resumes on its own). A chat SHALL have at most one activity: a send in a chat whose activity is still running SHALL keep it, and a send in a chat whose activity already finished SHALL replace it with a new one in the working state with a new start time. The system SHALL NOT start one while the "Live Activities" setting is off or still loading, or while iOS reports that Live Activities are not allowed for Hermes. A refusal from iOS (for example because too many activities are running) SHALL be dropped without an error reaching the user.

#### Scenario: Send from the phone

- **WHEN** the user sends a prompt in chat A, the setting is on and iOS allows Live Activities
- **THEN** a Live Activity titled with chat A's title appears in the working state

#### Scenario: Second send in the same chat

- **WHEN** the user sends another prompt in chat A while chat A's activity shows "Reply ready"
- **THEN** that activity is replaced by one in the working state and no second activity appears

#### Scenario: Prompt folded into the running turn

- **WHEN** the user sends a prompt in chat A while its reply is working and the server folds it into the running turn
- **THEN** chat A keeps its one activity, which goes on following the running turn

#### Scenario: Turn sent from the watch

- **WHEN** a turn sent from the watch runs through the phone
- **THEN** no Live Activity is started

#### Scenario: iOS refuses

- **WHEN** iOS refuses to start the activity
- **THEN** the send continues as usual and no error is shown

### Requirement: Activity states

The activity SHALL show the chat's title and exactly one of these states, each with a fixed label:

- working: "Working", with a counter of the time since the send;
- an approval request is open: "Waiting for your approval";
- a clarifying question is open: "Has a question for you";
- a secret or sudo request is open: "Waiting for you in Hermes";
- the reply completed: "Reply ready";
- the reply completed with failure or broke (as defined in the notifications spec): "Reply failed".

An input request that expires or is withdrawn, or progress after it (streamed text, reasoning, a tool call), SHALL return the activity to working while the reply is still running. Otherwise streaming text, tool activity and reasoning SHALL NOT change the state. Once the activity shows a finished state, later events in that chat SHALL NOT change it until the next send. A title the gateway gives the chat during the turn SHALL replace the title shown.

#### Scenario: Approval requested mid-turn

- **WHEN** the agent asks for approval while chat A's activity is working
- **THEN** the activity shows "Waiting for your approval"

#### Scenario: Approval answered

- **WHEN** the user approves in the app and the reply continues
- **THEN** the activity shows "Working" again

#### Scenario: Reply completes

- **WHEN** the reply in chat A completes
- **THEN** the activity shows "Reply ready"

#### Scenario: Reply breaks

- **WHEN** the connection drops while the reply is pending and no completion arrives after reconnecting
- **THEN** the activity shows "Reply failed"

#### Scenario: Chat named during the turn

- **WHEN** the gateway titles a new chat "Groceries" during the turn
- **THEN** the activity's title is "Groceries"

### Requirement: Nothing sensitive on a locked device

The activity SHALL show only the chat's title, the state label, the elapsed time and the Hermes icon. It SHALL NOT show reply text, reasoning, tool names or arguments, the command of an approval, the text of a question, or the name of a secret. Data the app shares with the activity SHALL NOT include tokens, the server address or message content.

#### Scenario: Approval for a command

- **WHEN** the agent asks for approval to run `rm -rf build`
- **THEN** the activity shows "Waiting for your approval" and does not mention the command

#### Scenario: Completed reply

- **WHEN** a reply "Done. Two files changed." completes
- **THEN** the activity shows "Reply ready" and not the reply text

### Requirement: Updates without a push channel

The system SHALL update the activity only from the running app, since Hermes sends no pushes. While the app is not in the foreground and a reply is running, each update SHALL mark the activity to go stale one minute later (ActivityKit is driven in whole minutes). A stale activity SHALL keep its last state and add "Open Hermes for the latest". When the app returns to the foreground, the system SHALL clear the stale mark of every running activity, and once the chat connection has caught up (reconnect and replay, or a re-read of the chat) the activity SHALL show the current state. A finished state SHALL NOT go stale.

#### Scenario: App suspended mid-reply

- **WHEN** the user locks the phone while chat A's reply is working and the app is suspended
- **THEN** after a minute without an update the activity says "Open Hermes for the latest"

#### Scenario: Returning to the app

- **WHEN** the user opens Hermes again and the reply completed meanwhile
- **THEN** the activity shows "Reply ready" without the stale note

#### Scenario: Reply finishes before suspension

- **WHEN** the reply completes while the app is still running in the background
- **THEN** the activity shows "Reply ready" and does not go stale

### Requirement: Ending an activity

The system SHALL end an activity:

- 15 minutes after it reached "Reply ready" or "Reply failed", leaving the final state on the Lock Screen until then;
- at once when the user stopped the reply;
- at once when the chat is deleted or archived, so the chat list no longer shows it;
- at once, all of them, when the user signs out;
- at once, all of them, when the user turns the setting off;
- at once when the app starts and finds an activity from an earlier launch, which it can no longer update.

The system SHALL NOT end an activity because the app went to the background or the connection dropped.

#### Scenario: Stopped reply

- **WHEN** the user stops the reply in chat A
- **THEN** chat A's activity disappears

#### Scenario: Sign-out

- **WHEN** the user signs out while two activities are shown
- **THEN** both disappear

#### Scenario: Leftover after relaunch

- **WHEN** iOS terminated the app while an activity was working and the user launches Hermes again
- **THEN** that activity is ended

#### Scenario: Finished activity lingers

- **WHEN** chat A's reply completed 10 minutes ago
- **THEN** the activity still shows "Reply ready"

### Requirement: Tapping an activity opens its chat

Tapping the activity on the Lock Screen or in the Dynamic Island SHALL open Hermes on the activity's chat, following the rules of "Tapping a notification opens its chat" in the notifications spec, including the profile match, a tap that started the app, and the message "Could not open that chat." when the chat cannot be opened.

#### Scenario: Tap from the Lock Screen

- **WHEN** the user taps chat A's activity on the Lock Screen
- **THEN** Hermes opens with chat A selected

#### Scenario: Tap for a chat of another profile

- **WHEN** the activity's profile differs from the profile currently shown
- **THEN** the open chat stays as it was and "Could not open that chat." is shown

### Requirement: Live Activities setting

On iOS the Notifications dialog SHALL contain a "Live Activities" switch, on by default, that explains that a running reply is shown on the Lock Screen and in the Dynamic Island while Hermes is running. It SHALL be independent of the "Notify me" switch and of the notification permission. When iOS reports that Live Activities are turned off for Hermes, the dialog SHALL show "Turn on Live Activities for Hermes in system settings." The switch SHALL be persisted across launches, and a change made while the saved value is loading SHALL win over the loaded value. On other platforms the switch SHALL NOT be shown.

#### Scenario: Default state

- **WHEN** the user opens the dialog on a fresh iOS install
- **THEN** the "Live Activities" switch is on

#### Scenario: Turned off in iOS

- **WHEN** Live Activities are disabled for Hermes in iOS Settings
- **THEN** the dialog shows "Turn on Live Activities for Hermes in system settings."

#### Scenario: Other platforms

- **WHEN** the dialog is opened on Android or macOS
- **THEN** no "Live Activities" switch is shown

### Requirement: Backend contract

The feature SHALL rely only on the gateway events the chat already handles over `/api/ws` (`prompt.submit` answers, `message.start`, `message.complete`, `session.info`, `approval.request`, `clarify.request`, `secret.request`, `sudo.request`, their `*.expire` frames, `approval.cancelled`, `session.title`) and SHALL need no new Hermes route, RPC method or minimum version beyond what the chat already requires.

#### Scenario: Older supported Hermes

- **WHEN** the app is connected to the oldest Hermes the chat supports
- **THEN** Live Activities work without any server change

### Requirement: Watch Smart Stack presentation

On iOS 18 and watchOS 11 or later, the activity SHALL declare a compact `small` presentation, which watchOS shows in the Smart Stack of a paired Apple Watch. It SHALL show the Hermes icon in the state's tint, the chat's title on one line, one short state word and, in the working state, the time since the send. While the activity is stale and the reply has not finished, it SHALL show "Open Hermes" in place of the state word and the time. The state word SHALL be "Working" for working, "Waiting for you" for an approval request, a question or a request that needs the user in Hermes, "Done" for a ready reply and "Failed" for a failed one. The presentation SHALL follow "Nothing sensitive on a locked device": it SHALL NOT show reply text, reasoning, tool names or arguments, the command of an approval, the text of a question or the name of a secret. The system SHALL start an activity only for a reply sent from the phone; a turn sent from the watch SHALL get none, because the phone app handles it in the background, where iOS does not allow an activity to start.

#### Scenario: Working reply

- **WHEN** the user sends a prompt from the phone in chat A and wears a paired watch
- **THEN** the watch Smart Stack shows chat A's title, "Working" and an elapsed-time counter

#### Scenario: Approval requested

- **WHEN** the agent asks for approval to run `rm -rf build`
- **THEN** the Smart Stack card shows "Waiting for you" and does not mention the command

#### Scenario: Reply finished

- **WHEN** the reply completes
- **THEN** the card shows "Done" and no counter

#### Scenario: Stale activity

- **WHEN** the activity has gone stale while the reply had not finished, because iOS suspended the app
- **THEN** the card shows "Open Hermes" instead of the state word and the counter, as the Lock Screen does

#### Scenario: Turn sent from the watch

- **WHEN** the user sends a turn from the watch
- **THEN** no Live Activity is started on the phone or the watch
