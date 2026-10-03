## ADDED Requirements

### Requirement: Thread search

The sidebar SHALL offer a search field above the thread list. While it holds text, the system SHALL search the active profile's sessions on the dashboard once the user has stopped typing for a short pause, and SHALL show the results in place of the thread list. Each result SHALL show the chat's title and the text that matched, with the matched words emphasised. Tapping a result SHALL open that chat, including one the loaded pages of the thread list do not hold. Clearing the field SHALL show the thread list again, and switching profile SHALL clear the search.

The system SHALL rely on `GET /api/sessions/search?q=<text>&limit=<n>&profile=<name>`, which answers `{"results": [...]}`. Each row carries `session_id` (and usually `id`), and may carry `title`, `preview`, `snippet` (FTS5 text with matches wrapped in `>>>` and `<<<`), `last_active` and `session_started` (epoch seconds). Rows without a usable id SHALL be skipped. The route exists in the Hermes version the real-backend contract test is pinned to.

#### Scenario: Results replace the list

- **WHEN** the user types a query and pauses
- **THEN** the dashboard is searched once for it on the active profile and the matching chats are shown instead of the thread list, each with its title and matched text

#### Scenario: Typing does not search on every key

- **WHEN** the user types several characters in quick succession
- **THEN** only the text present after the pause is searched

#### Scenario: No match

- **WHEN** the search returns no rows
- **THEN** the sidebar says that no chat matches the query

#### Scenario: Search fails

- **WHEN** the search request fails
- **THEN** the sidebar says the search failed, and the thread list is unchanged

#### Scenario: Opening a result not in the loaded list

- **WHEN** the user taps a result for a chat older than the loaded pages
- **THEN** that chat is fetched, added to the list and opened

#### Scenario: Clearing the search

- **WHEN** the user clears the field
- **THEN** the thread list is shown again

## REMOVED Requirements

### Requirement: No thread search

**Reason**: Replaced by "Thread search"; the dashboard offers a session search route.

**Migration**: None. The sidebar gains a search field above the thread list.
