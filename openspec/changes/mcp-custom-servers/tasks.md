## 1. Prepare

- [x] 1.1 Rebase onto `origin/main` (and onto the merged `mcp-catalog` once it lands) before writing code, then re-run `openspec validate mcp-custom-servers --strict`
- [x] 1.2 Add delta specs for `mcp-servers` (overflow menu with "Edit as JSON") and `mcp-catalog` (the Add button and the empty-state button now go through the menu): MODIFIED or ADDED as the current main specs require, copying the full current requirement text before editing it
- [x] 1.3 Note the generated client method names for the three calls in `design.md` and check the request models (`MCPServerCreate`, `MCPServersReplace`) send no non-empty `args` or `env` for a remote server and no `auth` or token for a command server

## 2. Repository

- [x] 2.1 Add `addServer` (`POST /api/mcp/servers`), `replaceServers` (`PUT /api/mcp/servers`) and `loadRawServers` (`GET /api/config`, returning the `mcp_servers` map, empty when missing) to `HermesMcpRepository`, each with the profile parameter
- [x] 2.2 Map refusals to typed results: 409 duplicate name, 400 with Hermes' reason (for replace, split at "; "), other failures
- [x] 2.3 Extend the repository tests against `FakeHermesServer`, including the request bodies for each server shape and a privacy test that the spans and log records of both calls contain no token, env value or body

## 3. Add form and review

- [x] 3.1 Add the `McpAddServerScreen` with the Remote and Command switch, the remote fields and sign-in choice, the obscured bearer token, the command, the one-per-line arguments and the environment rows, with the client checks and disabled Add from the spec
- [x] 3.2 Add `McpCommandReview` (bottom sheet below 900 logical pixels, dialog above), taking a list of servers and showing command, arguments and env names only
- [x] 3.3 Wire adding: review first for command servers, progress on Add, close and open or select the new server on success, 409 on the name field, 400 reason, "Could not add {name}", and clear the secret fields in a `finally`
- [x] 3.4 Turn the Add button into a menu and make the empty state's second button open the form
- [x] 3.5 Write `test/mcp_add_server_test.dart` for the add scenarios at widths either side of 900

## 4. JSON editor

- [ ] 4.1 Add `McpJsonEditorScreen`: load the full map, show the profile and the secrets note, the replace-everything warning, monospace editing, progress and Retry on failure
- [ ] 4.2 Add the checks: JSON errors with a line number, the object-of-objects rule, Save disabled while unchanged, the deletion confirmation naming removed servers, and the review step for new or changed command servers only
- [ ] 4.3 Save with `replaceServers`: progress, close and reload the list on success, the problem list on 400 with the text unchanged, "Could not save" otherwise, and the discard prompt when leaving with changes
- [ ] 4.4 Add "Edit as JSON" to the servers screen's overflow menu
- [ ] 4.5 Write `test/mcp_json_editor_test.dart` for the editor scenarios

## 5. Contract and finish

- [ ] 5.1 Extend `test/real_backend_contract_test.dart`: `/api/config` carries a `mcp_servers` map with fields the summary route omits, and the round trip of adding a remote server, saving it unchanged from the editor's data and seeing the list unchanged; run it against `scripts/dev-backend.sh`
- [ ] 5.2 Run `dart format .`, `flutter analyze` and `flutter test`; check the form, the review step and the editor against the mockups in the running app with the `verify-in-app` skill on a throwaway backend, adding only a remote server and a harmless command such as `true` that is never started
- [ ] 5.3 Update the `CLAUDE.md` architecture note for `lib/src/mcp/` and add anything learned to the `verify-in-app` skill
- [ ] 5.4 Archive the change (`openspec archive mcp-custom-servers`) as the last commit so the main specs are updated with the code
