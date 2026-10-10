# Spec Delta

## Purpose

Describes how the app runs Hermes work without a screen (for background refresh, App Intents and notification actions): which server and session it uses, when it gives up, how it refreshes tokens without ever signing the user out, its time budget, and how the foreground app takes over tokens that background work rotated.

## ADDED Requirements

### Requirement: Session for headless work

Headless work SHALL use the server the app has saved (or the server given at build time for development) and the session stored in secure storage. When the server reports that it requires no sign-in, it SHALL run without a session. It SHALL NOT start a sign-in, change the saved server or create a session. It SHALL end without doing anything, and without changing stored state, when no server is saved, no session is stored, secure storage cannot be read (on iOS: before the first unlock after the device started), or the server does not answer its status request.

Headless work SHALL report to its caller one of four outcomes, so the caller can tell the user what happened:

- done, with the work's result;
- signed out: no server saved, no session stored, or the server rejected the refresh token;
- locked: secure storage cannot be read yet;
- unreachable: the server did not answer, the refresh failed for another reason, the time budget ran out, or the work failed.

#### Scenario: Signed in, phone locked after first unlock

- **WHEN** the user is signed in, the phone was unlocked once since it started and is now locked, and background work runs
- **THEN** the work reaches the server with the stored session

#### Scenario: Phone not unlocked since restart

- **WHEN** the phone restarted and was not unlocked yet, and background work runs
- **THEN** the work ends without a request, reports locked, and the stored session is unchanged

#### Scenario: Nobody signed in

- **WHEN** no session is stored and background work runs
- **THEN** the work ends without a request and reports signed out

#### Scenario: Server unreachable

- **WHEN** the saved server does not answer
- **THEN** the work ends without a result, reports unreachable, and the user stays signed in

### Requirement: Headless work never signs the user out

Headless work SHALL NOT delete or overwrite a stored session because of an error. When the server rejects the access token, it SHALL refresh it at most once per run. When the refresh is rejected or fails, the work SHALL end without a result and leave the stored session as it was, for the app to deal with when it next runs in front.

#### Scenario: Refresh rejected in the background

- **WHEN** background work's refresh is rejected by the server
- **THEN** the work ends and reports signed out, the stored session is unchanged, and the app is still signed in when the user opens it (or shows sign-in only if its own refresh is rejected too)

### Requirement: Refreshing tokens alongside the app

Before refreshing, headless work SHALL re-read the stored session and use it without refreshing when it holds a different refresh token than the work started with. After a successful refresh it SHALL store the new pair only when storage still holds the refresh token it spent; otherwise it SHALL leave storage as it is.

The app in front SHALL do the same: before it refreshes, and when the server rejects its refresh, it SHALL re-read the stored session and, when that holds a different refresh token, use it instead of refreshing or signing the user out. Several rejected requests at once SHALL still lead to at most one refresh and SHALL NOT sign the user out (unchanged rule).

#### Scenario: Background rotated the tokens while the app was suspended

- **WHEN** background work refreshed and stored a new pair while the app was suspended, and the user opens the app, whose in-memory refresh token is now spent
- **THEN** the app uses the stored pair and the user stays signed in

#### Scenario: Both refresh at about the same time

- **WHEN** the app and background work present the same refresh token within a few seconds of each other
- **THEN** both receive the same new pair from the server and the user stays signed in

#### Scenario: App refreshed during background work

- **WHEN** the app stores a new pair while background work's refresh is in flight
- **THEN** background work does not overwrite the app's pair

### Requirement: Time budget

Headless work SHALL complete within a time budget given by its caller, 25 seconds by default, counting connection and work. When the budget runs out it SHALL close its connections, including any chat socket it opened, and end without a result. An error inside the work SHALL end it without a result and SHALL NOT be passed to the operating system as a crash.

#### Scenario: Slow server

- **WHEN** the work is still waiting for the server after 25 seconds
- **THEN** its socket is closed and it reports unreachable

### Requirement: Same data as the app

Headless work SHALL read Hermes through the same repositories and chat transport the app uses in front, so a row the app's screens skip as malformed is skipped headless too. It SHALL list the server's profiles, and fall back to the server's default profile when the list cannot be read. A chat transport it opens SHALL be closed when the work ends.

#### Scenario: Profiles listed

- **WHEN** the server has profiles `default` and `work`
- **THEN** headless work sees both

### Requirement: Telemetry without content

Each headless run SHALL record one span named `background.task` with the task name, its outcome (`ok`, `no_server`, `unreachable`, `no_session`, `locked`, `auth_failed`, `timeout`, `failed`) and the server attributes the app records for its connection. A refresh given up because storage changed SHALL be logged as `background.refresh_conflict`. The app in front adopting a stored pair SHALL be logged as `auth.session.adopted` with the trigger. None of these SHALL hold a token, server address, profile name, chat id or message text.

#### Scenario: Run with telemetry on

- **WHEN** telemetry is on and a background run succeeds
- **THEN** one `background.task` span with `outcome: ok` is exported and it holds no token or URL

### Requirement: Backend contract

Headless work SHALL rely only on routes the app already uses: `GET /api/status` (auth requirement and server attributes), `POST /auth/native/refresh` (which answers a repeat of the same refresh token within 30 seconds with the same pair), `GET /api/profiles`, and the `/api/ws` gateway with its ticket. It SHALL need no new Hermes route, RPC method or minimum version.

#### Scenario: Oldest supported Hermes

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** headless work runs as described
