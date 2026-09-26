## Why

While Hermes replies, the chat refuses a new prompt on that thread ("Hermes is still replying…"). A user who has the next question ready has to watch the reply, keep the text in the composer and come back to send it. They should be able to write and send while the agent works, and have their prompts go out in order once it is done.

## What Changes

- Sending on a thread whose reply is pending queues the prompt, text and attachments, instead of refusing it. The composer is cleared as for any accepted send.
- The queued prompts of the open thread show above the composer, in order, each with a button to remove it. While the thread replies the composer's hint reads "Queue a message…".
- When a reply ends normally, the first queued prompt is sent as a new turn. The rest wait for its reply, and so on. A turn Hermes chains on its own (a goal continuation) counts as a reply the queue waits for.
- When the user stops the reply, or it fails, the queue pauses instead of sending. The queue then offers "Send now", which sends its first prompt. A prompt sent on a thread with a paused queue joins the end of the queue and the first one is sent.
- The queue is held on the device while the app runs. It is dropped when the chat's threads reload on another profile, and on a restart.
- The "Sending a message" requirement no longer refuses a send on a thread with a pending reply.

## Impact

- Chat: `ChatController.submit` in `lib/src/chat/chat_controller.dart`, a new `QueuedPrompts` widget in `lib/src/chat/widgets/`, the composer builder and `ChatScreen`.
- Widgetbook: a use case for the queue, running and paused.
- Tests: `test/chat_one_turn_test.dart` changes from "refused" to "queued"; new controller and widget tests.
- No change to the generated API client and no new backend route or RPC method. Each queued prompt goes out with the same `session.resume` and `prompt.submit` a typed one uses.

## Non-goals

- Editing a queued prompt in place. It can be removed and typed again.
- Steering a running turn (injecting a prompt into it). Queued prompts start new turns.
- Using a server-side queue. The gateway has none the app can drive, so the queue lives in the app.
- Keeping the queue across a restart or a profile switch.

## Security and privacy impact

None. Queued text and attachment paths stay in memory on the device and go out through the same transport as a typed prompt.

## Telemetry

None. No span, log event or attribute is added.
