# Spec Delta

## ADDED Requirements

### Requirement: A response is confirmed or reported unconfirmed within 10 seconds

The app SHALL end the wait for a connection response within 10 seconds of sending it. A failed call and a missing confirmation SHALL be reported as unconfirmed, and a refused response (a status other than ok) as refused; both SHALL re-enable the response actions while the operation still has authority. A method-not-found result SHALL keep marking responses unavailable.

#### Scenario: The server does not answer

- **WHEN** connection.respond has no result after 10 seconds
- **THEN** the operation reports an unconfirmed answer and Skip and Continue are offered again
- **AND** no second connection.respond call was made

#### Scenario: The server refuses

- **WHEN** connection.respond returns a status other than ok
- **THEN** the operation reports a refusal, not an unconfirmed answer

### Requirement: A late result never replaces or repeats a response report

The app SHALL NOT resend a response automatically. A transport error arriving after the 10 second report SHALL NOT replace it or log a second outcome, and a settlement that arrives after the report SHALL still settle the operation.

#### Scenario: The transport fails after the report

- **WHEN** the transport reports its own timeout after the 10 second report
- **THEN** the card keeps the unconfirmed state and no second outcome is logged

## MODIFIED Requirements

### Requirement: Only supported responses are offered

The app SHALL offer an explicit browser-open action only for a valid HTTPS connect_url with no embedded credentials. It SHALL not claim connected because the browser opened or returned. For targets that support the existing response contract, Skip SHALL send the corresponding skipped target outcome through connection.respond, and Continue SHALL use settled_by continue. The app SHALL disable duplicate submissions while awaiting the RPC result, until the 10 second bound reports the answer unconfirmed or refused, and display refusal without optimistic settlement. Targets requiring env values or unsupported installation actions SHALL show that this app cannot complete them.

#### Scenario: A browser connection is opened

- **WHEN** the user returns without a connected update
- **THEN** the target keeps its reported state and is not marked connected

### Requirement: Actions require current operation authority

Browser and response actions SHALL require a currently confirmed physical connection, runtime owner, and known profile. Missing or mismatched authority SHALL produce read-only details with connect URLs omitted and no browser, Skip, or Continue controls. While the physical connection is lost and the scope is not retired, the app MAY keep a display-only model of an unsettled operation (target names, states, deadline text) with no connect URL, authority or response timer (the deadline still removes it), for the Needs-you card. Genuine global account updates SHALL appear only as clearly labeled connection-wide read-only activity until app-origin profile authority is established; they SHALL NOT acquire the selected conversation or profile as their owner. The app SHALL release operation details and deadline timers on runtime/profile/account retirement, reclaim, conversation removal or retarget, and protected activity loss, and the display-only model SHALL be released with them.

#### Scenario: An account update has no profile provenance

- **WHEN** a global account connection update arrives without trustworthy profile authority
- **THEN** the app shows connection-wide read-only activity with no connect URL or response action
- **AND** the selected conversation does not own that operation

#### Scenario: Scope retires before a response is sent

- **WHEN** a pending notification or request instrumentation callback retires the operation's current authority
- **THEN** no response bytes are sent and no later result can settle a replacement operation

#### Scenario: A stale displayed card is activated

- **WHEN** the user activates a card after its snapshot or attachment has been replaced
- **THEN** the old card cannot open a browser or respond for the replacement scope

#### Scenario: The connection drops

- **WHEN** the connection is lost with an unsettled operation and the scope is not retired
- **THEN** only a display-only model without connect URL or authority remains
