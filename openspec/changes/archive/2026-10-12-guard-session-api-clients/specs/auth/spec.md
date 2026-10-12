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

## MODIFIED Requirements

### Requirement: Gated servers load providers and check for a stored session

When auth is required, the system SHALL load the sign-in options from `GET /api/auth/providers` (each with a name, a display name that falls back to the name, and whether it supports password). It SHALL then read the stored session, except that credentials left by a failed departure/expiry deletion SHALL be treated as absent until fresh sign-in replaces them. With no stored session the state SHALL be needs login. With a stored session the system SHALL verify it with `GET /api/auth/me` and go to ready with the returned identity.

#### Scenario: No stored session

- **WHEN** auth is required and no session is stored
- **THEN** the state is needs login

#### Scenario: Valid stored session

- **WHEN** auth is required and a stored session passes `GET /api/auth/me`
- **THEN** the state is ready

#### Scenario: Providers cannot be loaded

- **WHEN** auth is required and the providers request fails
- **THEN** the state is connection error
- **AND** the message is the server's `detail` string if present, otherwise "Could not load sign-in options" for network failures

#### Scenario: Providers response is malformed

- **WHEN** auth is required and the providers response is not an object, its `providers` is not a list, or a row is not an object
- **THEN** the state is connection error
- **AND** the message is "Could not load sign-in options"

#### Scenario: Session check fails for a transient reason

- **WHEN** a stored session is found and the identity request fails because of a network error or a 5xx answer
- **THEN** the state is connection error
- **AND** the stored tokens are kept

#### Scenario: Identity response is malformed

- **WHEN** a stored session is found and the identity response is not an object or one of its fields has the wrong type
- **THEN** the state is connection error, also when the connect is restoring the saved address on launch
- **AND** the message is "Unexpected response from the server"
- **AND** the stored tokens are kept, so connecting again once the server answers correctly restores the session

#### Scenario: Stored session is dead

- **WHEN** a stored session cannot be refreshed because the server rejects the refresh token
- **AND** the applicable stored-token and saved-address deletions succeed
- **THEN** the stored tokens are cleared
- **AND** the state is needs login with the message "Your session expired. Please sign in again."

### Requirement: A 401 triggers one refresh and one retry

When a request on a gated server is answered with 401 and a session exists, the system SHALL refresh the session and retry that request once with the new access token. If the retried request also gets 401, the system SHALL treat the session as expired. If the session has no refresh token, the system SHALL treat it as expired immediately. If the refresh endpoint answers 400, 401 or 403, the system SHALL treat the session as expired. If the refresh fails for any other reason, such as a network error or a 5xx answer, the system SHALL keep the session and let the original request fail. A 401 while no session exists SHALL NOT change the connection state.

Treating the session as expired SHALL immediately disable protected requests and clear the in-memory session and identity, attempt stored-token deletion, announce account cleanup, and set the state to needs login. Successful deletion SHALL set the message "Your session expired. Please sign in again." Failed deletion SHALL report that the saved sign-in could not be removed while preserving recovery through fresh sign-in.

#### Scenario: Expired access token

- **WHEN** a request gets 401 and the refresh succeeds
- **THEN** the request is retried with the new token and succeeds
- **AND** the state stays ready

#### Scenario: Refresh token rejected

- **WHEN** a request gets 401 and the refresh endpoint answers 401
- **AND** the applicable stored-token and saved-address deletions succeed
- **THEN** the stored tokens are cleared
- **AND** the state is needs login
- **AND** the request fails

#### Scenario: Refresh endpoint unavailable

- **WHEN** a request gets 401 and the refresh endpoint answers 503
- **THEN** the request fails
- **AND** the stored tokens are kept
- **AND** the state stays ready

### Requirement: Sign-out and changing the server

Signing out SHALL retire old clients, clear the in-memory session and identity, attempt stored-token deletion, announce account cleanup, and SHALL go to needs login when the server requires auth and to ready when it does not. Changing the server SHALL retire old clients, attempt stored-token and saved-address deletion, announce account cleanup, forget the discovered server, providers, identity and clients, and go to needs server URL. Cleanup failures SHALL NOT prevent login/setup recovery; they SHALL report which saved data could not be removed and prevent reconnect from adopting credentials left by failed deletion. Both actions are available from the account menu; changing the server is also available on the login screen unless a sign-in is running.

#### Scenario: Sign out on a gated server

- **WHEN** the user signs out on a server that requires auth
- **AND** the applicable stored-token and saved-address deletions succeed
- **THEN** the stored tokens are removed
- **AND** the login screen is shown

#### Scenario: Sign out on an ungated server

- **WHEN** the user signs out on a server that does not require auth
- **THEN** the state stays ready

#### Scenario: Change server

- **WHEN** the user picks "Change server"
- **AND** the applicable stored-token and saved-address deletions succeed
- **THEN** the saved address and tokens are removed
- **AND** the server setup screen is shown

