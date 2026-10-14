## Purpose

Lets users continue a saved Hermes chat on another Apple device through Handoff while preserving dashboard identity, profile ownership, independent authentication, and app lock.

## ADDED Requirements

### Requirement: Advertise the visible saved chat

On iOS, iPadOS, and macOS, the app SHALL advertise the visible saved chat as a Handoff activity when the connection is ready, the app is unlocked, and the chat has an explicit profile. The activity SHALL identify the dashboard, profile, and thread. Unsaved chats and hosted group rooms SHALL NOT be advertised. The app SHALL withdraw the activity when the chat ceases to be visible, is deleted, the app locks, or the connection leaves ready state. Backgrounding alone SHALL NOT withdraw it when app lock is off. No Handoff integration SHALL run on Android, Windows, Linux, or watchOS.

#### Scenario: Switch saved chats

- **WHEN** an unlocked user switches from one saved chat to another
- **THEN** the outgoing activity identifies the newly visible chat and its profile

#### Scenario: Leave or lock the chat

- **WHEN** the user leaves the chat, opens another screen over it, selects an unsaved chat, deletes it, or locks the app
- **THEN** the previous chat is no longer advertised

#### Scenario: Move to another device

- **WHEN** the source app enters the background with app lock off and an eligible chat open
- **THEN** backgrounding alone does not invalidate its Handoff activity

### Requirement: Minimal versioned activity contract

The activity SHALL use `com.cedricziel.hermesApp.continueChat` for release builds and a distinct `.dev` variant for development builds. Both apps participating in a continuation SHALL support the same activity type and use the same Apple developer Team ID. Version 1 SHALL contain `version: 1`, an absolute HTTP or HTTPS `serverUrl` with a host, a non-empty `profile`, and a non-empty `threadId`. URLs SHALL NOT contain user information, query parameters, or fragments. The serialized payload SHALL be smaller than 3 KB. The activity SHALL use a generic title and SHALL NOT expose chat titles, transcripts, credentials, drafts, attachments, or queued messages. Search and public indexing SHALL be disabled. An unsupported version or malformed payload SHALL be rejected before any network request or server change.

#### Scenario: Unsupported incoming payload

- **WHEN** an incoming activity has an unknown version, invalid URL, empty identity, wrong field type, or oversized payload
- **THEN** the app reports that the activity cannot be continued without changing the connection or fetching history

#### Scenario: No explicit profile

- **WHEN** a saved chat has no resolved profile
- **THEN** the app does not advertise an identity that could resolve against another device's default profile

### Requirement: Receive after startup and unlock

The app SHALL receive Handoff activities during cold launch and while running. It SHALL retain at most one validated pending target in memory until initialization, connection, sign-in, app unlock, and chat readiness permit restoration. A newer incoming target SHALL replace an older pending target. The app SHALL NOT persist the target across process termination. Native startup delivery and runtime notification of the same receipt SHALL NOT cause duplicate restoration. The app SHALL NOT advertise an unrelated chat while continuation is pending.

#### Scenario: Cold launch while locked

- **WHEN** Handoff launches the app with app lock enabled
- **THEN** the app retains the target and shows no connection prompt or target chat before unlock
- **AND** after unlock and successful connection and sign-in it opens the target

#### Scenario: Sign-in required

- **WHEN** a valid target arrives for the configured dashboard and the app needs sign-in
- **THEN** the existing sign-in flow runs with local credentials and restoration waits until it succeeds

#### Scenario: Newer target arrives

- **WHEN** another valid target arrives before the pending target opens
- **THEN** only the newer target is restored and an older asynchronous load cannot override it

### Requirement: Explicit dashboard connection choice

The app SHALL compare dashboard identities after canonicalizing scheme, host, default ports, and trailing path slashes while preserving the base path. A different host, port, scheme, or base path SHALL remain a different dashboard. If no dashboard is configured or the target differs, the unlocked app SHALL show the target address and offer Connect and Cancel before contacting it. The prompt SHALL explain that changing dashboards clears the current session and local queued messages. Connect SHALL enter the existing setup and sign-in flow with the incoming address prefilled and retain that accepted target. Cancel SHALL discard the target without changing the existing connection. A development server override SHALL NOT be replaced by an incoming target.

#### Scenario: Same dashboard with a trailing slash

- **WHEN** the incoming URL differs from the configured URL only by canonical formatting
- **THEN** the app continues through the existing connection without asking to switch servers

#### Scenario: Different dashboard

- **WHEN** an incoming target identifies a different dashboard
- **THEN** the app asks before any request to that dashboard
- **AND** cancellation leaves the configured server and session unchanged

#### Scenario: Accept another dashboard

- **WHEN** the user selects Connect for a different dashboard
- **THEN** existing setup and sign-in establish the target connection before its chat opens
- **AND** no source-device token is transferred or reused

#### Scenario: Fixed development server

- **WHEN** an incoming target differs from `HERMES_SERVER_URL`
- **THEN** the app explains the mismatch and does not change the override or contact the incoming dashboard

### Requirement: Restore exact profile ownership without sending

The app SHALL open only the target's profile and saved thread on the accepted dashboard, including a thread outside the loaded session page. It SHALL load history and follow any running reply through existing chat behavior. It SHALL NOT submit a prompt, create a replacement chat, interrupt the source device, or transfer local drafts or queues. Missing profiles, missing chats, and permission failures SHALL produce a visible failure without falling back to an identically named thread on another profile. Retryable connection failures SHALL retain the target for explicit retry or normal connection recovery without an automatic retry loop.

#### Scenario: Thread ID exists on two profiles

- **WHEN** Handoff names a thread ID shared by two profiles
- **THEN** history is requested with the incoming profile and only that profile's thread opens

#### Scenario: Saved thread outside the list

- **WHEN** the target thread is older than the loaded session page
- **THEN** the app fetches its detail and history directly rather than reporting it missing from the list

#### Scenario: Reply is running

- **WHEN** the restored chat has a reply running on the dashboard
- **THEN** the receiving device follows the existing reply without submitting or interrupting a turn

#### Scenario: Target no longer exists

- **WHEN** the dashboard reports a missing profile or thread
- **THEN** the app reports that the chat could not be opened and does not create a chat or choose another profile

#### Scenario: Dashboard temporarily unreachable

- **WHEN** restoration fails because the dashboard cannot be reached
- **THEN** the target remains available for retry and no prompt is sent

### Requirement: Cancellation prevents stale navigation

An explicit sign-out, change-server action outside the accepted Handoff transition, dismissal, or deliberate navigation after reception SHALL cancel pending restoration. Late asynchronous results SHALL NOT restore cancelled targets. Ordinary token refresh, login, and connection recovery SHALL NOT discard the pending target.

#### Scenario: Navigate while a target loads

- **WHEN** the user deliberately opens another destination or chat before restoration completes
- **THEN** a delayed Handoff result does not navigate away from that selection

#### Scenario: Sign out while waiting

- **WHEN** the user explicitly signs out while continuation is pending
- **THEN** the pending target is discarded and a later sign-in does not reopen it

### Requirement: Existing Hermes backend contract

Handoff SHALL require no new backend API or Hermes version increase beyond the app's existing profile-aware chat and gateway requirements. The current compatibility baseline is the Hermes revision `7b3c7aef31da73aabab0aa7fd15fdfe7c838834e` pinned in `.github/workflows/real-backend-contract.yml`; a numeric minimum release is not established by this repository. The implementation SHALL verify restoration against that baseline or document the tested replacement before release.

The app SHALL use existing auth discovery and native sign-in routes, `GET /api/profiles/active` with an `active` profile name, `GET /api/sessions?profile=<name>` with a `sessions` list, `GET /api/sessions/<id>?profile=<name>` with a session object carrying `id` or `session_id`, and `GET /api/sessions/<id>/messages?profile=<name>` with a `messages` list. History rows SHALL retain the existing role, content, attachment, and tool-result interpretation. A session-detail 404 SHALL mean missing chat. Existing `/api/ws` gateway `session.resume` SHALL receive `session_id` and `profile` and return the runtime `session_id`, `running`, and available messages used by existing reply attachment. Handoff SHALL NOT use `prompt.submit` or `session.interrupt` to restore a chat.

#### Scenario: Existing dashboard supports restoration

- **WHEN** a dashboard provides the current profile-scoped session routes and gateway resume contract
- **THEN** Handoff restores through those existing APIs with the receiving device's credentials and no backend migration
