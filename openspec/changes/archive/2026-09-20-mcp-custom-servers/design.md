## Context

See `proposal.md` for motivation, and `mcp-servers` and `mcp-catalog` (`openspec/specs/`) for the screens, repository and profile handling this builds on. What Hermes does (read from `hermes_cli/web_routers/mcp.py`, `web_server_mcp.py`, `mcp_config.py`, `mcp_security.py`, 0.21.3):

- `POST /api/mcp/servers` normalises the body: exactly one of `url` and `command`; `auth` is `none`, `header` or `oauth`; a remote server takes no `args` or `env`; a command server takes no auth and no token; a token requires `auth: header`. For `header`, Hermes writes the token to the profile's `.env` under `MCP_<NAME>_API_KEY` and stores only a `${...}` placeholder in the config. It answers 409 for a name that exists and 400 with a reason for everything else, including a command that `validate_mcp_server_entry` rejects (a known indicator of compromise, or a shell interpreter with network egress or persistence in its inline script).
- `PUT /api/mcp/servers` replaces the whole `mcp_servers` map, validates every entry first, and rejects the whole save on any issue with the problems joined by "; ". An empty map removes the key.
- `GET /api/mcp/servers` is a lossy summary: no `headers`, `oauth`, timeouts or other keys, and `env` values are masked. It cannot be the source for an editor that replaces the whole map, since saving would delete every field it left out. `GET /api/config` returns the full stored map with env values as stored, and with `${VAR}` references expanded: a bearer token saved through `POST` shows in plain text in its `Authorization` header. Saving that value back unchanged keeps the reference in `config.yaml` (Hermes compares it with the expanded stored value), so a round trip does not write the token into the file; a value the user changes is written as typed.

## Goals / Non-Goals

**Goals:**

- Make it hard to run something on the host by accident: every command server passes the same review step, from either entry point.
- Make the JSON editor lossless: what the user loaded is what they save, apart from their edits.

**Non-Goals:**

- No structured editing of one existing server; the JSON editor covers that.
- No local check that a command exists or that a URL answers.

## Decisions

**The JSON editor reads `GET /api/config`, not the servers route.** Reading the lossy summary and saving it with a whole-map replace would silently delete headers, OAuth client settings, timeouts and tool selections. `GET /api/config` is the same source the web dashboard's editor uses. Alternative: build the map from the summary plus a per-server fetch. Rejected: no per-server route exists. The trade-off is that the editor shows env values as stored and bearer tokens expanded. That is the user's own server, over an authenticated connection, and the screen says the text holds secrets; the text lives only in the screen's state, is never logged or persisted, and is dropped on leaving. Masking would break the round trip.

**One `McpCommandReview` widget, shown as a bottom sheet or a centred dialog by width, fed with a list of servers to review.** The form passes one server, the JSON editor passes every new or changed command server. The widget shows command, arguments (one line each) and environment names, never values. Alternative: a separate confirmation per entry point. Rejected: two implementations of a security prompt drift apart.

**The JSON editor decides "new or changed" by comparing the parsed map with the map it loaded.** A command server is reviewed when its name is new, or its `command`, `args` or `env` (keys or values) differ, because a changed value such as `NODE_OPTIONS` can change what runs. The review still shows env names only. The loaded and saved maps are both held only in the screen's state. Alternative: review on every save that contains any command server. Rejected: it trains users to dismiss it.

**Arguments are entered one per line.** Splitting a single field with shell-like quoting would need a parser, and a phone keyboard makes quotes awkward. One line per argument needs none and keeps spaces inside an argument intact. Alternative: a row per argument. Rejected: too much chrome for `-y`, a package name and a path.

**Client checks are only the ones that stop an unusable request:** a non-empty trimmed name, an `http` or `https` URL, a non-empty command, valid and unique env names, a token when one is required. Everything else (suspicious commands, bad names for the server's own rules) is Hermes' answer, shown as its own words, so the app does not carry a second copy of Hermes' security rules.

**Sending a token or env value sets the fields to empty afterwards in a `finally`, on success and on failure.** The form's other fields survive a failure so the user does not retype. Values live in `TextEditingController`s only and never in a model, provider or route argument.

**JSON text checks use `dart:convert`.** A `FormatException` carries the offset; the screen turns it into a line number. An object-of-objects check follows. No JSON editor package is added: the need is a monospace text field with a line-numbered error, and a plain `TextField` does that.

**Removal confirmation compares names, not contents.** Names present at load and absent at save are listed. A rename shows as a removal plus an addition, which is honest: Hermes sees it that way and the old server's config is gone.

## Risks / Trade-offs

- [A phone user pastes a command from somewhere untrusted] → The review step is unconditional for command servers, says what runs and where, and Hermes' own check still applies. It cannot make an unsafe command safe.
- [The JSON editor exposes secrets on screen] → Banner on the screen, nothing persisted or logged, telemetry never sees text or bodies (tested). Screenshots and screen recording are the user's own device and choice.
- [Saving a whole map can delete servers another client added since loading] → The confirmation names deletions relative to what was loaded. A second client's additions since then would also be lost; Hermes offers no versioning. The editor re-reads on Retry and says nothing more; noted as a known limit.
- [A large config makes the text field slow on a phone] → Dozens of servers are a few kilobytes; not a concern.
- [Hermes changes the create rules (for example allowing args on remote servers)] → The client does not send fields the current rules refuse; a loosening only makes the form more restrictive than needed, and the contract test notices tightening.

## Platforms and invariants

- **Platforms:** iOS, Android, macOS, Windows, Linux (shared Dart). watchOS is not involved. No dependency, entitlement, manifest or Xcode project change.
- **API layering:** `POST` and `PUT /api/mcp/servers` and `GET /api/config` are in the generated client (`addMcpServerApiMcpServersPost`, `replaceMcpServersApiMcpServersPut`, `getConfigApiConfigGet`); nothing is hand-rolled. Request models `MCPServerCreate` and `MCPServersReplace` are used as generated. `MCPServerCreate` defaults `args` and `env` to empty and would send `[]` and `{}` for a remote server, which Hermes accepts (it tests for truthiness) but the repository passes `null` so that they are left out. `auth` and `bearer_token` are null, and so not sent, for a command server. `MCPServersReplace.servers` is typed `Map<String, Map<String, Object>>`, so the repository drops a top-level `null` field of a server (Hermes reads a `null` as unset) before sending.
- **Auth:** nothing new; 401s go through the existing pipeline.
- **Telemetry:** nothing added; the existing privacy interceptor records no bodies and a test asserts it for both calls.

## Testing

`FakeHermesServer` with per-route answers: the add body for remote (none, header, oauth) and command servers, no forbidden fields for either, disabled Add with each invalid input, arguments with a space, env row validation, the review step before any request and "Back to edit" keeping the form, values hidden in the review, 409, 400 (including suspicious), other failures, secrets cleared after failure, the menu and empty-state entries, the editor loading the full map from `/api/config` (with a field the summary route lacks), `{}` for no key, JSON and shape errors with line numbers, save disabled when unchanged, deletion confirmation, review of new or changed command servers only, the 400 problem list, discard on leaving, and a privacy test for both calls. The contract test gains a check that `/api/config` carries a `mcp_servers` map with the fields the summary route omits, and a round trip against the throwaway backend: add a remote server, load it in the editor form, save it unchanged, and see the list unchanged.
