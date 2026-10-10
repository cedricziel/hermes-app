## MODIFIED Requirements

### Requirement: Notification body

For a completed reply the notification body SHALL be a one-line preview of the reply: whitespace runs collapsed to single spaces and trimmed, cut at 120 characters (counted as user-perceived characters, so an emoji is never split) with an ellipsis appended when cut. An empty reply SHALL use the body "Reply ready". A failed or broken reply SHALL use the body "Reply failed" and SHALL NOT include the error text. On iOS and macOS an approval request SHALL show the command it asks to run, or its description when the command is empty, and "Waiting for your approval" when both are empty; a question SHALL show the question, and a request with several questions SHALL show "Has a question for you". Request text SHALL be cut at 1000 characters with an ellipsis. Each approval and question notification SHALL carry a hidden-preview placeholder, "Waiting for your approval" or "Has a question for you", which the system shows in place of the body while previews are hidden (the Show Previews "When Unlocked" setting on a locked device, or "Never"). On Android the approval and question bodies SHALL stay "Waiting for your approval" and "Has a question for you", whatever choices the request offers. While App Lock is on, or before its saved setting has loaded, approval and question notifications SHALL use those generic bodies on every platform too, and SHALL carry no actions (see "Answering a request from its notification"). A request for a secret value, a sudo password or a vault prompt, and any request the app cannot answer, SHALL use "Waiting for you in Hermes" and SHALL NOT include anything about what is asked for.

#### Scenario: Long reply

- **WHEN** a reply of 200 characters completes
- **THEN** the body is its first 120 characters followed by an ellipsis

#### Scenario: Approval request

- **WHEN** the agent asks for approval to run `rm -rf build` on iOS or macOS
- **THEN** the body is "rm -rf build" and the placeholder is "Waiting for your approval"

#### Scenario: Locked device with previews hidden

- **WHEN** an approval notification arrives on a locked iPhone whose Show Previews setting is "When Unlocked"
- **THEN** the lock screen shows "Waiting for your approval" and not the command

#### Scenario: Question

- **WHEN** the agent asks "Which branch?" on iOS or macOS
- **THEN** the body is "Which branch?" and the placeholder is "Has a question for you"

#### Scenario: Android

- **WHEN** the agent asks for approval to run `rm -rf build` on Android
- **THEN** the body is "Waiting for your approval"

#### Scenario: App Lock on

- **WHEN** App Lock is on and the agent asks for approval to run `rm -rf build`
- **THEN** the body is "Waiting for your approval" and the notification has no actions

#### Scenario: Secret or sudo request

- **WHEN** the agent asks for a secret value named `SERVICE_API_KEY` or for a sudo password
- **THEN** the body is "Waiting for you in Hermes" and does not mention the variable or the kind of request

#### Scenario: Failed reply

- **WHEN** a reply completes with failure and an error text
- **THEN** the body is "Reply failed"

### Requirement: Turns sent from the watch

The system SHALL post a notification for a turn sent from the watch and relayed through the phone, under the rules of "Notifiable events" and "Notification body": a reply that completed, a reply that completed with failure, a reply that broke (the connection dropped, the stream ended without a completion, or no event arrived for the send timeout) once the chat was known, and an approval request, a question or a request the watch cannot answer raised during the turn. An approval or a question SHALL be posted with the actions of "Answering a request from its notification", which watchOS shows on the watch. A broken reply SHALL be announced as a failed one. The system SHALL post it whichever chat the phone has open and whether or not the app is in front, because the phone's chat screen does not follow a turn it did not send, so "Attention policy" does not suppress it. Its title SHALL be the chat's title when the gateway named it during the turn, and "Hermes" otherwise. It SHALL replace an earlier notification for the same chat and profile. The system SHALL read the saved setting first when a watch request woke the app before it loaded, SHALL ask the operating system each time whether it may post (without prompting), SHALL NOT post while notifications are off or the system does not allow them, SHALL NOT post for a reply that broke before the chat was known, and SHALL NOT ask the operating system for permission on behalf of a watch turn.

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

- **WHEN** the agent asks for approval to run `rm -rf build` during a watch turn
- **THEN** an approval notification with its actions is shown

#### Scenario: Notifications off or not permitted

- **WHEN** notifications are off, or the user has never answered the permission prompt
- **THEN** no notification is shown and no permission prompt is raised

### Requirement: Notification settings

The system SHALL let the user open a "Notifications" dialog from the account menu. The dialog SHALL contain a "Notify me" switch, on by default, which explains that alerts arrive when a reply finishes or Hermes needs the user while the app is not in front, that replies show a preview, and that approvals and questions show the command or the question and can be answered from the notification, hidden on a locked screen when the system hides previews there. When notifications are on and the system permission was denied, the dialog SHALL show "Turn on notifications for Hermes in system settings." The dialog SHALL also state that alerts arrive while Hermes is running, including for a short time after the user leaves it. The switch position and the permission outcome SHALL be persisted across launches. A change made while the saved values are still loading SHALL win over the loaded value.

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

## ADDED Requirements

### Requirement: Answering a request from its notification

On iOS and macOS an approval or question notification SHALL carry actions that answer the request without opening the app. Every action SHALL require the device to be unlocked. Approval actions SHALL be "Allow once", "Allow for session", "Always allow" and "Deny", limited to and in the order of the choices the agent offered (`once`, `session`, `always`, `deny`); "Always allow" and "Deny" SHALL be marked destructive and SHALL NOT ask for confirmation. A question with one to four choices SHALL offer one action per choice, titled with the choice; a question with more than four SHALL offer the first three and "Other…", which opens the app on the chat. Every single question SHALL offer "Reply", a text input whose text is the answer. A multi-select question SHALL offer only "Reply" and "Open", and an open-ended question the same. A request with several questions and an approval that offers no choice the app knows SHALL carry no actions, only the placeholder. While App Lock is on, or before its saved setting has loaded, every approval and question SHALL carry no actions, only the placeholder, so that tapping the notification opens the app, which asks to be unlocked first. Turning App Lock on SHALL withdraw delivered notifications whose actions answer a request, and an action used while App Lock is on SHALL send nothing and post a notification for the chat with the body "Open Hermes to answer." A secret, sudo, vault or unsupported request SHALL carry no actions. Tapping the notification itself SHALL open the chat as before.

The category identifiers SHALL be `hermes.request.approval.<offered choices joined by ->`, `hermes.request.question`, `hermes.request.question.<hash of the action titles>`, and, with the placeholder alone, `hermes.request.approval` and `hermes.request.questions`; the action identifiers SHALL be `hermes.action.allow-once`, `hermes.action.allow-session`, `hermes.action.allow-always`, `hermes.action.deny`, `hermes.action.choice.0` to `hermes.action.choice.3`, `hermes.action.reply` and `hermes.action.open`, which "Other…" also uses.

An answer SHALL be sent with the gateway's `request.answer` RPC (`{id, result, profile}`, answered `{status: ok | expired}`; in the Hermes OpenRPC contract from `HERMES_REF` 167e9fd on): `{choice}` for an approval, `{answers: {<question id>: <answer>}}` for a question, where a multi-select reply is a JSON list holding the typed text. A request the server raised as an event frame (`approval.request`, `clarify.request`) rather than as a server-to-client request, which the notification records, and any request on a server that does not know `request.answer`, SHALL be answered the older way: an approval with `approval.respond` on the session resumed by its chat, a question with `clarify.respond`. A request `request.answer` reports `expired` SHALL NOT be resumed or answered another way. The app SHALL send it from the running app when it is running, including when iOS started a background launch for the action, and otherwise from that background launch, which signs in with the stored session. It SHALL be sent once, and the outcome SHALL be known within 25 seconds of the moment the system handed the action to the app, in time to post a follow-up; nothing SHALL be sent after that. When the answer cannot be sent in that time, its outcome never comes back, the server reports the request `expired`, or nobody is signed in, the system SHALL post a notification for the same chat with the body "Couldn't send your answer. Open Hermes to answer.", which opens the chat when tapped.

#### Scenario: Allow from the lock screen

- **WHEN** the user picks "Allow once" on an approval notification and unlocks with Face ID
- **THEN** the approval is answered `once` without the app coming to the front, and the turn continues

#### Scenario: Offered choices only

- **WHEN** the agent offers `once` and `deny` only
- **THEN** the notification offers "Allow once" and "Deny"

#### Scenario: Question with three choices

- **WHEN** the agent asks "Which branch?" with the choices `main`, `dev` and `release`
- **THEN** the notification offers "main", "dev", "release" and "Reply"

#### Scenario: Question with six choices

- **WHEN** the agent asks a question with six choices
- **THEN** the notification offers the first three choices, "Other…" and "Reply", and "Other…" opens the chat

#### Scenario: Typed reply

- **WHEN** the user picks "Reply" on a question notification and types "the second one"
- **THEN** the question is answered with "the second one"

#### Scenario: Request already gone

- **WHEN** the user answers from a notification after the request was answered in the app or expired
- **THEN** a notification "Couldn't send your answer. Open Hermes to answer." for that chat is shown

#### Scenario: Secret request

- **WHEN** the agent asks for a sudo password
- **THEN** the notification carries no actions

#### Scenario: App Lock turned on after the notification

- **WHEN** the user turns App Lock on while an approval notification with buttons is in the notification centre
- **THEN** that notification is withdrawn

#### Scenario: Button used while App Lock is on

- **WHEN** a button of a request notification is used while App Lock is on
- **THEN** no answer is sent and a notification for the chat says "Open Hermes to answer."

#### Scenario: App not running

- **WHEN** the user picks "Allow once" while Hermes is not running
- **THEN** iOS starts it in the background, it signs in with the stored session, and the approval is answered

#### Scenario: App Lock on

- **WHEN** App Lock is on and the agent asks a question
- **THEN** the notification says "Has a question for you" and carries no actions
