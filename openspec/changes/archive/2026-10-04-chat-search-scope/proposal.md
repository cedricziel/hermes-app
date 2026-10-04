## Why

The Mac native concept moves search out of the sidebar into the window's toolbar, as Mail and Notes have it, and lets a search look through every profile. A chat in another profile could only be found by switching to it first. The sidebar also turned into a phone drawer below 900 points, which a Mac window never does.

## What Changes

- macOS: a search field in the toolbar (a search button in a medium window), opened with ⌘F and closed with Escape or its clear button. While a search is open the sidebar shows its results instead of the destinations and threads; the sidebar's own search field and New chat row go away (New Chat moves into the toolbar too).
- macOS: the results have a scope switch, "This profile" or "All profiles". All profiles searches every profile at once and merges the results newest first; a profile that fails is left out. A hit from another profile names it, and opening it switches to that profile.
- macOS: hits are grouped into Chats (the title matches) and Messages, with counts. An empty field lists the last five searches.
- macOS: the chat toolbar shows the chat's title over "profile · model", New Chat, Copy Transcript, Connection Details and search. In a compact window (under 760 points) Copy Transcript and Connection Details fold into a "…" menu, and the sidebar opens over the content instead of beside it, closing when something in it is picked.

### Non-goals

- Search scope on other platforms: they keep the sidebar search of the active profile.
- Sharing through the system share sheet; the app has no share dependency, so the toolbar copies the transcript.

### Security and privacy

Recent searches are kept on the device in shared preferences (the last five queries). Nothing new goes to the server beyond one search request per profile for an all-profiles search.

### Telemetry

None beyond the HTTP span each request gets.

## Capabilities

### Modified Capabilities

- `chat`: adds "Searching from a Mac toolbar", "Mac chat toolbar" and "Sidebar of a compact Mac window".

## Impact

`ThreadSearch` (scope, open/closed, recent searches), `ChatController` (fan-out), `HermesChatRepository.searchThreads` (hits carry their profile), new Mac widgets (`MacToolbarSearchField`, `MacChatToolbar`, `MacSearchResults`), `MacSplitView` (overlay), `ChatScreen`, `AppShell`.
