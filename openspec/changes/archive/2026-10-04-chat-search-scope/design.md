## Context

`ThreadSearch` (owned by `ChatController`) debounces typing and keeps only the latest answer. `GET /api/sessions/search` takes a `profile` parameter; `HermesProfilesRepository.load` lists the profiles.

## Decisions

- **One search object.** `ThreadSearch` gains a scope with a second search function (`searchAll`), an `active` flag (`begin`/`end`) and the recent queries, rather than a second Mac-only search. Debounce and the generation counter apply to both scopes; switching scope searches again at once.
- **Fan-out in the controller.** `ChatController._searchAllProfiles` lists the profiles, asks each one in parallel with `Future.wait`, drops failed answers and sorts the rest by `updatedAt`. Only when every profile fails does the search fail. Hits carry the profile the repository searched.
- **Opening a hit** goes through `ChatController.open(fetchMissing: true)` with the hit's profile, which already switches profile when needed. Opening a hit, or pressing Return, remembers the query.
- **Chats and Messages** are split in the widget by whether the title contains the query: the server does not say which column matched.
- **Recent searches** are five strings in `SharedPreferencesAsync` (`hermes.recent_searches`).
- **Compact window.** `MacSplitView` checks the window width (`isMacCompact`, under 760 pt). `MacSidebarController.toggle(compact:)` opens an overlay there instead of collapsing the docked sidebar, so the docked state is not overwritten by a narrow window. `ChatScreen` and `AppShell` keep the Mac split view at every width when a `MacSidebarScope` is present.
- **⌘F** is a `HardwareKeyboard` handler in `ChatScreen`, active only while the chat page is in front (`Visibility.of`). The menu bar work can take it over.

## Risks / Trade-offs

- [All profiles sends one request per profile] → only when the user picks that scope; profiles are few.
- [Title match is a guess] → a title that contains the query but matched in a message still lands under Chats, which reads fine.
