## Why

The catalog covers the servers Hermes has approved, but people also run their own: an internal remote server, a local script, a tool that is not in the catalog. Today those can only be added on the Hermes host or in the web dashboard. This change lets the user add one from the app, and edit the whole list as JSON, which completes managing MCP from the app.

This is the third of three changes (see `mcp-servers/proposal.md`). The screens are in the archived `mcp-servers` mockups (`openspec/changes/archive/*-mcp-servers/mockups/index.html`): Add server (remote), the review step for a command server, and the JSON editor on the phone, and the review dialog on the Mac.

## What Changes

- Turn the "Add" button of the MCP servers screen into a menu: "Browse the catalog" (from `mcp-catalog`) and "Add a custom server". The empty state's second button opens the same form.
- Add an "Add server" form with two shapes. A remote server takes a name, a URL and how it signs in (none, a bearer token, or OAuth). A command server takes a name, a command, arguments (one per line) and environment variables.
- Before a command server is saved, show a review step with the exact command, arguments and the names of the environment variables, and require an explicit "Add and run on server". Remote servers skip it.
- Add an "Edit as JSON" screen, opened from the servers screen's menu. It loads the profile's whole `mcp_servers` map, checks it on the device, warns that saving replaces everything, asks for confirmation when servers would be deleted, applies the same review step to new or changed command servers, and shows Hermes' validation problems as a list.

## Capabilities

### New Capabilities

- `mcp-custom-servers`: adding a remote or command server by hand, the review step for command servers, and the JSON editor for the whole list.

### Modified Capabilities

- `mcp-servers`: the servers screen gains an overflow menu with "Edit as JSON".
- `mcp-catalog`: the "Add" button and the empty-state button now offer the catalog next to the custom form instead of opening the catalog directly.

## Non-Goals

- Editing one server through a form after it was added. Changes go through the JSON editor.
- Editing a server's tool selection, timeouts, headers other than the bearer token, or OAuth client settings through a form. They are reachable in the JSON editor.
- Importing from other clients' config files, QR codes or deep links.
- Checking that a command exists on the server. Hermes reports problems when the server is tested.
- Running or testing a server as part of adding it. Testing stays a separate button from `mcp-servers`.

## Impact

- **Code:** `lib/src/mcp/` gains an add-server screen, a review sheet or dialog, a JSON editor screen and the calls for adding and replacing on the repository, and the servers screen gets a menu. No change to `packages/hermes_api`.
- **Backend contract:** `POST /api/mcp/servers`, `PUT /api/mcp/servers` and `GET /api/config` (for the full map). All untyped in the OpenAPI spec, so parsing is lenient and the real-backend contract test covers the shapes. Minimum Hermes 0.21.3.
- **Security and privacy:** this change lets a phone make the Hermes host run a program, so the review step is required for every command server, whichever way it arrives. Environment values and the bearer token are sent once in the request body and are never stored on the device, logged or put in telemetry, and their fields are obscured and cleared afterwards. The JSON editor shows the profile's real config, environment values included, so its text is never logged, persisted or sent to telemetry, and the screen says it holds secrets. Hermes' own check that rejects suspicious command configurations stays in force and its message is shown.
- **Telemetry:** none added. Request bodies are not recorded, and a test asserts that for both calls.
- **Platforms:** iOS, Android, macOS, Windows and Linux (shared Dart). No dependency, entitlement, manifest or Xcode project change.
