## Context

ChatController holds a stable ChatTransport, while HermesGatewayTransport.close permanently disposes its connection. Retained screens need a replaceable delegate without changing controller transport identity.

## Goals / Non-Goals

Provide synchronous suspension, stale-result fencing, subscription cancellation, explicit renewal, and permanent retirement. Do not decide account ownership or wire retained UI in this change.

## Decisions

The proxy receives a delegate factory. Suspension increments an operation epoch and closes the gate before asynchronous cleanup. Futures capture that epoch and reject stale successes and failures. Streams capture it at invocation, reject late subscription, and stop relaying after suspension. Cancel tracked subscriptions before closing their delegate. A later resume creates a fresh delegate; old cleanup cannot clear it. Permanent close prevents renewal.

GatewayRequester preserves the existing request signature. PromptAcknowledgement remains a separate optional capability. Preserve acknowledgement of the latest submitted prompt through suspension and renewal until another prompt is actually submitted, so connection teardown does not imply that an accepted question can safely be repeated. Authentication integration must verify owner identity and generation before calling resume.

## Risks / Trade-offs

Cancellation cannot recall requests already dispatched to the server. Integration must reconcile ambiguous operations rather than automatically resubmitting. Proxy tests establish lifecycle semantics, not full draft preservation or native connection behavior.

## Migration Plan

Introduce and test the contract without app wiring. Integrate activity suspension in a subsequent bounded change before retaining the navigator.

## Open Questions

None for this contract. Full main and auxiliary-window draft preservation remains open work.
