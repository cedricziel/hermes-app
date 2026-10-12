## ADDED Requirements

### Requirement: Protected HTTP clients stay within their session owner

An application API client SHALL NOT dispatch requests, attach credentials, refresh, retry, or expose responses after its server/owner lifetime is retired. Explicit sign-out, server departure, a change between anonymous and gated access, or a different verified account SHALL permanently retire old clients. Session expiry SHALL suspend protected HTTP access immediately before asynchronous credential cleanup; verified same-owner sign-in SHALL permit new requests through retained clients, while pre-expiry requests remain invalidated.

#### Scenario: Departure cleanup is slow
- **WHEN** sign-out or server departure begins while token deletion is pending
- **THEN** requests through old application clients fail locally without reaching the server

#### Scenario: Another account signs in
- **WHEN** a different verified account signs in on the same server after expiry
- **THEN** an old client cannot attach the new account's credentials or affect its session through an old response

#### Scenario: Same account returns
- **WHEN** the same verified owner reauthenticates after expiry
- **THEN** retained clients can make new requests while requests begun before expiry cannot retry or expose late responses

#### Scenario: Concurrent token refresh
- **WHEN** concurrent requests rotate or adopt tokens for the same owner
- **THEN** existing refresh deduplication and retry behavior remains valid without retiring that owner

### Requirement: Recovery proof uses verified account identity

The system SHALL expose recovery ownership only from a nonempty server-verified user ID scoped to the normalized server, organization, and provider. Expiry SHALL retain the previous verified owner as recovery proof. Missing identity SHALL provide no restoration proof. Display names, email addresses, and token strings SHALL NOT establish ownership.

The backend contract SHALL remain GET /api/status, GET /api/auth/providers, GET /api/auth/me and the existing native token/refresh endpoints with their existing response shapes. No new route, RPC method, or minimum Hermes Agent version SHALL be required.

#### Scenario: Missing identity
- **WHEN** the identity response has no nonempty user ID
- **THEN** it supplies no draft-restoration ownership proof

#### Scenario: Changed identity scope
- **WHEN** user, organization, provider, or normalized server differs
- **THEN** it does not match the retained recovery owner

### Requirement: Credential mutations cannot cross invalidation

Credential writes and clears SHALL be ordered so obsolete work cannot restore a departed session or delete a newer sign-in. Sign-in verification SHALL use its candidate credential without an old protected client replacing it. Bootstrap verification SHALL retain existing stored-session refresh behavior through a narrowly scoped allowance.

#### Scenario: Old write completes after departure
- **WHEN** an old credential write finishes after its operation is invalidated
- **THEN** it is cleared before a later valid credential write can complete

#### Scenario: New sign-in waits for cleanup
- **WHEN** sign-in is requested during pending departure cleanup
- **THEN** cleanup completes before that sign-in starts and cannot later clear its credentials

#### Scenario: Candidate and bootstrap verification
- **WHEN** a candidate token or a stored session is verified
- **THEN** the candidate is verified with its own token and stored-session verification retains existing refresh behavior

#### Scenario: Credential deletion fails during expiry
- **WHEN** secure-storage deletion fails after a session expires
- **THEN** protected requests remain blocked, account cleanup is announced, and login remains recoverable with an error explaining that the saved sign-in could not be removed

#### Scenario: Older authentication operations finish
- **WHEN** a pending connect resumes after explicit sign-out or an abandoned sign-in fails after a newer navigation/authentication state
- **THEN** that obsolete operation cannot restore credentials or replace the newer state

#### Scenario: Explicit departure cleanup fails
- **WHEN** token deletion or saved-server preference removal fails during explicit sign-out or server departure
- **THEN** old clients remain retired, account cleanup is announced, the login/setup state remains reachable with a truthful cleanup error, and credentials left by failed deletion cannot be restored through reconnect
