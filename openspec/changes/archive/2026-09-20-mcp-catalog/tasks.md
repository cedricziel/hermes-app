## 1. Prepare

- [x] 1.1 Rebase onto `origin/main` (and onto the merged `mcp-servers` once it lands) before writing code, then re-run `openspec validate mcp-catalog --strict`
- [x] 1.2 Add the delta `specs/mcp-servers/spec.md` with a MODIFIED "Sign in needed" requirement (the banner now offers the Sign in button and the "Signing in itself is not part of this capability" sentence goes) and an ADDED requirement for the "Add" button and the empty-state button opening the catalog; copy the full current requirement text from `openspec/specs/mcp-servers/spec.md` before editing it
- [x] 1.3 Note the generated client method names for the six calls in `design.md` and confirm their request models (`MCPCatalogInstall`)

## 2. Repository

- [x] 2.1 Add `HermesMcpCatalogEntry`, `HermesMcpInstallResult`, `HermesMcpAction` and `HermesMcpFlow` models to `lib/src/mcp/`
- [x] 2.2 Implement `loadCatalog` (entries and diagnostics, skipping entries without a name), `installEntry` (only declared credentials, empty optional ones omitted, `enable`, profile), `actionStatus`, `startSignIn`, `flowStatus` and `cancelFlow`, each with lenient parsing and the profile parameter where the route takes one
- [x] 2.3 Map refusals to typed results the screens can show: 400 reason, 404, 409, 429 and other failures for install and sign-in
- [x] 2.4 Extend the repository test file against `FakeHermesServer`, including a privacy test that the install call's span and log records contain neither the credential name nor value

## 3. Catalog screen

- [x] 3.1 Add `McpCatalogScreen` with the profile header, loading, failed and diagnostics states, the rows and chips, search with the count, the four filters, and "No servers match"
- [x] 3.2 Add the tap behaviour: uninstalled entries open the install sheet or right-hand pane at the 900 logical pixel breakpoint, installed ones open that server's detail
- [x] 3.3 Add the Add button to the MCP servers screen and the empty state's button, both opening the catalog for the same profile
- [x] 3.4 Write `test/mcp_catalog_screen_test.dart` for the catalog, search, filter and tap scenarios at widths either side of 900

## 4. Install

- [x] 4.1 Add the install sheet content: the "What Hermes will run" block for remote, command and build entries, the obscured credential fields, the on-after-install switch, and the Install button that stays disabled until required credentials are filled
- [x] 4.2 Run the install: progress, success ("Installed {name}" with a way to open the server), Hermes' own reason on 400, reload on 404, "Could not install {name}" otherwise, and clear the fields after every finished request
- [x] 4.3 Follow background installs: poll the action status every two seconds, show "Building on your server…", show the last 20 log lines on failure, stop polling when the sheet closes
- [x] 4.4 Write `test/mcp_install_test.dart` for the install scenarios above, including only-declared credentials, cleared fields and the build success, failure and close-while-building paths

## 5. Sign in

- [x] 5.1 Add the sign-in screen: start the flow, open the URL with `launchUrl(externalApplication)`, poll every two seconds and once on app resume, handle `approved`, `error`, 404 expiry and an unknown status, show the URL to copy when the browser cannot open
- [x] 5.2 Cancel the flow with `DELETE` on Cancel and on every other way out of the screen while the flow is unsettled
- [x] 5.3 Add the Sign in button to the OAuth server's detail and to the "Sign in needed" banner, run a test after `approved`, and show the refusal messages for 409, 429, 400, 404 and other failures
- [x] 5.4 Write `test/mcp_sign_in_test.dart` for the sign-in scenarios, using an injectable browser launcher as `native_login_flow.dart` does

## 6. Contract and finish

- [x] 6.1 Extend `test/real_backend_contract_test.dart`: catalog shape, and starting sign-in on a remote OAuth server returns a flow with an `authorization_url` (cancel it afterwards); run it once against `scripts/dev-backend.sh`
- [x] 6.2 Run `dart format .`, `flutter analyze` and `flutter test`; check the catalog, install sheet and waiting screens against the mockups in the running app with the `verify-in-app` skill on a throwaway backend, installing only an entry that needs no credential and no build
- [x] 6.3 Update the `CLAUDE.md` architecture note for `lib/src/mcp/` and add anything learned to the `verify-in-app` skill
- [x] 6.4 Archive the change (`openspec archive mcp-catalog`) as the last commit, so `openspec/specs/mcp-catalog/spec.md` and the `mcp-servers` update land with the code
