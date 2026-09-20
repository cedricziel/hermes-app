# Notifications Specification

## Purpose

Describes the local notifications the app posts when the agent has something for the user (a reply finished, a reply failed, or the agent is waiting for an approval or an answer), the policy that decides when one is shown, the user's on/off setting and the system permission flow, and how tapping a notification opens the matching chat. Notifications are local: they are posted by the running app when it sees the event on its own chat connection, or, for a turn sent from the watch, on the connection the phone opened for it. No push service is involved.

## Requirements

### Requirement: Notifiable events

The system SHALL post a local notification for exactly these chat events: a reply that completed, a reply that completed with failure, a reply that broke (the stream ended or failed while the reply was still pending, for example because the socket dropped or the gateway answered with an error, so that no completion arrived), an approval request from the agent, a clarifying question from the agent, and a request from the agent for something the app cannot answer (a secret value or a sudo password). A broken reply SHALL be announced exactly like a failed one. Streaming text, tool activity, title changes, thread binding and expiring input requests SHALL NOT produce a notification. The notification title SHALL be the chat's title.

#### Scenario: Reply completes

- **WHEN** a reply finishes while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

#### Scenario: Reply breaks while the user is away

- **WHEN** the app is in the background, the socket drops while a reply is pending and no completion arrived
- **THEN** a notification titled with the chat's title and the body "Reply failed" is shown

#### Scenario: Stream ends after the reply already completed

- **WHEN** the stream ends after the reply completed
- **THEN** no further notification is shown

#### Scenario: Streaming and tool events

- **WHEN** the agent streams text or runs a tool
- **THEN** no notification is shown

#### Scenario: Request the app cannot answer

- **WHEN** the agent asks for a secret value or a sudo password while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

### Requirement: Notification body

For a completed reply the notification body SHALL be a one-line preview of the reply: whitespace runs collapsed to single spaces and trimmed, cut at 120 characters (counted as user-perceived characters, so an emoji is never split) with an ellipsis appended when cut. An empty reply SHALL use the body "Reply ready". A failed or broken reply SHALL use the body "Reply failed" and SHALL NOT include the error text. An approval request SHALL use "Waiting for your approval", a clarifying question SHALL use "Has a question for you", and a request for a secret value or a sudo password SHALL use "Waiting for you in Hermes"; these SHALL NOT include the command, the question or anything about the secret asked for, so that nothing sensitive shows on a lock screen.

#### Scenario: Long reply

- **WHEN** a reply of 200 characters completes
- **THEN** the body is its first 120 characters followed by an ellipsis

#### Scenario: Approval request

- **WHEN** the agent asks for approval to run `rm -rf build`
- **THEN** the body is "Waiting for your approval" and does not mention the command

#### Scenario: Secret or sudo request

- **WHEN** the agent asks for a secret value named `SERVICE_API_KEY` or for a sudo password
- **THEN** the body is "Waiting for you in Hermes" and does not mention the variable or the kind of request

#### Scenario: Failed reply

- **WHEN** a reply completes with failure and an error text
- **THEN** the body is "Reply failed"

### Requirement: Attention policy

The system SHALL NOT post a notification while the app is in the foreground and the event belongs to the chat that is currently open. It SHALL post one when the app is not in the foreground, even for the open chat, and when the app is in the foreground but another chat (or no chat) is open. It SHALL post none while the user has notifications turned off, and none until the saved setting has finished loading. A chat counts as the open one only while the chat screen still shows the Hermes profile the turn was sent under; if the profile was switched since, the event belongs to a chat that is not open and SHALL be announced.

#### Scenario: Watching the chat

- **WHEN** the app is focused on chat A and a reply in chat A completes
- **THEN** no notification is shown

#### Scenario: Reply for another chat

- **WHEN** the app is focused on chat B and a reply in chat A completes
- **THEN** a notification for chat A is shown

#### Scenario: App in the background

- **WHEN** the app is not in the foreground and a reply completes in the open chat
- **THEN** a notification is shown

#### Scenario: Profile switched during a turn

- **WHEN** a reply is sent in chat A under profile P, the user then switches the chat screen to profile Q, which lists a chat with the same thread id, and the reply completes while the app is in the foreground
- **THEN** a notification for chat A of profile P is shown

#### Scenario: Notifications switched off

- **WHEN** the user has turned notifications off
- **THEN** no notification is shown for any event

### Requirement: Turns sent from the watch

The system SHALL post a notification for a turn sent from the watch and relayed through the phone, under the rules of "Notifiable events" and "Notification body": a reply that completed, a reply that completed with failure, and a reply that broke (the connection dropped, the stream ended without a completion, or no event arrived for the send timeout) once the chat was known. A broken reply SHALL be announced as a failed one. The system SHALL post it whichever chat the phone has open and whether or not the app is in front, because the phone's chat screen does not follow a turn it did not send, so "Attention policy" does not suppress it. Its title SHALL be the chat's title when the gateway named it during the turn, and "Hermes" otherwise. It SHALL replace an earlier notification for the same chat and profile. The system SHALL NOT post for an approval request, a question or an unsupported request raised during such a turn, SHALL NOT post while notifications are off or the saved setting is loading, SHALL NOT post for a reply that broke before the chat was known, and SHALL NOT ask the operating system for permission on behalf of a watch turn.

#### Scenario: Reply completes while the wrist is down

- **WHEN** a turn sent from the watch completes with "Done. Two files changed." and notifications are on and permitted
- **THEN** a notification with the body "Done. Two files changed." is shown

#### Scenario: Chat named during the turn

- **WHEN** the gateway titles a new chat "Groceries" during a watch turn and the reply completes
- **THEN** the notification is titled "Groceries"

#### Scenario: Existing chat not renamed

- **WHEN** a watch turn into an existing chat completes without the gateway renaming it
- **THEN** the notification is titled "Hermes"

#### Scenario: Phone showing the same chat

- **WHEN** the phone app is in front on chat A and a turn the watch sent into chat A completes
- **THEN** a notification is shown

#### Scenario: Failed reply

- **WHEN** a watch turn completes with failure and an error text
- **THEN** the body is "Reply failed" and does not include the error text

#### Scenario: Turn breaks after the chat is known

- **WHEN** the connection drops after the chat was created or resumed and no completion arrived
- **THEN** a notification with the body "Reply failed" is shown

#### Scenario: Turn breaks before the chat is known

- **WHEN** the connection fails before the gateway reported a chat
- **THEN** no notification is shown

#### Scenario: Input request during a watch turn

- **WHEN** the agent asks for an approval or a question during a watch turn
- **THEN** no notification is shown

#### Scenario: Notifications off or not permitted

- **WHEN** notifications are off, or the user has never answered the permission prompt
- **THEN** no notification is shown and no permission prompt is raised

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

The system SHALL open the chat a notification was posted for when the user taps it while the app is running. When the tap started the app, the system SHALL open that chat once the chat list has loaded. A tap that arrives while the chat list is still loading SHALL be held and applied when the list has loaded, and SHALL take precedence over the notification that launched the app. A notification carries the chat's thread id and, when known, its profile; a notification without a profile SHALL match on the thread id alone (so a notification posted by an earlier build, whose payload is a bare thread id, still works). If the target chat cannot be opened, because it belongs to a different profile than the one currently shown or is not in the loaded list, the selection SHALL NOT change (for a launch, the first chat in the list SHALL be selected instead) and the system SHALL tell the user with the message "Could not open that chat." Opening a chat from a notification SHALL close the chat list drawer when it is open, and SHALL NOT close or pop any other screen the user has open.

#### Scenario: Tap while running

- **WHEN** the user taps a notification for chat s2 while chat s1 is open
- **THEN** chat s2 opens

#### Scenario: Tap for an unknown chat

- **WHEN** the tapped notification names a chat that is not in the list
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap made under another profile

- **WHEN** the notification's profile differs from the profile currently shown
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap while the list is loading

- **WHEN** the user taps a notification for chat s2 while the chat list is still loading
- **THEN** chat s2 is selected as soon as the list has loaded

#### Scenario: Tap while another screen is open

- **WHEN** the user taps a notification for chat s2 while a secondary screen such as Profiles or Bots is open over the chat
- **THEN** chat s2 is selected
- **AND** the secondary screen stays open

#### Scenario: Cold start from a notification

- **WHEN** the app was launched by tapping a notification for chat s2
- **THEN** chat s2 is selected once the list has loaded
