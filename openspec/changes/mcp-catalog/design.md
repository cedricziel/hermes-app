## Context

See `proposal.md` for motivation and `mcp-servers` (`openspec/specs/mcp-servers/spec.md` once archived) for the screen, repository and profile handling this builds on. What Hermes does for this change (read from `hermes_cli/web_routers/mcp.py` and `tools/mcp_dashboard_oauth.py`, Hermes 0.21.3):

- `GET /api/mcp/catalog` returns `{entries, diagnostics}`. Each entry is annotated with `installed` and `enabled` for the profile. Entries carry `transport`, `command`, `args`, `url`, `install_url`, `install_ref` and `bootstrap`, because the catalog's trust model expects the user to inspect them before installing.
- `POST /api/mcp/catalog/install` writes any declared env values to the profile's `.env` first, then either installs synchronously (`background: false`) or, for git-bootstrap entries, spawns `hermes mcp install <name>` and answers `background: true` with an `action` name. It rejects env keys the entry does not declare with 400, and unknown entries with 404.
- `GET /api/actions/{name}/status` reports `running`, `exit_code` and a tail of the log for that spawned process.
- `POST /api/mcp/servers/{name}/auth` starts a flow on the server and answers a snapshot with `flow_id`, `status`, `authorization_url` and `error`. The redirect URI is the dashboard's own callback, built from its public URL or from the request's base URL. Hermes receives the browser redirect, exchanges the code and stores the token; the app never sees the code. A flow lives 15 minutes, waits 5 minutes for the callback, allows one live flow per server (409) and eight overall (429).
- `DELETE /api/mcp/oauth/flows/{id}` cancels a flow and is idempotent. Without it, the server's "already in progress" slot stays taken until the timeout.

## Goals / Non-Goals

**Goals:**

- Reuse the `mcp-servers` repository, profile resolution and detail widget, and extend them rather than fork them.
- Keep secrets out of everything except the one install request body.

**Non-Goals:**

- No in-app OAuth machinery. The auth flow specification (`openspec/specs/auth`) is about signing in to Hermes itself; MCP OAuth is server-side.
- No catalog cache across visits. The catalog is small (about 65 entries) and its installed state must be true.

## Decisions

**Extend `HermesMcpRepository` with `loadCatalog`, `installEntry`, `actionStatus`, `startSignIn`, `flowStatus` and `cancelFlow`.** One repository per backend area keeps the profile handling in one place. Models are small immutable classes (`HermesMcpCatalogEntry`, `HermesMcpInstallResult`, `HermesMcpAction`, `HermesMcpFlow`), parsed leniently like the rest.

**Filtering and search happen on the device.** The whole catalog arrives in one answer and is small, so there is no query parameter to add and no wait per keystroke.

**One install-sheet widget, shown as a bottom sheet or as the right-hand pane.** Same idea as the shared detail widget in `mcp-servers`: the content is one widget; only the container differs by the 900 logical pixel breakpoint.

**Credentials are held only in `TextEditingController`s of the sheet, and the controllers are cleared after the request.** They are never put in a model, a provider or a route argument, so nothing can log them by accident. The request body is the only place they go, over the same authenticated `Dio`. The existing Dio telemetry setup records no bodies (`DioOTelInterceptor.privacy`), and a test asserts that the install call's span and log records contain neither the key nor the value.

**Background installs are followed by polling `actions/{name}/status` every two seconds, in the sheet's state, and stop when the sheet closes.** Alternative: keep a global installer that survives the sheet. Rejected: the build keeps running on the server either way, the catalog reload shows the truth, and a global object would need a place to live and a way to report back with no screen open. On failure the tail of the log (last 20 lines) is shown as-is; it is text Hermes wrote for the user.

**Sign-in is a screen of its own with a `WidgetsBindingObserver` for resume.** It opens the URL with `launchUrl(..., externalApplication)`, as the Telegram pairing screen does, polls the flow every two seconds, and also polls once when the app resumes from the browser, so a quick approval feels instant. The screen owns the flow id and cancels the flow in `dispose` if it is not settled, so backing out of the screen cannot leave the server's slot taken. A flow that answers 404 is treated as expired.

**After `approved`, the server is tested and the result is passed back to the detail.** The flow status also carries the tool list, but the test route is the one the detail already understands, so reuse it instead of a second parser.

**"Add" is a single button that opens the catalog in this change.** `mcp-custom-servers` turns it into a menu with a second entry. The empty state's two buttons follow the same rule.

**No suggestion hints, no default-enabled tool preview.** The catalog also exposes `default_enabled` and `suggest`. Neither is needed to install safely, and both would need copy the user never asked for.

## Risks / Trade-offs

- [The redirect URI is built from the address Hermes sees for the request, which behind some proxies is not the address the user's browser can reach] → Hermes supports a configured public URL and a per-server `redirect_uri`; the waiting screen shows the URL to copy and says the sign-in finishes on the server. If the callback cannot be reached, the flow ends in `error` after the timeout and the user can try again. Not solvable in the app.
- [A build can run a long time or fail with unhelpful log lines] → The sheet keeps working while it runs, polling stops when it closes, and the log tail is shown on failure.
- [Installing runs code on the server] → The sheet always shows the command, arguments, repository, reference and build steps first, and only enables Install once required credentials are filled. This is the same disclosure the catalog's own trust model asks for.
- [A user pastes a credential into the wrong field] → Fields are labelled with the name and prompt Hermes declares. Values are never echoed back, so a mistake is fixed by reinstalling or by editing on the server; no route exists to read them.
- [Untyped responses drift] → Lenient parsing and the real-backend contract test.

## Platforms and invariants

- **Platforms:** iOS, Android, macOS, Windows, Linux (shared Dart). watchOS is not involved. `url_launcher` is already a dependency; on Android 11 and later, opening an `https` URL through it needs no `<queries>` entry beyond what the Telegram link already uses, so no manifest change is expected. Verify on the existing sign-in and Telegram paths before adding one.
- **API layering:** the calls are in the generated client (`installMcpCatalogEntryApiMcpCatalogInstallPost`, `listMcpCatalogApiMcpCatalogGet`, `authMcpServerApiMcpServersNameAuthPost`, `mcpOauthFlowStatusApiMcpOauthFlowsFlowIdGet`, `cancelMcpOauthFlowApiMcpOauthFlowsFlowIdDelete`, `getActionStatusApiActionsNameStatusGet`), so nothing is hand-rolled.
- **Auth:** a 401 on any of these calls is handled by the existing pipeline. Concurrent 401s must not sign the user out, so the sign-in polling uses the same `Dio` and adds no retry loop of its own.
- **Telemetry:** nothing added; secrets and the authorization URL never appear in spans or logs.

## Testing

`FakeHermesServer` with per-route answers: catalog parsing, skipped entries, diagnostics note, search and each filter, the installed tap, the sheet's disclosure of the run block (remote, command, build), the disabled Install with a missing required credential, only declared credentials sent, optional ones omitted, fields cleared after success and failure, `enable` from the switch, 400, 404 and other failures, background install through success and failure with a log tail, closing the sheet while building, sign-in success, error, expired flow, cancel, dispose cancelling, the browser failing to open, and each refusal (409, 429, 400, 404). A privacy test proves the install call's telemetry has no credential. The contract test gains a catalog-shape check and, against the pinned Hermes, a check that starting sign-in on a remote OAuth server returns a flow with an `authorization_url` (this needs no model call and no real provider).
