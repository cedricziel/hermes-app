## Why

The requested first Bot Mode release includes conversations with several specialists and messages between bots. Hosted rooms give those conversations one durable server log and driver so mobile suspension or another client opening the room does not duplicate work. A live hosted clarify request currently waits outside room state, so the group UI must explain that interactive requests may leave a member waiting and provide Stop.

## What Changes

- Add hosted group rows alongside bot conversations, with creation of named rooms containing 2–6 bots from the connected server.
- Render the durable room transcript with participant attribution, thread references, activity, and explicit failure states.
- Send text and @mentions through the server driver; expose Stop, exact pending approvals, and deliberate task retry.
- Resume room logs after reconnect and provide rename/disband management.
- Gate executable actions on advertised protocol 2 transport and driver readiness. Explain the unsupported clarify, sudo, and secret input limitation without collecting values.

## Capabilities

### New Capabilities

- `bot-mode-groups`: Hosted bot group conversations and room controls.

### Modified Capabilities

None.

## Impact

Depends on `bot-mode-group-protocol`. Affects bot roster room rows, new group repository/controller and transcript widgets, gateway reuse, lifecycle handling, tests, and Widgetbook. Uses hosted `groups.*` JSON-RPC methods over the authenticated dashboard socket.

Non-goals: Cross-server RoomLinks, authority promotion/replication administration, mutable membership, attachments, room pictures, and hosted clarify, sudo, or secret input. Same-server text groups remain executable with a visible limitation and Stop control.

Security and privacy impact: Group membership identifies profiles permitted to take turns. Only exact server pending requests can receive approval, using once/deny choices. The app does not create grants, change execution policy, or retain peer credentials. Room content is stored on the connected server and excluded from telemetry.

Telemetry: Existing opt-in RPC method/status tracing; no transcripts, room IDs, participant IDs, approval text, or arguments in added telemetry attributes.
