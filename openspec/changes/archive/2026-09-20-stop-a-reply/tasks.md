## 1. Model and policy

- [x] 1.1 Test first: a stopped completion keeps streamed text or reads "Stopped.", and a stopped reply is not announced
- [x] 1.2 Add the `stopped` flag to the completion event, apply it to the reply and exempt it from notifications

## 2. Transport

- [x] 2.1 Test first: `stopReply` interrupts the runtime session of a created or resumed thread, reports not stopped for `not_interrupted`, an unknown thread or an ended reply, and an `interrupted` completion is mapped to stopped
- [x] 2.2 Add `stopReply` to the transport interface, the gateway transport and the fake, and map the status

## 3. Composer and screen

- [x] 3.1 Test first: Stop shows only while a reply is in flight, stops that thread, is gone once the reply ended, sending works again, and a failed stop says so and stays available
- [x] 3.2 Add the bar to the composer and wire it through the screen

## 4. Wrap up

- [x] 4.1 Telemetry: none added
- [x] 4.2 No `.claude/skills` entry is made stale by this
- [x] 4.3 Sync the deltas into the specs and archive the change
- [x] 4.4 Verify: dart format, flutter analyze, flutter test, `openspec validate --strict`; the interrupt is not checked against a live gateway, and no verify-in-app run was made
