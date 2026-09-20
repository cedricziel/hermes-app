# Notifications Specification

## Purpose

Describes the local notifications the app posts when the agent has something for the user (a reply finished, a reply failed, or the agent is waiting for an approval or an answer), the policy that decides when one is shown, the user's on/off setting and the system permission flow, and how tapping a notification opens the matching chat. Notifications are local: they are posted by the running app when it sees the event on its own chat connection. No push service is involved.
## Requirements
### Requirement: Notifiable events

The system SHALL post a local notification for exactly these chat events: a reply that completed, a reply that completed with failure, a reply whose stream broke before it completed (treated as a failed reply), an approval request from the agent, and a clarifying question from the agent. Streaming text, tool activity, title changes, thread binding and expiring input requests SHALL NOT produce a notification. The notification title SHALL be the chat's title.

#### Scenario: Reply completes

- **WHEN** a reply finishes while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

#### Scenario: Streaming and tool events

- **WHEN** the agent streams text or runs a tool
- **THEN** no notification is shown

#### Scenario: Stream breaks while the user is away

- **WHEN** the connection drops or the stream ends before the reply completed and the app is not in the foreground
- **THEN** a notification with the body "Reply failed" is shown for that chat

#### Scenario: Reply that already completed

- **WHEN** a reply completed and its stream then closes normally
- **THEN** only the completion is announced, not a failure

### Requirement: Notification body

For a completed reply the notification body SHALL be a one-line preview of the reply: whitespace runs collapsed to single spaces and trimmed, cut at 120 characters (counted as user-perceived characters, so an emoji is never split) with an ellipsis appended when cut. An empty reply SHALL use the body "Reply ready". A failed reply SHALL use the body "Reply failed" and SHALL NOT include the error text. An approval request SHALL use "Waiting for your approval" and a clarifying question SHALL use "Has a question for you"; these SHALL NOT include the command or the question, so that nothing sensitive shows on a lock screen.

#### Scenario: Long reply

- **WHEN** a reply of 200 characters completes
- **THEN** the body is its first 120 characters followed by an ellipsis

#### Scenario: Approval request

- **WHEN** the agent asks for approval to run `rm -rf build`
- **THEN** the body is "Waiting for your approval" and does not mention the command

#### Scenario: Failed reply

- **WHEN** a reply completes with failure and an error text
- **THEN** the body is "Reply failed"

### Requirement: Attention policy

The system SHALL NOT post a notification while the app is in the foreground and the event belongs to the chat that is currently open. It SHALL post one when the app is not in the foreground, even for the open chat, and when the app is in the foreground but another chat (or no chat) is open. A chat counts as open only while the app is still on the profile the turn was sent under. It SHALL post none while the user has notifications turned off, and none until the saved setting has finished loading.

#### Scenario: Watching the chat

- **WHEN** the app is focused on chat A and a reply in chat A completes
- **THEN** no notification is shown

#### Scenario: Reply for another chat

- **WHEN** the app is focused on chat B and a reply in chat A completes
- **THEN** a notification for chat A is shown

#### Scenario: App in the background

- **WHEN** the app is not in the foreground and a reply completes in the open chat
- **THEN** a notification is shown

#### Scenario: Notifications switched off

- **WHEN** the user has turned notifications off
- **THEN** no notification is shown for any event

#### Scenario: Profile changed since the turn was sent

- **WHEN** a turn was sent under profile A, the app is now on profile B, and a chat with the same id is open there
- **THEN** the reply is announced, with profile A, instead of being treated as the open chat

### Requirement: One notification per chat

The system SHALL identify a notification by its chat, and by the Hermes profile the chat belongs to when one is known, so that a newer notification for the same chat replaces the earlier one and chats of different profiles with the same thread id do not replace each other. The identifier SHALL be stable across app releases.

#### Scenario: Two replies in one chat

- **WHEN** two notifications are posted for the same chat
- **THEN** the second replaces the first in the notification centre

### Requirement: Supported platforms

The system SHALL post notifications on Android, iOS and macOS, on the Android channel "Agent activity". On other platforms it SHALL do nothing and report the permission as unavailable. A notification that cannot be shown SHALL be dropped without an error reaching the user.

#### Scenario: Unsupported platform

- **WHEN** the app runs on Windows or Linux and a reply completes
- **THEN** no notification is shown and no error is raised

### Requirement: Notification permission

The system SHALL ask the operating system for permission to post notifications, once, after the user's first send to the agent, provided the saved setting has loaded, notifications are on, and a permission answer has not already been recorded. Sends that only produce a canned local reply, without a real agent connection, SHALL NOT trigger the request. A granted or denied answer SHALL be recorded and remembered across launches, and a later grant clears an earlier denial. An answer of "unavailable" (unsupported platform, plugin failure, or no answer) SHALL NOT be recorded, so the question is asked again on a later send. A notification that becomes due while a permission request is in flight SHALL be shown only after the request resolves.

#### Scenario: First send

- **WHEN** the user sends their first message with notifications on and no permission recorded
- **THEN** the system permission prompt is requested exactly once, however many messages follow

#### Scenario: Permission denied

- **WHEN** the system answers that permission is denied
- **THEN** the denial is remembered and the app does not ask again

#### Scenario: Unavailable answer

- **WHEN** the permission request returns unavailable
- **THEN** nothing is recorded and the next send asks again

#### Scenario: Notifications off

- **WHEN** the user has turned notifications off
- **THEN** no permission request is made on send

### Requirement: Notification settings

The system SHALL let the user open a "Notifications" dialog from the account menu. The dialog SHALL contain a "Notify me" switch, on by default, which explains that alerts arrive when a reply finishes or Hermes needs the user while the app is not in front, that replies show a preview and that requests only say Hermes is waiting. When notifications are on and the system permission was denied, the dialog SHALL show "Turn on notifications for Hermes in system settings." The dialog SHALL also state that alerts arrive while Hermes is running, including for a short time after the user leaves it. The switch position and the permission outcome SHALL be persisted across launches. A change made while the saved values are still loading SHALL win over the loaded value.

#### Scenario: Default state

- **WHEN** the user opens the dialog on a fresh install
- **THEN** the switch is on and no permission hint is shown

#### Scenario: Turning off

- **WHEN** the user flips the switch off
- **THEN** notifications are disabled and the choice is kept for the next launch

#### Scenario: Permission was denied

- **WHEN** the system permission was denied and the switch is on
- **THEN** the dialog tells the user to enable notifications in system settings

#### Scenario: Denied but switched off

- **WHEN** the permission was denied and the switch is off
- **THEN** the permission hint is not shown

### Requirement: Tapping a notification opens its chat

The system SHALL open the chat a notification was posted for when the user taps it while the app is running, without closing any screen the user has opened above the chat; when the thread drawer of a narrow layout is open, the system SHALL close it. When the tap started the app, the system SHALL open that chat once the chat list has loaded. A tap made while the chat list is still loading SHALL be held and applied once the list has loaded. A notification carries the chat's thread id and, when known, its profile; one without a profile SHALL match on the thread id alone (so a notification posted by an earlier build, whose payload is a bare thread id, still works). When the chat cannot be opened, because the notification's profile differs from the one currently shown or the chat is not in the loaded list, the selection SHALL NOT change (for a launch, the first chat in the list SHALL be selected instead) and the system SHALL tell the user "Could not open that chat."

#### Scenario: Tap while running

- **WHEN** the user taps a notification for chat s2 while chat s1 is open
- **THEN** chat s2 opens

#### Scenario: Screen above the chat

- **WHEN** the user has another screen open above the chat and taps a notification
- **THEN** that screen stays open

#### Scenario: Thread drawer open

- **WHEN** the thread drawer is open on a narrow layout and the user taps a notification for another chat
- **THEN** that chat opens and the drawer closes

#### Scenario: Tap while the list loads

- **WHEN** the user taps a notification for chat s2 while the chat list is still loading
- **THEN** chat s2 opens once the list has loaded and no error is shown

#### Scenario: Tap for an unknown chat

- **WHEN** the tapped notification names a chat that is not in the list
- **THEN** the open chat stays as it was and "Could not open that chat." is shown

#### Scenario: Tap made under another profile

- **WHEN** the notification's profile differs from the profile currently shown
- **THEN** the open chat stays as it was and "Could not open that chat." is shown

#### Scenario: Notification without a profile

- **WHEN** the notification carries no profile
- **THEN** it matches on its thread id alone

#### Scenario: Cold start from a notification

- **WHEN** the app was launched by tapping a notification for chat s2
- **THEN** chat s2 is selected once the list has loaded

#### Scenario: Cold start for a chat that cannot be opened

- **WHEN** the launching notification names a chat that is not in the list, or another profile
- **THEN** the first chat is selected and "Could not open that chat." is shown

