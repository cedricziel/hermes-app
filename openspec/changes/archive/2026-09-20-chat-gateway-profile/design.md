## Context

The dashboard serves several Hermes profiles from one process. Each profile has its own `state.db`, so a stored session id is unique only within a profile. The REST layer scopes by a `profile` query parameter, and the chat already passes it. The gateway socket (`/api/ws`) had no profile in the app: `session.create` sent no params and `session.resume` only `session_id`.

## Evidence

Read from the Hermes Agent source (NousResearch/hermes-agent, `main` at 3dae1f7, and the ref the contract workflow pins, 2237be3). No `hermes` binary was available locally, so the behaviour was not probed against a live backend; the contract case added here does that when run against one.

- `tui_gateway/contracts/sessions.py`: `SessionCreateParams(ProfileParams)`. `ProfileParams` has one field, `profile: str | None`, documented as "any method the desktop may route to a named profile". `session.resume` reads `params.get("profile")` in the same way.
- `tui_gateway/methods_session.py`, `session.create`: `_profile_home(profile := (params.get("profile") or "").strip() or None)`, with the comment "`profile` (app-global remote mode): stored so the build and every turn re-bind HERMES_HOME". The runtime session records `profile_home`, so `prompt.submit` on that runtime id runs under the profile without another param. The same lines exist at the pinned ref.
- `session.resume` (`_Resume`): reads `params.get("profile")` and resolves it to a profile home: "resume from another local profile's state.db". Without it the lookup goes to the launch profile's store.
- `_profile_home` in `tui_gateway/server.py`: a blank or missing name means the launch profile; the launch profile's own name resolves to the same home and needs no override; `default` is the default profile; an unknown name raises `ProfileUnavailableError` rather than silently falling back. Current `main` turns that into JSON-RPC error `4064` (`rpc_dispatch.py`); the pinned ref has no such translation.
- The socket has no per-profile connection or query parameter: the profile is a per-call param, as the desktop does with `requestGatewayForProfile`.

## Decision

Pass `profile` as a param of `session.create` and `session.resume`. Nothing else on the socket needs it, because the runtime session id keeps the binding.

- `ChatTransport.send({threadId, profile, text})`. The interface stays wire-neutral; only the gateway transport knows the param name.
- `HermesGatewayTransport` builds one `{'profile': profile}` map, omitted when the profile is null, and adds it to both calls. The omitted case keeps today's wire format exactly, so an older or single-profile backend is unaffected.
- `ChatScreen` passes `_profile` as captured when the send starts, the same value it already uses for notifications. `_profile` is set together with the thread list, so it is the profile the threads on screen were listed under.
- `WatchRequestHandler` already resolves the active profile before a send, to bind and check thread ids. It passes that value on, so a watch send goes to the profile the watch lists.

The profile value is the name the dashboard returns from `GET /api/profiles/active`, the same string used for the REST `profile` query parameter.

## Alternatives considered

- Send `profile` on every RPC: not needed, the runtime session is already bound, and it would add a way for params to disagree with the binding.
- A `profile` query parameter on the socket URL: not supported by the gateway; the connection is shared across profiles.
- Reconnect per profile: needless, one socket can carry sessions of several profiles.

## Risks

- A profile deleted since the list was loaded: the gateway rejects the call. On current Hermes that is error `4064`; on the pinned ref it may surface as a dropped socket. Either way the send fails and the reply is marked as an error, which is the existing failure path. The contract case does not assert the rejection, because it differs by version.

## Platforms and invariants

All platforms (Dart only; no manifest, entitlement or Xcode change). Touches no auth, API-layering or telemetry invariant: no new REST call, no token handling, no new span attribute.
