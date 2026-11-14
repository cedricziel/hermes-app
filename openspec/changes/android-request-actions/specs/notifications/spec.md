# Spec Delta

## MODIFIED Requirements

### Requirement: Notification body

For a completed reply the notification body SHALL be a one-line preview of the reply: whitespace runs collapsed to single spaces and trimmed, cut at 120 characters (counted as user-perceived characters, so an emoji is never split) with an ellipsis appended when cut. An empty reply SHALL use the body "Reply ready". A failed or broken reply SHALL use the body "Reply failed" and SHALL NOT include the error text. An approval request SHALL show the command it asks to run, or its description when the command is empty, and "Waiting for your approval" when both are empty; a question SHALL show the question, and a request with several questions SHALL show "Has a question for you". Request text SHALL be cut at 1000 characters with an ellipsis. Each approval and question notification SHALL carry a hidden-preview placeholder, "Waiting for your approval" or "Has a question for you", which the system shows in place of the body while previews are hidden (the Show Previews "When Unlocked" setting on a locked device, or "Never"). On Android the placeholder is not shown, because the notification is hidden from the lock screen instead (see "Answering a request from its notification"). While App Lock is on, or before its saved setting has loaded, approval and question notifications SHALL use those generic bodies on every platform, Android included, and SHALL carry no actions (see "Answering a request from its notification"). A request for a secret value, a sudo password or a vault prompt, and any request the app cannot answer, SHALL use "Waiting for you in Hermes" and SHALL NOT include anything about what is asked for.

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

#### Scenario: Android approval

- **WHEN** the agent asks for approval to run `rm -rf build` on Android and the app can answer it
- **THEN** the body is "rm -rf build"

#### Scenario: Android with App Lock on

- **WHEN** App Lock is on and the agent asks for approval to run `rm -rf build` on Android
- **THEN** the body is "Waiting for your approval" and the notification has no actions

#### Scenario: App Lock on

- **WHEN** App Lock is on and the agent asks for approval to run `rm -rf build`
- **THEN** the body is "Waiting for your approval" and the notification has no actions

#### Scenario: Secret or sudo request

- **WHEN** the agent asks for a secret value named `SERVICE_API_KEY` or for a sudo password
- **THEN** the body is "Waiting for you in Hermes" and does not mention the variable or the kind of request

#### Scenario: Failed reply

- **WHEN** a reply completes with failure and an error text
- **THEN** the body is "Reply failed"

### Requirement: Answering a request from its notification

On Android, iOS and macOS an approval or question notification SHALL carry actions that answer the request without opening the app. Every action SHALL require the device to be unlocked; on Android, where an action cannot demand authentication, the notification SHALL be posted with secret lock screen visibility, so that neither its text nor its actions show on a locked device and both appear once it is unlocked. Approval actions SHALL be "Allow once", "Allow for session", "Always allow" and "Deny", limited to and in the order of the choices the agent offered (`once`, `session`, `always`, `deny`); "Always allow" and "Deny" SHALL be marked destructive and SHALL NOT ask for confirmation. A question with one to four choices SHALL offer one action per choice, titled with the choice; a question with more than four SHALL offer the first three and "Other…", which opens the app on the chat. Every single question SHALL offer "Reply" (on Android as fitted below), a text input whose text is the answer. A multi-select question SHALL offer only "Reply" and "Open", and an open-ended question the same. A request with several questions and an approval that offers no choice the app knows SHALL carry no actions, only the placeholder. While App Lock is on, or before its saved setting has loaded, every approval and question SHALL carry no actions, only the placeholder, so that tapping the notification opens the app, which asks to be unlocked first. Turning App Lock on SHALL withdraw, on every platform, delivered notifications whose actions answer a request, and an action used while App Lock is on SHALL send nothing and post a notification for the chat with the body "Open Hermes to answer." Android shows at most three actions, so there the set SHALL be fitted: an approval SHALL offer its offered choices in that order, without "Always allow" when all four are offered; a question with one or two choices SHALL offer them and "Reply" (a text input labelled "Your answer"); a question with exactly three choices SHALL offer the three choices and no "Reply"; a question with more than three choices SHALL offer the first two and "Other…", which opens the app on the chat; a multi-select or open-ended question SHALL offer "Reply" and "Open". A request that the app cannot answer, and every request while App Lock is on or before its saved setting has loaded, SHALL be posted on Android with default visibility and no actions. A secret, sudo, vault or unsupported request SHALL carry no actions. Tapping the notification itself SHALL open the chat as before.

The category identifiers SHALL be `hermes.request.approval.<offered choices joined by ->`, `hermes.request.question`, `hermes.request.question.<hash of the action titles>`, and, with the placeholder alone, `hermes.request.approval` and `hermes.request.questions`; the action identifiers SHALL be `hermes.action.allow-once`, `hermes.action.allow-session`, `hermes.action.allow-always`, `hermes.action.deny`, `hermes.action.choice.0` to `hermes.action.choice.3`, `hermes.action.reply` and `hermes.action.open`, which "Other…" also uses.

An answer SHALL be sent with the gateway's `request.answer` RPC (`{id, result, profile}`, answered `{status: ok | expired}`; in the Hermes OpenRPC contract from `HERMES_REF` 167e9fd on): `{choice}` for an approval, `{answers: {<question id>: <answer>}}` for a question, where a multi-select reply is a JSON list holding the typed text. A request the server raised as an event frame (`approval.request`, `clarify.request`) rather than as a server-to-client request, which the notification records, and any request on a server that does not know `request.answer`, SHALL be answered the older way: an approval with `approval.respond` on the session resumed by its chat, a question with `clarify.respond`. A request `request.answer` reports `expired` SHALL NOT be resumed or answered another way. The app SHALL send it from the running app when it is running, including when iOS started a background launch for the action, and otherwise from the background launch (on Android, the notification plugin's background isolate), which signs in with the stored session. On Android the answering action SHALL remove the notification, and a failed answer SHALL post its follow-up in its place. It SHALL be sent once, and the outcome SHALL be known within 25 seconds of the moment the system handed the action to the app, in time to post a follow-up; nothing SHALL be sent after that. When the answer cannot be sent in that time, its outcome never comes back, the server reports the request `expired`, or nobody is signed in, the system SHALL post a notification for the same chat with the body "Couldn't send your answer. Open Hermes to answer.", which opens the chat when tapped.

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

#### Scenario: Android approval with all four choices

- **WHEN** the agent offers `once`, `session`, `always` and `deny` and the notification is shown on Android
- **THEN** it offers "Allow once", "Allow for session" and "Deny"

#### Scenario: Android question with two choices

- **WHEN** the agent asks "Which branch?" with the choices `main` and `dev` on Android
- **THEN** the notification offers "main", "dev" and "Reply"

#### Scenario: Android question with three choices

- **WHEN** the agent asks a question with the choices `main`, `dev` and `release` on Android
- **THEN** the notification offers "main", "dev" and "release" and no "Reply"

#### Scenario: Android question with six choices

- **WHEN** the agent asks a question with six choices on Android
- **THEN** the notification offers the first two choices and "Other…", which opens the chat

#### Scenario: Android lock screen

- **WHEN** an approval notification with actions arrives on a locked Android device
- **THEN** neither its text nor its actions show on the lock screen until the device is unlocked

#### Scenario: Android App Lock on

- **WHEN** App Lock is on and the agent asks a question on Android
- **THEN** the notification says "Has a question for you", has default visibility and carries no actions

#### Scenario: App not running

- **WHEN** the user picks "Allow once" while Hermes is not running
- **THEN** iOS starts it in the background, or Android runs the plugin's background isolate, it signs in with the stored session, and the approval is answered

#### Scenario: App Lock on

- **WHEN** App Lock is on and the agent asks a question
- **THEN** the notification says "Has a question for you" and carries no actions
