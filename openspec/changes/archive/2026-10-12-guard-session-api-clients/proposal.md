## Why

Retaining drafts across session expiry requires keeping old controllers alive. Their API clients currently read the controller's latest credentials, so a stale controller can attach credentials belonging to a different server or account. Requests and token mutations also need to stop crossing an invalidated session boundary.

## What Changes

- Suspend protected HTTP requests synchronously before token cleanup, without changing the root-screen state early.
- Bind API clients to a server and logical owner lifetime; invalidate in-flight requests on expiry and retire clients on explicit departure or verified owner mismatch.
- Expose verified owner and expired-owner proof for the later navigator-preservation layer.
- Keep bootstrap refresh and candidate-token verification distinct from suspended application requests.
- Serialize credential writes/clears so old cleanup cannot delete or restore a newer session.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `auth`: protected client isolation, verified owner proof, and credential mutation ordering.

## Impact

AuthController, a small immutable owner value, and focused authentication regressions. No new backend routes, dependencies, entitlements, or native project changes. Navigator covering/draft restoration, sockets/dictation suspension, external queues, and auxiliary-window restoration are subsequent layers; this PR claims protected HTTP isolation only.

Security and privacy impact: prevents stale clients from using another account/server's credentials. Owner proof uses normalized server and verified user/organization/provider identifiers in memory only. Tokens remain in secure storage. Observability: record a fixed-reason auth.client.retired event at lifetime retirement; never log identities, addresses, credentials, or request content.
