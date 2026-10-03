## Context

The sidebar (`thread_sidebar.dart`) renders `ChatController`'s threads, and `ThreadHousekeeping` pages them. `ChatController.open` with `fetchMissing` already opens a chat the loaded pages do not hold, through `_openMissing` and `GET /api/sessions/{id}`. The generated client has `searchSessionsApiSessionsSearchGet`, which returns untyped JSON.

## Goals / Non-Goals

**Goals:** server-side search through the existing route, results that open with the existing open path, widgets testable in Widgetbook without a backend.

**Non-Goals:** see proposal. No client-side filter of loaded threads: the server search covers titles via ids and message text, and mixing two sources would order results inconsistently.

## Decisions

- **Repository**: `HermesChatRepository.searchThreads(query, {profile, limit = 20})` returns `ThreadSearchHit`s (id, title, snippet parts, time). The id is `id`, else `session_id` (both are the compression tip). The title uses the same `title` / `preview` fallback as the thread list. The snippet is split on the `>>>`/`<<<` markers into plain and matched parts so the widget can bold matches without parsing markup; an id match's snippet has no markers and is one plain part.
- **State**: a `ThreadSearch` `ChangeNotifier` holds the query, a status (idle, loading, done, failed) and the hits. It debounces by 300 ms and drops replies to a query that is no longer current (generation counter), so out-of-order answers cannot show stale results. `ChatController` owns it (it knows the repository and profile) and clears it when the profile changes. Alternative considered: state inside the sidebar widget. Rejected: the drawer is rebuilt on each open on phones, which would lose the query, and the widget would need a repository.
- **Widgets**: `ThreadSearchField` and `ThreadSearchResults` are plain-model widgets (query, status, hits, callbacks), with Widgetbook use cases for each state. The sidebar shows the results in place of the thread list while the query is not blank.
- **Opening**: a result opens through `ChatController.open(NotificationTarget(threadId, profile), fetchMissing: true)`, reusing the path notifications use. The query stays, so the user can open another result; on phones the drawer closes as it does for a thread tap.

## Risks / Trade-offs

- [A result's snippet can be long or contain markdown] → shown as plain text, two lines, ellipsised.
- [Every pause fires a request] → 300 ms debounce and the server's own limit of 20 rows; a blank query sends nothing.

## Platforms

All platforms share the Dart code; no native, entitlement or Xcode project change. Invariants touched: none (no auth, token or telemetry change).
