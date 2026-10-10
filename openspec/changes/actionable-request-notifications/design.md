# Design

## Context

`AttentionNotifier` posts a notification through `LocalNotificationService` (`flutter_local_notifications` 22.3.1) when `attentionFor` says an event deserves one. Requests (`ApprovalRequested`, `ClarifyRequested`) get a fixed body. The watch relay (`WatchRequestHandler`) ends a watch send with a fixed text when the agent asks for anything.

Hermes (contract at `HERMES_REF` 167e9fd) raises approvals and questions as server-to-client requests (`approval`, `clarify`). They are kept on the server until answered, expired or cancelled: a reconnecting client gets them again in `session.resume`'s `open_requests`, and the transport already re-shows them from there. `request.answer {id, result, profile}` answers an open request "from a client that never received the frame": the server resolves it by id with no session attached and answers `{status: ok | expired}`. An approval's result is `{choice}` (`once`, `session`, `always`, `deny`); a clarify result is `{answers: {qid: string}}` for the whole set.

Platforms: iOS, macOS and watchOS (mirrored). Android, Windows and Linux are unaffected.

## Decisions

### Categories and actions

UNNotificationCategory actions have fixed titles, and the plugin only registers categories at `initialize`. So:

- Approval categories are static: one per non-empty subset of `once, session, always, deny`, in that order, id `hermes.request.approval.<choices joined with ->` (for example `hermes.request.approval.once-session-always-deny`). Fifteen categories, registered at start.
- `hermes.request.question` (Reply, Open) is static, for open-ended and multi-select questions.
- A question with choices gets a category made for it: `hermes.request.question.<hash>`, where the hash is FNV-1a (hex) of the button titles. It is registered just before the notification is posted.

Actions reuse fixed ids, whatever their titles:

| Action id                        | Title                             | Options                             |
| -------------------------------- | --------------------------------- | ----------------------------------- |
| `hermes.action.allow-once`       | Allow once                        | authenticationRequired              |
| `hermes.action.allow-session`    | Allow for session                 | authenticationRequired              |
| `hermes.action.allow-always`     | Always allow                      | authenticationRequired, destructive |
| `hermes.action.deny`             | Deny                              | authenticationRequired, destructive |
| `hermes.action.choice.0` to `.3` | the choice                        | authenticationRequired              |
| `hermes.action.reply`            | Reply (text input, button "Send") | authenticationRequired              |
| `hermes.action.open`             | Open, or Other…                   | authenticationRequired, foreground  |

"Other…" reuses the Open id: the plugin routes a response to the main isolate only for action ids it saw with the foreground option at `initialize`, and question categories with choices are registered later, natively.

The builder is top-level in `lib/src/notifications/request_notifications.dart`: `requestCategoryFor(InputRequest)` and `staticRequestCategories()`, both plain values, so a background refresh can post request notifications through the same function.

### Hidden-preview placeholders need native code

`DarwinNotificationCategory` has no `hiddenPreviewsBodyPlaceholder`. The plugin still registers the categories at `initialize`, because it records the foreground action ids it uses to route a response (foreground to the main isolate, the rest to the background engine). Right after, the Dart side calls a small native channel, `hermes_app/notification_categories`, `register`, with every category and its placeholder. It reads the current categories, replaces those with the same ids by copies that carry the placeholder, and sets them again. The channel also remembers the last 20 question categories in `UserDefaults` and re-adds them on each call, since every launch's `initialize` replaces the whole set and a question still in the notification centre would lose its buttons. Lives in `ios/Runner/AppDelegate.swift` and `macos/Runner/MainFlutterWindow.swift` (no new Xcode file references).

### Where an answer is sent from

On iOS the plugin hands every background action (no `foreground` option) to a separate headless engine and Dart isolate, which runs `onDidReceiveBackgroundNotificationResponse`, even when the main app is alive. It calls the system's completion handler at once, so the work needs its own background time. On macOS every action reaches the main isolate's `onDidReceiveNotificationResponse`, or the launch details when it started the app.

The main isolate's live transport cannot be reached from the background isolate, and does not need to be: `request.answer` works on any connection. So:

1. The main isolate registers a `SendPort` with `IsolateNameServer` as `hermes_app.request_answers` while it runs.
2. The background entry point (`answerRequestInBackground`) begins a UIKit background task (`hermes_app/background_task`, registered in the background engine by the plugin registrant callback), decodes the action, and sends it to that port when it is registered. The main isolate answers on a fresh gateway transport built from its `AuthController` (once it is ready), the same way the watch relay builds one, and replies with the outcome.
3. When no port is registered, the main isolate is not running in this process. The background isolate builds its own `AuthController`, runs `bootstrap()` (saved server, stored session, refresh when needed) and answers on a fresh transport. Only one isolate refreshes the token pair at a time this way, which keeps the "concurrent 401s must not sign the user out" invariant.
4. Any outcome but `ok` posts the follow-up notification, from whichever isolate sent the answer.

The answer itself is `ChatTransport.answerOpenRequest(requestId, OpenRequestAnswer, {profile})`, implemented with `request.answer`. A turn that is waiting on the request continues on the server, and whichever connection follows it (the chat screen's, the watch send's after a reconnect) sees the turn go on.

Alternatives: resume the session first and answer on the resumed connection (`approval.respond`, `clarify.lock`). Rejected: it attaches a second client to a live session for no gain, and `request.answer` is the method Hermes has for exactly this. A typed reply cannot reach a choice-only question that way either.

### Payload

The payload stays JSON with `t` (thread) and `p` (profile), so taps keep working. A request notification adds `n` (the chat title, for the follow-up) and `r`: `i` request id, `k` kind (`approval` or `question`), `q` question id, `m` multi-select, `c` the choice titles shown as buttons, in order. The action id and the text input are enough with it to build the answer.

### Bodies

Approval: the command, else the description, else "Waiting for your approval". Question: the question; a request with several questions keeps "Has a question for you" and gets no category. Text is cut at 1000 characters. Android keeps the generic bodies, because it has no hidden-preview placeholder per notification.

### Watch-sent turns

`WatchRequestHandler` keeps the send going on an approval or a question. It announces the actionable notification and marks the send as waiting (`approval` or `question`). The watch protocol stays request and reply, as a long poll:

- A `send` returns early with `{ok: true, threadId, waiting: 'approval' | 'question'}` when the send starts waiting.
- The watch shows the waiting text and sends the same `sendId` again. A retry of a send that is waiting returns the final reply, a change of the waiting state, or the same waiting answer after 20 seconds, so each call stays inside the phone's background time and each new watch message wakes the phone app again.
- While waiting, the silence timeout is 15 minutes instead of 60 seconds. Any event that continues the turn clears the waiting state.

The watch side is small: `SendResult.waiting`, a loop in `ConversationModel.send` and a `.waiting` phase that `ConversationView` shows in place of "Hermes is thinking…". It stays out of the quick-reply area.

### Relation to open changes

- `live-activities`: unchanged. It reuses `kApprovalBody` and `kQuestionBody` as its labels, which stay as the placeholders. The activity still carries no request text and gets no buttons.
- `apple-handoff`: unrelated. A follow-up tap opens the chat through the existing `NotificationTarget` path, which Handoff also feeds.

## Invariants touched

- Auth: the background isolate reuses `AuthController` (refresh, 401 handling) and refreshes only while the main isolate is not running.
- API layering: no REST route is added. `request.answer` is a gateway RPC in the OpenRPC contract.
- Telemetry: the `notification.answer` log event and the `notification.answered` breadcrumb carry kind, outcome and route only. Failures are swallowed.

## Risks

- Background time: the plugin completes the system handler before Dart runs. The background task covers about 30 seconds; a cold `bootstrap()` plus the answer usually fits. Not verified on a device.
- A user who answers in the app first gets the follow-up "Couldn't send" when they then tap the notification action (`expired`). Accepted: the brief treats a missing request as a failure.
- Dynamic categories are capped at 20; a question older than that loses its buttons and opens the app on tap.
