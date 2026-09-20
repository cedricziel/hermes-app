## Why

Hermes can give the agent extra tools through MCP servers, but the app has no way to see or change them. Users have to open the web dashboard or edit config on the host to turn a server on or off, check whether it works, or remove it. The generated client already wraps every MCP route, so the app can offer this with no new backend work.

This is the first of three changes that together cover managing MCP servers from the app. The mockups for all three are in `mockups/index.html` (open it through a local web server; phone and Mac layouts).

1. **`mcp-servers`** (this change): see the servers, turn them on and off, test them and see their tools, remove them.
2. **`mcp-catalog`** (next): browse the approved catalog, install with credentials, sign in to servers that use OAuth.
3. **`mcp-custom-servers`** (after that): add a server by hand, with a review step for command servers, and edit the whole list as JSON.

## What Changes

- Add an "MCP servers" entry to the chat sidebar, under Profiles and Bots. It opens a screen for the active profile, with the profile named in the header.
- List the profile's MCP servers with their transport (remote or command), how they sign in, and whether they are on.
- Let the user turn a server on or off. The change applies from the next chat, and the screen says so.
- Let the user open a server, test it, and see the tools it offers with their descriptions and schema sizes, plus the prompt and resource counts.
- Show a failed test in Hermes' own words. When a test says OAuth is needed, show "Sign in needed" (the sign-in flow itself arrives in `mcp-catalog`).
- Let the user remove a server after a confirmation.
- Empty state with no servers, a Retry when loading fails, and a wide-window layout with the list and the detail side by side.

## Capabilities

### New Capabilities

- `mcp-servers`: listing, switching on and off, testing and removing the MCP servers of the active profile, and the sidebar entry to reach them.

### Modified Capabilities

None. The sidebar entry is specified inside `mcp-servers` and does not change a requirement of `profiles-and-bots`.

## Non-Goals

- Installing from the catalog, entering credentials and OAuth sign-in (`mcp-catalog`).
- Adding a server by hand and the JSON editor (`mcp-custom-servers`).
- Choosing a profile other than the active one on this screen. To manage another profile, switch to it in Profiles first.
- Choosing which tools of a server are enabled. Hermes stores that selection but the routes to change it are only the whole-map replace, which belongs to `mcp-custom-servers`.
- Changing how a chat that is already running uses tools.
- Reporting server health in the list. Hermes only reports it when a test runs.

## Impact

- **Code:** a new `lib/src/mcp/` folder (repository over `authController.api!.raw`, list and detail screens), a new row and callback in the chat sidebar, and tests against `FakeHermesServer`. No change to `packages/hermes_api`.
- **Backend contract:** `GET /api/mcp/servers`, `PUT /api/mcp/servers/{name}/enabled`, `POST /api/mcp/servers/{name}/test`, `DELETE /api/mcp/servers/{name}`. Every response is untyped in the OpenAPI spec, so the repository parses rows leniently and the real-backend contract test gains a check for these shapes. Minimum Hermes version: 0.21.3, the version the bundled spec was taken from.
- **Security and privacy:** the server redacts environment values in the list, and the app never asks for or stores them in this change. The list can show a command line and a URL, which the app shows only on screen, never in telemetry. No new tokens and nothing new in secure storage.
- **Telemetry:** the four calls above show up as HTTP client spans like every other request. No new spans or log events.
- **Platforms:** iOS, Android, macOS, Windows and Linux, all Dart. watchOS is not affected. No entitlement, manifest or Xcode project change.
