## 1. Prepare

- [x] 1.1 Rebase the branch onto `origin/main` before writing any code (`git fetch origin main && git rebase origin/main`), and re-check that `openspec validate mcp-servers --strict` still passes
- [x] 1.2 Confirm the four calls exist on the generated client's `DefaultApi` (list, set enabled, test, remove) and note their names; no change to `packages/hermes_api`

## 2. Repository

- [x] 2.1 Add `lib/src/mcp/hermes_mcp_repository.dart` with the models `HermesMcpServer`, `HermesMcpTool` and `HermesMcpTestResult`
- [x] 2.2 Implement `loadServers` (`GET /api/mcp/servers`) with lenient parsing: skip rows without a non-empty string name, treat a missing `enabled` as on, never keep `env` values, and throw when the body is not an object with a `servers` array
- [x] 2.3 Implement `setEnabled`, `testServer` and `removeServer`, each passing the `profile` query parameter when a profile is known; `testServer` skips tools without a name and recognises the "OAuth authentication required" prefix for OAuth servers
- [x] 2.4 Write `test/hermes_mcp_repository_test.dart` against `FakeHermesServer` (list parsing, skipped rows, missing `enabled`, profile parameter on each call, malformed test answer, sign-in-needed prefix, 404 on each call)

## 3. Screens

- [x] 3.1 Add `McpServersScreen`: resolves the active profile (404 means none, any other failure shows "Could not load MCP servers" with Retry), shows the profile in the header, the progress, error and empty states, and the "changes apply from the next chat" note
- [x] 3.2 Add the server row (name, address, transport, auth, "Off" and "Sign in needed" chips, tool count after a test) and the switch that waits for the server's answer, is disabled while its request runs, and reloads the list on 404
- [x] 3.3 Add the shared detail widget: name, transport, address, sign-in, switch, "Test connection" with progress, the Connected banner with counts and tool list (name, description, optional schema size), the "Could not connect" and "Sign in needed" banners, and "Could not test {name}" with Retry
- [x] 3.4 Add removal with a confirmation naming the server, treating OK and 404 as gone and showing "Could not remove {name}" on other failures
- [x] 3.5 Switch between one page and list-plus-detail at 900 logical pixels, select the first server on wide layouts, and move the selection when the selected server disappears
- [x] 3.6 Write `test/mcp_servers_screen_test.dart` covering the spec's scenarios: profile named, 404 profile, failed profile lookup, list states, toggle success, failure and 404, test success, failure, request failure and sign-in-needed, removal confirm, cancel and failure, and both layouts either side of 900

## 4. Sidebar entry

- [x] 4.1 Add an `MCP servers` row under Bots in the chat sidebar, with an `onOpenMcp` callback that is null without a repository, and build the repository in `ChatScreen` the same way as the bots repository
- [x] 4.2 Add the open callback that closes the drawer on narrow layouts and pushes the screen, and extend the sidebar tests for the row being shown and hidden

## 5. Contract and docs

- [ ] 5.1 Add a list-shape check and a test-route check (an OAuth server without a token gives the "OAuth authentication required" wording) to `test/real_backend_contract_test.dart`
- [ ] 5.2 Run `dart format .`, `flutter analyze` and `flutter test`, and check the screens against `mockups/index.html` in the running app with the `verify-in-app` skill, on a throwaway dev backend
- [ ] 5.3 Note in `CLAUDE.md` that MCP servers live in `lib/src/mcp/`, and add anything learned while verifying to the `verify-in-app` skill
