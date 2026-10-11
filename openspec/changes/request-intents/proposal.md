# Proposal

## Why

When Hermes waits for an approval, the user may be away from the phone's screen: on a walk with AirPods, in the car, or running a morning Shortcut. "Hey Siri, what does Hermes need?" should say what is waiting, and an approval the user has already judged should be answerable without opening the chat. The notifications rollout gives approvals buttons; Siri and Shortcuts should reach the same requests.

## What Changes

- A "Pending Requests" App Intent that answers in place: how many requests wait across all profiles, and for each its chat's title and kind ("Trip plan is waiting for your approval", "Backup has a question for you"). Shortcuts gets the count and the list. It never says the command or the question.
- An "Answer Approval" App Intent with a Request parameter (the open approvals) and an optional Choice (Once, This session, Always, Deny). It looks the approval up live, offers only the choices Hermes offers for it, shows and speaks the command in a confirmation step, then answers it. It needs the device unlocked.
- A Pending Request entity for the Request parameter, from the pending list the app shares with the system (`surface-snapshot`).
- Both take an optional Profile; without it, "Pending Requests" covers every profile and "Answer Approval" offers every profile's approvals.
- App Shortcut phrases "What does Hermes need", "Hermes requests" and "Pending Hermes requests". "Answer Approval" has no phrase (it needs a request picked) but can be run from Siri by name and from Shortcuts.
- Both run in the app's process: a small bridge in the Runner starts a background Flutter engine, and Dart works through the headless runtime.

Non-goals:

- No answering clarifying questions, secrets or sudo requests by intent; only approvals.
- No "approve everything" (`all: true`).
- No proactive Siri announcement of new requests; that is notifications.
- No Android, macOS or watch equivalent.

Security and privacy impact:

- "Pending Requests" runs on a locked device (like "Ask Hermes") and says chat titles and request kinds, which notifications already show on the Lock Screen; it never says a command, question or secret name. With Hermes' App lock on it says the count only.
- "Answer Approval" runs only after the device is unlocked (`requiresAuthentication`), because it can let the agent run a command. The command is shown and spoken in the confirmation step, so it can be heard by people nearby; the user started the intent. The command never reaches the App Group, the snapshot or telemetry.
- Tokens are read by the headless runtime only (Contract 3).

Observability:

- Span `background.task` with `task` = `intent.pending` or `intent.answer_approval`, `engine` and `result` (`answered`, `none`, `gone`, `failed`, `signed_out`, `device_locked`, `unreachable`, `app_locked`). Each crosses into Dart and the gateway.
- Log event `intent.answer_approval` with `outcome` and `choice` (`once`, `session`, `always`, `deny`): approving from Siri is a security-relevant action worth counting.
- None carries a command, title, profile name or id.

## Capabilities

### New Capabilities

- `request-intents`: the "Pending Requests" and "Answer Approval" App Intents, the Pending Request entity, and the gateway calls they rely on.

### Modified Capabilities

None.

## Impact

- Swift (`ios/HermesSurfaceKit`): `PendingRequestEntity`, `ApprovalChoice`, `PendingRequestsIntent`, `AnswerApprovalIntent`; phrases in `HermesAppShortcuts`; `RequestIntentsBridge` in the Runner (a background Flutter engine on the `hermes_app/request_intents` channel).
- Dart: `lib/src/intents/request_intents.dart`; one read-only gateway call on the transport that lists the approvals of one session. Answering goes through #587's `RequestAnswerSender` and `ChatTransport.answerOpenRequest`; no answering method is added.
- Builds on #587 (on main) (`answerOpenRequest`, `RequestAnswerSender`), `headless-runtime` (`withHeadlessHermes`, `HeadlessOutcome`), `background-refresh` (`OpenRequestsStep`, `refreshSnapshot(pending:)`), `surface-snapshot` (`pending` rows) and `app-intents` (Profile entity, shortcuts provider). It does not wait for `ask-hermes-intent`: it has its own bridge, and the two may be merged once both are on main.
- Backend: no new routes. Uses `session.active_list` and `approval.pending`, and through #587 `request.answer` (falling back to `approval.respond`).
