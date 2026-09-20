## Decisions

**Skip is an empty answer, in either protocol form.** Server-to-client form: a response frame `{id, result: {value: ''}}`; the gateway's contract defines an empty `value` as "skipped / declined" for every one-string prompt. Event form (Hermes before 2026-09-14): `sudo.respond {request_id, password: ''}` or `secret.respond {request_id, value: ''}`; both tolerate a late reply and report `status: expired` when the request already ended, which the transport reports as "not accepted".

**Every secret and sudo request is registered, in both forms,** in the transport's open-request map, so a skip for an id the transport does not know (the turn ended, the request expired) answers false without sending anything. Without that, a stale server-request id would fall through to an event-form call the gateway may not have.

**The transport takes the kind.** `skipUnsupported(requestId, kind)` needs the kind only to pick the event-form method and key; the card already has it.

**Failure follows the approval card.** A skip that throws shows the same "Could not send your answer. Try again." and leaves the button usable; one that reports "no longer pending" locks the card as timed out.

**Another client may answer first.** A skip is a response like any other; whichever client answers first settles the request. The gateway drops a later response, and its `request.cancel` locks the card.

## Platforms and invariants

All platforms; Dart only, no native change. No auth, storage, API-layering or telemetry invariant is touched. The secret-handling rule of the existing capability is unchanged: nothing is collected or shown.
