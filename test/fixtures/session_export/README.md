# Session export fixtures

Answers of `GET /api/sessions/{id}/export?profile=` recorded from a throwaway
Hermes at revision `d923a5eb487a17c0a68801bba9ef0f56c81040a8` (`openapi/HERMES_REF`
when recorded; every file also carries it as `revision`), with a scripted model
on the loopback interface (no provider, no cost).

Each file is `{revision, request, status, headers, body}`. `headers` keeps only
`content-type`, `transfer-encoding`, `content-length` and `allow`; `date` and
`server` are dropped. `body` is the parsed JSON, pretty-printed, keys in the
server's order.

Scrubbed: session ids, message uids and timestamps are invented, the system
prompt and the tool list are shortened, the working folder, profile name and
model address are made up. Nothing else was changed.

- `short.json`: one turn. 200, streamed (`transfer-encoding: chunked`, no
  `content-length`, no `content-disposition`).
- `tools.json`: one turn with a tool call and reasoning on both assistant rows.
- `undone.json`: the second turn undone (`active` 0, `rewind_count` 1).
- `compacted.json`: a chat after `session.compress`, cut from 60 rows to 15
  (rows dropped, none edited), so tool calls and results no longer pair up.
  It has all three row kinds: archived (`compacted` 1), replaced (`active` 0,
  `compacted` 0) and active, with the summary row alone carrying
  `_compressed_summary`.
- `unknown_id.json`, `unknown_profile.json`, `invalid_profile.json`,
  `other_profile.json`: 404 `Session not found`, 404 `Profile '...' does not
exist.`, 400 (the name lower-cased in the text), and a chat asked for under
  another profile (404 `Session not found`).
- `wrong_method.json`, `wrong_route.json`: 405 with `allow: GET`, and 404
  `No such API endpoint: ...`.

Refresh: run the `session export on a scripted model` group of
`test/real_backend_contract_test.dart` with `HERMES_DEV_RECORD=<dir>` against a
fresh throwaway backend, then scrub the `session-export-*.json` files it writes.
