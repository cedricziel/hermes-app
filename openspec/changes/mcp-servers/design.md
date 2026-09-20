## Context

See `proposal.md` for the motivation and the three-change plan. Screens for all three changes are in `mockups/index.html`.

Hermes keeps MCP servers under `mcp_servers` in each profile's config. The dashboard exposes them through `hermes_cli/web_routers/mcp.py`. What matters for this change:

- Every route takes an optional `profile` query parameter. Without it, Hermes uses the profile the dashboard process runs as.
- `GET /api/mcp/servers` returns `{"servers": [...]}` sorted by name. Each entry has `name`, `transport` (`http`, `stdio` or `unknown`), `url`, `command`, `args`, `env` (values redacted), `auth` (`oauth`, `header`, or null), `enabled` and `tools` (a list of enabled tool names, or null for all). It does not say whether a server works.
- `POST …/test` connects, lists tools and disconnects. It can take seconds (a command server may start `npx`). It answers HTTP 200 with `ok: false` and an `error` for failures, and 404 for an unknown name. For an OAuth server with no token on disk it answers `ok: false` with "OAuth authentication required — no token found."
- `PUT …/enabled` and a removal touch config only. Neither restarts anything, so they take effect on the next session.
- The generated client returns untyped JSON for all four calls, so the app parses rows itself, as it does for bots and profiles.

The chat sidebar already links to Profiles and Bots through callbacks on `ChatScreen`, each pushing a `MaterialPageRoute` (`chat_screen.dart`, `_openProfiles`, `_openBots`). The chat resolves the active profile with `_activeProfile()`: no repository or a 404 means "none", any other failure throws so nothing is listed or sent unscoped.

## Goals / Non-Goals

**Goals:**

- Follow the Bots and Profiles pattern (a repository over `authController.api!.raw`, a screen that takes the repository) so the code reads like its neighbours.
- Lay the ground the next two changes build on: the repository and screen structure must take catalog and add-server screens without rework.
- Never act on the wrong profile.

**Non-Goals:**

- No caching of server lists across visits, and no background polling. The screen loads when it opens and after each change.
- No new dependency.

## Decisions

**A `HermesMcpRepository` in `lib/src/mcp/`, next to a `McpServersScreen`.** The repository owns the four calls and the lenient parsing and returns small immutable models (`HermesMcpServer`, `HermesMcpTestResult`, `HermesMcpTool`). The screen takes the repository as a constructor argument, so tests inject one built on the real client and `FakeHermesServer`. Alternative: a `ChangeNotifier` controller in `provider`. Rejected for now: Bots and Profiles are plain stateful screens, and nothing here is shared across screens. If change 2 needs the installed set on the catalog screen, the state can move up then.

**The active profile is resolved once per screen visit, by the screen, with the same rule as the chat.** The screen calls the profiles repository's `loadActive()`, treats 404 as "no profile", and treats any other failure as "cannot load" with Retry. It then passes the profile name to every repository call. The repository never guesses a profile. Alternative: let the server pick its default when the profile is missing. Rejected: the chat fixed this exact trap in #172, and a switch flipped on the wrong profile is worse than a failed load. The name is also shown in the header so the user can see it. It is read again on Retry and on each visit, so switching profiles and coming back shows the new one.

**Toggle waits for the server's answer.** The switch does not flip until `PUT …/enabled` answers OK; while it runs, that row's switch is disabled. Alternative: optimistic update with rollback. Rejected: the change only takes effect on the next chat, so there is no lag to hide, and a wrong optimistic state on a config change invites a second tap. A 404 reloads the list, since another client removed the server.

**Test results live in the screen's state, keyed by server name, and are dropped when the screen closes.** They show the tool count on the row and fill the detail. They are not persisted: a result says "worked just now", and a stale one on disk would mislead. The list itself never claims health.

**"Sign in needed" is recognised by the error text prefix, and only for `auth == "oauth"`.** Hermes has no structured code for this case, only the message. The check is a prefix match on "OAuth authentication required" so a change to the tail of the message does not break it, and it falls back to the plain failure banner if the wording ever changes. The real-backend contract test gets a case that asserts the wording, so a Hermes release that changes it fails a non-required check instead of silently degrading. Alternative: treat every failed test of an OAuth server as "sign in needed". Rejected: it would send the user to sign in for a server that is simply down.

**Command servers show their command line in the list; environment values never appear.** The server already redacts them, and the app does not render `env` at all in this change. That keeps the screen safe to screenshot and leaves the decision about showing key names to `mcp-custom-servers`, which has to (for the review step).

**Layout switches at 900 logical pixels**, the same breakpoint the shell uses for its rail. Wide: list and detail side by side inside one screen. Narrow: the detail is a pushed route. Both share one detail widget so the wide and narrow layouts cannot drift apart.

**Notes for the next changes (not built here).**

- `mcp-catalog`: OAuth completes on the server, because the callback URL points at the dashboard. The app only opens `authorization_url` in the system browser and polls `GET /api/mcp/oauth/flows/{id}`; it needs no loopback listener and no PKCE of its own. It must call `DELETE` on the flow when the user cancels, or the server refuses a retry with 409 until its five-minute timeout. Catalog installs of entries with a git step return `background: true` and an action name, so the app has to keep checking that the server appears in the list.
- `mcp-custom-servers`: the list route is a lossy summary (no headers, oauth settings or timeouts, env redacted), so the JSON editor reads the full map from `GET /api/config` and saves with `PUT /api/mcp/servers`, which replaces the whole map.

## Risks / Trade-offs

- [Error-text match breaks when Hermes rewords the message] → Prefix match plus a contract-test assertion; worst case is the plain "Could not connect" banner with Hermes' own text, which is still correct.
- [A test can take many seconds for a command server that has to download packages] → The button shows progress, the screen stays usable, and leaving the screen ignores the late answer. No timeout is added beyond the client's own.
- [Removing a server is not undoable, and its OAuth token and env values stay in Hermes' files] → Confirmation names the server and says it is deleted, not switched off. The app does not try to clean up server-side secrets, since no route exists for that.
- [Untyped responses drift between Hermes releases] → Lenient parsing, skipped rows, and the contract test against a pinned Hermes.
- [A profile with many servers makes the list long] → A plain scrolling list is enough for the dozens a person configures. Search is not added.

## Platforms and invariants

- **Platforms:** iOS, Android, macOS, Windows, Linux (shared Dart). watchOS is not involved. No entitlement, manifest or Xcode project change, and no change to `packages/hermes_api`.
- **API layering:** all calls go through `authController.api!.raw`. No hand-rolled Dio call, because the four routes are in the generated client.
- **Auth:** nothing new. A 401 is handled by the existing Dio pipeline, so a failed MCP request cannot sign the user out by itself.
- **Telemetry:** nothing added. The URLs and command lines shown on screen are not sent in any span or event.

## Testing

Tests use `FakeHermesServer` with per-route responses, as the other repositories do: list parsing (including skipped rows, missing `enabled`, redacted env not rendered), profile parameter on each call, the 404-profile and failed-profile paths, toggle success, failure and 404, test success, failure, sign-in-needed and request failure, removal with confirm, cancel and failure, and both layouts at widths either side of 900. `test/real_backend_contract_test.dart` gets a list-shape check and, for the test route, a check that an OAuth server without a token gives the expected wording.
