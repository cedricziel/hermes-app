# Auth Specification

## Purpose

Describes how the app finds a Hermes dashboard, decides whether sign-in is needed, signs the user in with the RFC 8252 native flow, keeps the session alive and signs the user out. This is a baseline of current behaviour, derived from the code and its tests.

## Requirements

### Requirement: Connection states drive the visible screen

The system SHALL expose exactly one connection state at a time: initializing, needs server URL, connecting, connection error, needs login, signing in, or ready. The screen shown SHALL follow from that state alone: a splash while initializing, the server setup screen for needs server URL, connecting and connection error, the login screen for needs login and signing in, and the main app shell for ready.

#### Scenario: Startup shows a splash

- **WHEN** the app has launched and has not yet finished restoring the saved server
- **THEN** the state is initializing
- **AND** a progress indicator is shown instead of any form

#### Scenario: Ready opens the app

- **WHEN** the state becomes ready
- **THEN** the main app shell is shown

### Requirement: Server address is restored or requested on launch

On launch the system SHALL connect to the saved server address if there is one, and SHALL otherwise ask the user for a server address.

#### Scenario: First launch with no saved address

- **WHEN** the app launches and no server address is saved
- **THEN** the state is needs server URL
- **AND** the server setup screen asks for a dashboard URL

#### Scenario: Launch with a saved address

- **WHEN** the app launches and a server address is saved
- **THEN** the system connects to that address as described in the server discovery requirement

### Requirement: Dev server override

When the `HERMES_SERVER_URL` compile-time define is non-empty, the system SHALL connect to that address on launch instead of the saved one, and SHALL NOT save it.

#### Scenario: Override wins over the saved address

- **WHEN** a dev server URL is defined and a different address is saved
- **THEN** the system connects to the dev server URL
- **AND** the saved address is left unchanged

#### Scenario: Override without a saved address

- **WHEN** a dev server URL is defined and no address is saved
- **THEN** the system connects to the dev server URL without asking the user

### Requirement: Server URL entry and normalization

The server setup screen SHALL require a non-empty URL before it submits. The system SHALL trim the entered text, assume `http://` when it has no scheme, accept only `http` and `https` addresses with a host, and remove trailing slashes from the path. An address that fails these rules SHALL put the app in the connection error state with a message asking for a valid http(s) URL, without contacting the network.

#### Scenario: Scheme is added

- **WHEN** the user submits `192.168.1.20:9119`
- **THEN** the system connects to `http://192.168.1.20:9119`

#### Scenario: Trailing slash is removed

- **WHEN** the user submits `https://hermes.example/`
- **THEN** the system connects to `https://hermes.example`

#### Scenario: Unsupported scheme

- **WHEN** the user submits `ftp://hermes.example`
- **THEN** the state is connection error
- **AND** the message is "Enter a valid http(s) URL, e.g. http://192.168.1.20:9119"

#### Scenario: Empty field

- **WHEN** the user submits the setup form with an empty field
- **THEN** the form shows "Enter a URL" and no connection is attempted

#### Scenario: Connect button while connecting

- **WHEN** the state is connecting
- **THEN** the Connect button is disabled and shows a progress indicator

### Requirement: Server discovery through the status route

The system SHALL discover a server by requesting `GET /api/status` without credentials, using an 8 second connect timeout and an 8 second receive timeout. It SHALL read from the response whether auth is required (`auth_required`, defaulting to false when absent), the registered provider names (`auth_providers`), the supported flows (`auth_flows`) and the version. The state SHALL be connecting while the request is in flight. The address SHALL be saved only after the status request succeeds, and only when the connect was not a dev override.

#### Scenario: Unreachable server

- **WHEN** the status request fails because the host cannot be reached or times out
- **THEN** the state is connection error
- **AND** the message is "Could not reach" followed by the address, unless the server sent a `detail` string, which is shown instead
- **AND** the address is not saved

#### Scenario: Status response is malformed

- **WHEN** the status response is not an object or one of its fields has the wrong type
- **THEN** the state is connection error, also when the connect is restoring the saved address on launch
- **AND** the message is "Unexpected response from the server"
- **AND** the address is not saved

#### Scenario: Successful discovery saves the address

- **WHEN** the status request succeeds
- **THEN** the normalized address is saved so the next launch reconnects to it

### Requirement: Servers without the auth gate skip sign-in

When the status response says auth is not required, the system SHALL go to ready without loading providers, requiring sign-in or reading stored tokens, and SHALL clear any session and identity it held.

#### Scenario: Loopback dashboard

- **WHEN** `/api/status` returns `auth_required: false`
- **THEN** the state is ready
- **AND** the login screen is never shown

### Requirement: Ungated dashboards are called with the page session token

For a server without the auth gate, the system SHALL send the session token embedded in the dashboard page (`__HERMES_SESSION_TOKEN__` on `GET /`) as the `X-Hermes-Session-Token` header on API requests. It SHALL fetch that token once and reuse it. When a request is answered with 401, it SHALL re-read the token once and retry that request once; a request that still gets 401 SHALL fail with 401.

#### Scenario: Token is fetched once and reused

- **WHEN** two API requests are made to an ungated dashboard
- **THEN** the dashboard page is fetched once
- **AND** both requests carry the token

#### Scenario: Dashboard restarted with a new token

- **WHEN** the dashboard restarts and the next request is rejected with 401
- **THEN** the system re-reads the page token and retries the request with it
- **AND** the request succeeds

#### Scenario: Token that is never accepted

- **WHEN** the dashboard keeps rejecting the token after the re-read
- **THEN** the request fails with 401

### Requirement: Gated servers load providers and check for a stored session

When auth is required, the system SHALL load the sign-in options from `GET /api/auth/providers` (each with a name, a display name that falls back to the name, and whether it supports password). It SHALL then read the stored session. With no stored session the state SHALL be needs login. With a stored session the system SHALL verify it with `GET /api/auth/me` and go to ready with the returned identity.

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
- **THEN** the stored tokens are cleared
- **AND** the state is needs login with the message "Your session expired. Please sign in again."

### Requirement: Login screen offers the advertised providers

The login screen SHALL show the server address and one button per provider from `/api/auth/providers`. A password-capable provider SHALL be labelled "Sign in with username & password"; any other SHALL be labelled "Sign in with" followed by its display name. If the server names its auth flows and `native_pkce` is not among them, the screen SHALL explain that the server does not support app sign-in instead of offering providers. If the server advertises no flows, providers SHALL still be offered. If there are no providers, the screen SHALL say that none are registered. The login screen SHALL show the current error message when there is one.

#### Scenario: Server supports the native flow

- **WHEN** the advertised flows include `native_pkce` and one provider named "Acme SSO" exists
- **THEN** the screen offers "Sign in with Acme SSO"

#### Scenario: Server lacks the native flow

- **WHEN** the advertised flows are non-empty and do not include `native_pkce`
- **THEN** no provider button is shown
- **AND** the screen says the server does not support app sign-in

#### Scenario: Server advertises no flows

- **WHEN** the advertised flows list is empty
- **THEN** the providers are still offered

### Requirement: Native sign-in uses the system browser, a loopback listener and PKCE

Every provider, OIDC or password, SHALL sign in through the same RFC 8252 flow. The system SHALL generate a fresh PKCE verifier (32 random bytes, base64url without padding), an S256 challenge and a random state value, and SHALL bind an HTTP listener on `127.0.0.1` on an OS-assigned port. It SHALL open the system browser at `/auth/native/authorize` with the query parameters `code_challenge`, `code_challenge_method=S256`, `redirect_uri=http://127.0.0.1:<port>/callback`, `state`, and `provider` when a provider name is known. The listener SHALL be running before the browser opens. When the callback carries an authorization code and the same state, the system SHALL redeem it with `POST /auth/native/token` carrying `code` and `code_verifier`, and SHALL read the bearer token set from the answer. Whatever the outcome, the listener SHALL be closed and any in-app browser sheet SHALL be closed. On iOS the browser SHALL be an in-app browser view so the listener stays active; on other platforms it SHALL be the external browser.

#### Scenario: Successful sign-in

- **WHEN** the browser redirects to the loopback callback with a code and the state the app sent
- **THEN** the system posts the code and verifier to `/auth/native/token`
- **AND** the token response becomes the session
- **AND** the browser sheet is closed

#### Scenario: The page shown after the redirect

- **WHEN** the loopback listener receives any request
- **THEN** it answers 200 with a small page telling the user they can close the tab, containing no tokens

#### Scenario: Stray requests are ignored

- **WHEN** the listener receives a request that carries neither a `code` nor an `error`, such as a favicon probe
- **THEN** the flow keeps waiting

#### Scenario: State mismatch

- **WHEN** the callback state differs from the state the app sent
- **THEN** the sign-in fails with a message naming a state mismatch
- **AND** no token request is made
- **AND** the browser sheet is closed

#### Scenario: Identity provider error

- **WHEN** the callback carries an `error` parameter
- **THEN** the sign-in fails with "Sign-in was rejected: " followed by the error and, when present, its description in parentheses

#### Scenario: Missing code

- **WHEN** the callback carries no code or an empty code
- **THEN** the sign-in fails with the message "Sign-in callback missing authorization code."

#### Scenario: Browser cannot be opened

- **WHEN** the system browser cannot be launched
- **THEN** the sign-in fails with "Could not open the system browser for sign-in."

#### Scenario: Redirect arrives before the launch call returns

- **WHEN** the browser redirects to the listener while the launch call is still pending
- **THEN** the redirect is answered and the sign-in completes

#### Scenario: Timeout

- **WHEN** no callback arrives within 5 minutes
- **THEN** the sign-in fails with "Sign-in timed out. Please try again."

#### Scenario: Token exchange is rejected

- **WHEN** the token request fails
- **THEN** the sign-in fails with the server's `detail` string when it sent one, and the HTTP status is kept for reporting

#### Scenario: Listener cannot start

- **WHEN** the loopback listener cannot bind
- **THEN** the sign-in fails with a message that the local sign-in listener could not start

#### Scenario: Closing the browser fails

- **WHEN** closing the browser sheet throws, for example because the user already dismissed it
- **THEN** the flow reports its own outcome and not the close error

### Requirement: Sign-in outcome and progress

While a sign-in runs, the state SHALL be signing in, and the login screen SHALL show a progress indicator, the text "Continue in your browser…" and a Cancel button, and SHALL disable the "Change server" action. On success the system SHALL store the session, load the identity with `GET /api/auth/me` and go to ready. On any failure it SHALL go to needs login and SHALL show the failure message. The state SHALL NOT remain signing in after a failure or cancellation, including a cancellation that arrives after the browser flow has already produced its result.

#### Scenario: Flow failure

- **WHEN** the native flow fails with a readable message
- **THEN** the state is needs login
- **AND** that message is shown

#### Scenario: Identity load fails after sign-in

- **WHEN** the token exchange succeeds and the identity request fails
- **THEN** the state is needs login
- **AND** the message is the server's `detail` string if present, otherwise "Sign-in succeeded but loading your profile failed" for network failures

#### Scenario: Unexpected error

- **WHEN** the sign-in raises an error of an unexpected type, such as a platform exception
- **THEN** the state is needs login
- **AND** the message is "Sign-in failed. Please try again."

#### Scenario: User cancels

- **WHEN** the user presses Cancel while waiting for the browser
- **THEN** the loopback listener is released and the browser sheet is closed
- **AND** the state is needs login without an error message

#### Scenario: Cancel during the token exchange

- **WHEN** the user cancels after the callback arrived but before the token response is processed
- **THEN** the session is discarded and never stored

#### Scenario: Cancel while the browser is closing

- **WHEN** the browser flow has already produced a session and the user presses Cancel while the browser sheet is still closing
- **THEN** the session is discarded and never stored
- **AND** the state is needs login without an error message
- **AND** the sign-in is recorded as cancelled

#### Scenario: Server changed while sign-in was finishing

- **WHEN** the user leaves the server (or signs out) while a sign-in is still completing
- **THEN** the late result is discarded and no token is stored
- **AND** the state stays where the user's action put it

### Requirement: Auth outcomes are reported without secrets

The system SHALL report the connection state changes and the outcome of each sign-in (started, succeeded, cancelled, failed) and refresh (refreshed, refresh failed, expired) through its telemetry hook. A failed sign-in SHALL carry only a fixed reason code, the HTTP status when there is one, the type name of an unexpected error, and non-sensitive context (whether the provider is password-based, and the elapsed time). It SHALL NOT carry the message text, tokens or codes.

#### Scenario: Failure is recorded by reason only

- **WHEN** a sign-in fails with a timeout
- **THEN** the recorded event has reason `timeout`
- **AND** it has no message field

### Requirement: Tokens are stored only in secure storage

The system SHALL keep the session (access token, refresh token, expiry, provider and user id) only in the platform secure storage (Keychain on iOS and macOS, Keystore-backed encrypted preferences on Android), under a single versioned key. It SHALL NOT use cookies or plain preferences for tokens. The saved server address is not a secret and SHALL be kept in ordinary preferences. A stored value that cannot be turned into a session (invalid JSON, JSON that is not an object, fields of the wrong type) SHALL be treated as signed out, and the stored value SHALL be deleted on a best-effort basis. A failure to read the secure storage (for example a locked keychain) SHALL also be treated as signed out for that launch, but the stored value SHALL be left in place.

#### Scenario: Session persists across launches

- **WHEN** the user signs in and the app restarts
- **THEN** the stored session is read and verified without asking the user to sign in again

#### Scenario: Corrupt stored value

- **WHEN** the stored value is not valid JSON
- **THEN** it is cleared and the user is treated as signed out

#### Scenario: Stored value is valid JSON but not a session

- **WHEN** the stored value is valid JSON that is not an object
- **THEN** the user is treated as signed out, the value is deleted, and the state is needs login, not left on connecting

#### Scenario: Secure storage cannot be read

- **WHEN** the secure storage throws while reading, for example because the keychain is locked
- **THEN** the user is treated as signed out for that launch and the state is needs login, not left on connecting
- **AND** the stored value is not deleted

### Requirement: Authenticated requests carry a fresh bearer token

Every request made through the authenticated client on a gated server SHALL carry `Authorization: Bearer <access token>` when a session exists. Before sending, the system SHALL refresh the session with `POST /auth/native/refresh` (body `refresh_token` and `provider`) when the access token expires within 60 seconds and a refresh token is available. An access token with no known expiry (the server left `expires_at` out) SHALL NOT be refreshed before a request; it is refreshed only after a 401. The rotated token set SHALL replace the stored session. If that refresh fails, the request SHALL still be sent with the existing token. Requests to the sign-in and refresh routes SHALL NOT use the authenticated client.

#### Scenario: Token near expiry

- **WHEN** the access token expires in less than 60 seconds and a request is made
- **THEN** the session is refreshed first
- **AND** the request carries the new access token
- **AND** the new token set is stored

#### Scenario: Proactive refresh fails

- **WHEN** the refresh before a request fails
- **THEN** the request is sent with the existing token

#### Scenario: Session has no refresh token

- **WHEN** the access token is near expiry and there is no refresh token
- **THEN** the request is sent with the existing token without a refresh

#### Scenario: Token has no known expiry

- **WHEN** the session has no expiry because the server left `expires_at` out, and several requests are made
- **THEN** the requests are sent with the existing token without a refresh
- **AND** a 401 still triggers one refresh and one retry

### Requirement: A 401 triggers one refresh and one retry

When a request on a gated server is answered with 401 and a session exists, the system SHALL refresh the session and retry that request once with the new access token. If the retried request also gets 401, the system SHALL treat the session as expired. If the session has no refresh token, the system SHALL treat it as expired immediately. If the refresh endpoint answers 400, 401 or 403, the system SHALL treat the session as expired. If the refresh fails for any other reason, such as a network error or a 5xx answer, the system SHALL keep the session and let the original request fail. A 401 while no session exists SHALL NOT change the connection state.

Treating the session as expired SHALL clear the stored tokens and identity, set the message "Your session expired. Please sign in again." and set the state to needs login.

#### Scenario: Expired access token

- **WHEN** a request gets 401 and the refresh succeeds
- **THEN** the request is retried with the new token and succeeds
- **AND** the state stays ready

#### Scenario: Refresh token rejected

- **WHEN** a request gets 401 and the refresh endpoint answers 401
- **THEN** the stored tokens are cleared
- **AND** the state is needs login
- **AND** the request fails

#### Scenario: Refresh endpoint unavailable

- **WHEN** a request gets 401 and the refresh endpoint answers 503
- **THEN** the request fails
- **AND** the stored tokens are kept
- **AND** the state stays ready

### Requirement: Concurrent refreshes and 401s do not sign the user out

The system SHALL run at most one refresh at a time and let concurrent callers share its result. A request whose 401 came from a token that another request has since rotated SHALL be retried with the current token instead of spending the already used refresh token. A refresh that completes after the session was cleared or replaced, for example by sign-out, SHALL be discarded and SHALL NOT restore the old session.

#### Scenario: Two requests fail with 401 at once

- **WHEN** two requests are rejected with 401 for the same revoked token, with one rejection arriving after the other request finished rotating the tokens
- **THEN** exactly one refresh is made
- **AND** both requests end up succeeding
- **AND** the state stays ready and the stored session holds the rotated tokens

#### Scenario: Sign-out during a refresh

- **WHEN** the user signs out while a refresh is in flight
- **THEN** the refreshed tokens are not stored
- **AND** the stored session stays empty

### Requirement: Sign-out and changing the server

Signing out SHALL delete the stored session and the identity, and SHALL go to needs login when the server requires auth and to ready when it does not. Changing the server SHALL delete the stored session and the saved address, forget the discovered server, providers, identity and clients, and go to needs server URL. Both actions are available from the account menu; changing the server is also available on the login screen unless a sign-in is running.

#### Scenario: Sign out on a gated server

- **WHEN** the user signs out on a server that requires auth
- **THEN** the stored tokens are removed
- **AND** the login screen is shown

#### Scenario: Sign out on an ungated server

- **WHEN** the user signs out on a server that does not require auth
- **THEN** the state stays ready

#### Scenario: Change server

- **WHEN** the user picks "Change server"
- **THEN** the saved address and tokens are removed
- **AND** the server setup screen is shown

### Requirement: Backend contract

The system SHALL rely on these dashboard routes for auth and connection: `GET /api/status` (public; `auth_required`, `auth_providers`, `auth_flows`, `version`), `GET /api/auth/providers` (public; a `providers` list of `name`, `display_name`, `supports_password`), `GET /auth/native/authorize` (opened in the browser), `POST /auth/native/token` (`code`, `code_verifier` in; `access_token`, `refresh_token`, `expires_at` in Unix seconds, `provider`, `user_id` out), `POST /auth/native/refresh` (`refresh_token`, `provider` in; the same token set out) and `GET /api/auth/me` (`user_id`, `email`, `display_name`, `org_id`, `provider`). A token response with no `access_token` SHALL be treated as a failure. Missing optional fields SHALL be read as empty values.

#### Scenario: Token response without an access token

- **WHEN** the token or refresh response has no `access_token`
- **THEN** the sign-in or refresh fails and no session is created
