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

On iOS the plugin hands a background action (no `foreground` option) to a separate headless engine and Dart isolate, which runs `onDidReceiveBackgroundNotificationResponse`, even when the main app is alive. But it only hears of the response through a Flutter engine's plugins, and a launch for such a button makes no scene and so no engine (the app uses the UIScene life cycle, and plugins are registered in `didInitializeImplicitFlutterEngine`): the response would be dropped and the completion handler never called. On macOS every action reaches the main isolate's `onDidReceiveNotificationResponse`, or the launch details when it started the app; the launch answer is handed over once, however many screens read the launch target.

So the iOS Runner owns the notification center's delegate from `didFinishLaunching` on (`NotificationActions` in `AppDelegate.swift`). For a `hermes.action.*` other than Open it begins a UIKit background task, starts the plugin's headless engine itself with its public `FlutterEngineManager` and `ActionEventSink` (the same engine, dispatcher and payload shape the plugin uses), hands it the response and calls the completion handler. Every other response, and `willPresent`, goes on to the app delegate, which passes it to the plugins as before. The plugin registrant callback is set in `didFinishLaunching` too, and registers only what the headless engine needs: the notifications plugin, secure storage, shared preferences, and the Runner's `hermes_app/background_task` and `hermes_app/notification_categories` channels. Each background task is ended once, by Dart when its answer is done (oldest first) or by its expiry.

The main isolate's live transport cannot be reached from the background isolate, and does not need to be: `request.answer` works on any connection. So:

1. The main isolate registers a `SendPort` with `IsolateNameServer` as `hermes_app.request_answers` while it runs.
2. The background entry point (`answerRequestInBackground`) sets one deadline, 25 seconds from the action, and looks for that port for up to 3 seconds (an app started by the same launch registers it a moment later). The hand-off has two steps: the main isolate offers to take the action, and sends it only after the background isolate confirms. An offer that comes after 3 seconds finds the background isolate gone alone, so it is never confirmed and the answer never goes out twice. The main isolate answers on a fresh gateway transport built from its `AuthController` (once it is ready), the same way the watch relay builds one, and gives up 3 seconds before the deadline so its follow-up is posted in time.
3. When no app takes the action, the background isolate answers alone through one `LoneAnswerer` per isolate: one `AuthController`, bootstrapped from the saved server and stored session, and answers one at a time, inside the same deadline.
4. Any outcome but `ok` posts the follow-up notification, from whichever isolate sent the answer. The background isolate never posts one for an answer the app took.

Two isolates can still hold the same refresh token: a background answer and an app the user opens meanwhile. `AuthController` therefore re-reads the token store when a refresh is rejected, and takes over a newer pair it finds there instead of signing the user out (`auth.session.adopted`). This is the general fix; the serialization above only makes the race rarer.

The answer itself is `ChatTransport.answerOpenRequest(requestId, OpenRequestAnswer, {threadId, profile})`, implemented with `request.answer`. A server that raised the request as an event frame (`approval.request`, `clarify.request`) cannot resolve it that way: an approval `request.answer` reports `expired` is tried again with `approval.respond` on the session `session.resume` returns for its chat, and a question without a question id goes straight to `clarify.respond`. A turn that is waiting on the request continues on the server, and whichever connection follows it (the chat screen's, the watch send's after a reconnect) sees the turn go on.

Alternatives: resume the session first and answer on the resumed connection for every request. Rejected: it attaches a second client to a live session for no gain, and `request.answer` is the method Hermes has for exactly this.

### App Lock

While App Lock is on (and until its saved setting has loaded) requests are announced with the generic body under a category with the placeholder and no actions (`hermes.request.approval`, `hermes.request.questions`), so nothing is answered past the lock: tapping opens the app, which asks to unlock first. The same placeholder-only categories serve an approval without a choice the app knows and a request with several questions. `AttentionNotifier` and the watch relay read `appLockHidesRequests(AppLockController)`.

### Payload

The payload stays JSON with `t` (thread) and `p` (profile), so taps keep working. A request notification adds `n` (the chat title, for the follow-up) and `r`: `i` request id, `k` kind (`approval` or `question`), `q` question id, `m` multi-select, `c` the choice titles shown as buttons, in order. The action id and the text input are enough with it to build the answer.

### Bodies

Approval: the command, else the description, else "Waiting for your approval". Question: the question; a request with several questions keeps "Has a question for you" and gets the placeholder-only category. Text is cut at 1000 characters. Android keeps the generic bodies, taken from the category's placeholder, which every approval and question now has, because Android has no hidden-preview placeholder per notification.

### Watch-sent turns

`WatchRequestHandler` keeps the send going on an approval or a question, but only for a watch that says it can (`waits: true` on the request) and only when an answerable notification was posted: the announcer reads the saved setting first on a cold wake and reports nothing posted while notifications are off or denied, and App Lock posts no buttons. Otherwise the send ends as before. The watch protocol stays request and reply, as a long poll:

- A `send` returns early with `{ok: true, threadId, waiting: 'approval' | 'question'}` when the send starts waiting.
- The watch shows the waiting text and asks again with the same `sendId`, the bound chat and `retry: true`, for at most 20 minutes. A retry returns the final reply, at once a state that differs from the one the watch was last told (stored on the attempt; `working` once the turn goes on), or the same waiting answer after 20 seconds, so each call stays inside the phone's background time and each new watch message wakes the phone app again. A phone that has forgotten the send (iOS ended the app) reads the chat for a `retry` instead of sending again.
- The send tracks every open request id. An expired or withdrawn request leaves the others open, and a turn-progress event is taken as the oldest open request answered, since the app is not told which one was. While any is open the silence timeout is 15 minutes instead of 60 seconds.
- When a retry fails, the watch keeps the message and its "Try again" asks with `retry`. "Stop waiting" ends the wait on the watch, keeps the message and frees the chat.

The watch side: `SendResult.waiting`, the loop and `stopWaiting()` in `ConversationModel`, and a `.waiting` phase that `ConversationView` shows in place of "Hermes is thinking…", with the Stop waiting button. It stays out of the quick-reply area.

### Relation to open changes

- `live-activities`: unchanged. It reuses `kApprovalBody` and `kQuestionBody` as its labels, which stay as the placeholders. The activity still carries no request text and gets no buttons.
- `apple-handoff`: unrelated. A follow-up tap opens the chat through the existing `NotificationTarget` path, which Handoff also feeds.

## Invariants touched

- Auth: the background isolate reuses `AuthController` (refresh, 401 handling), one per isolate with answers one at a time, and a rejected refresh adopts a newer pair another isolate stored, so concurrent refreshes across isolates do not sign the user out.
- API layering: no REST route is added. `request.answer` is a gateway RPC in the OpenRPC contract.
- Telemetry: the `notification.answer` log event and the `notification.answered` breadcrumb carry kind, outcome and route only. Failures are swallowed.

## Risks

- Background time: the background task is begun natively as the button arrives and covers about 30 seconds; the answer works to a 25-second deadline. Not verified on a device, nor is the cold launch through the Runner's own delegate.
- The Runner uses the plugin's `FlutterEngineManager` and `ActionEventSink`, public headers but not documented API; a plugin upgrade must be checked against them.
- The background engine is never shut down once started, as in the plugin.
- A user who answers in the app first gets the follow-up "Couldn't send" when they then tap the notification action (`expired`). Accepted: the brief treats a missing request as a failure.
- Dynamic categories are capped at 20; a question older than that loses its buttons and opens the app on tap.
