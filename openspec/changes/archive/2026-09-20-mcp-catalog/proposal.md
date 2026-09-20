## Why

`mcp-servers` lets the user manage MCP servers that already exist on the Hermes host, but a new phone-only user has none, and no way to add one. Hermes ships an approved catalog of about 65 servers and can sign in to OAuth servers on the user's behalf. This change brings both to the app, so a server can be found, installed and signed in to without opening the dashboard.

This is the second of three changes (see `mcp-servers/proposal.md`). The screens are in the archived `mcp-servers` mockups (`openspec/changes/archive/*-mcp-servers/mockups/index.html`): Catalog, Install sheet and OAuth in progress on the phone, and the two-pane catalog on the Mac.

## What Changes

- Add a Catalog screen, opened from an "Add" button on the MCP servers screen and from its empty state. It lists the approved servers with a description, transport and sign-in kind, search, and filters for Remote, Command and OAuth.
- Show which entries are already installed, and open an installed entry's server instead of installing it again.
- Add an install sheet (a right-hand pane on wide layouts) that shows exactly what Hermes will run: the transport, URL or command and arguments, any build steps, and the entry's source. It asks only for the credentials the entry declares, as write-only fields, and offers "Turn on after installing".
- Install through Hermes, and for entries that need a build on the server, show progress until it finishes and report failure with the tail of the build log.
- Add sign-in for OAuth servers: a "Sign in" button on the server's detail (including the "Sign in needed" banner from `mcp-servers`) that opens the system browser, waits for the user to approve, can be cancelled, and runs a test when it succeeds.

## Capabilities

### New Capabilities

- `mcp-catalog`: browsing the approved catalog, installing an entry with its credentials, and signing in to OAuth servers.

### Modified Capabilities

- `mcp-servers`: the "Sign in needed" requirement stops saying that signing in is out of scope and offers the sign-in button; the empty state and the servers screen gain the entry to the catalog.

## Non-Goals

- Adding a server that is not in the catalog, and editing the list as JSON (`mcp-custom-servers`).
- Choosing which of a server's tools are enabled. Hermes installs the entry's default selection.
- Updating or reinstalling an installed entry.
- Running OAuth inside the app (a loopback listener, PKCE). Hermes receives the redirect on its own address and the app only opens the browser and watches the flow.
- Showing the catalog's "suggest" hints (keywords and hosts used by another client's composer).

## Impact

- **Code:** `lib/src/mcp/` gains catalog models and calls on the repository, a catalog screen, an install sheet or pane, and a sign-in screen. The MCP servers screen gets an Add button. No change to `packages/hermes_api`.
- **Backend contract:** `GET /api/mcp/catalog`, `POST /api/mcp/catalog/install`, `GET /api/actions/{name}/status`, `POST /api/mcp/servers/{name}/auth`, `GET` and `DELETE /api/mcp/oauth/flows/{id}`. All are untyped in the OpenAPI spec, so parsing is lenient and the real-backend contract test covers the shapes. Minimum Hermes 0.21.3.
- **Security and privacy:** credentials the user types are sent once in the install request body and are never stored by the app, logged, or added to telemetry. Fields are obscured and cleared after the request. Install runs a build or a program on the user's Hermes host, so the sheet always shows what it will run before the Install button is enabled. OAuth tokens stay on the Hermes server; the app holds only the flow id while a sign-in is running. The authorization URL is opened in the system browser and never logged.
- **Telemetry:** the calls appear as HTTP client spans like every other request. Request bodies must not be recorded, which the existing privacy setup already ensures and a new test asserts for the install call. No new spans or log events.
- **Platforms:** iOS, Android, macOS, Windows and Linux. `url_launcher` is already a dependency and already used for the Telegram link and sign-in. No entitlement, manifest or Xcode project change.
