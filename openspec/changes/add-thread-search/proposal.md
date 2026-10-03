## Why

The sidebar only pages through threads, so an older chat is reached by scrolling until it loads. The chat spec records this as "No thread search" (#105). The dashboard already answers `GET /api/sessions/search`, a full-text search over session ids and message text, so the app can offer search without a server change.

## What Changes

- A search field at the top of the thread list in the sidebar, on phone (drawer) and desktop.
- Typing searches the active profile's sessions on the server once the user pauses (debounced); the thread list is replaced by the results while the field holds text.
- Each result shows the chat's title and the matching text, with the matched words emphasised.
- The result list has loading, no-match and failed states. A failed search does not touch the thread list.
- Tapping a result opens that chat, also when it is older than the pages the sidebar has loaded.
- Clearing the field brings the thread list back. Switching profile clears the search.

### Non-goals

- Filtering by source, date or archived state; the route takes `source`, but the app sends only `q`, `limit` and `profile`.
- Searching across all profiles at once.
- Jumping to the matched message inside the opened chat.
- Searching offline or on the device.

### Security and privacy

None. The query goes to the user's own server over the existing authenticated client and is not stored or logged.

### Telemetry

None beyond the HTTP span every dashboard request already gets.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: the "No thread search" requirement is replaced by a "Thread search" requirement covering the field, the results, their states and opening a result.

## Impact

- `lib/src/chat/hermes_chat_repository.dart`: a search call that parses the result rows leniently.
- A small search state holder next to `ChatController`, and the sidebar widgets that show the field and the results.
- `widgetbook/` use cases for the result states, `test/real_backend_contract_test.dart` for the row shape.
- No API spec or generated client change: `searchSessionsApiSessionsSearchGet` already exists.
