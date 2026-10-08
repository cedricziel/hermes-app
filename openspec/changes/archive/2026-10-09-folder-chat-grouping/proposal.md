## Why

Chats become hard to browse as their list grows. Users need folder sections without a large grouping switch on iOS.

## What Changes

Add a compact Group by menu with Recent and Folder choices. Folder sections collapse and show counts; pinned chats stay first. Remember the choice and folded sections locally. Group by the server-reported repository root, falling back to the working directory; missing paths use No folder.

## Capabilities

### New Capabilities
- `chat-folder-grouping`: Folder grouping and a compact grouping menu for the chat list.

### Modified Capabilities
None.

## Impact

Session metadata parsing, sidebar widgets, preferences, Widgetbook, and tests. Reuse GET /api/sessions; no new route or generated API changes. No project creation or folder assignment, and no watchOS changes.

Security and privacy: folder paths already returned by the server remain on the device. No token storage changes or new network calls. Preferences store grouping and folded section identities locally.

Telemetry: None.
