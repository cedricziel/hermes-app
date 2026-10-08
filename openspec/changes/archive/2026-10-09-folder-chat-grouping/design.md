## Context

The sidebar already uses native adaptive menus and Mac source-list headers. Session rows include cwd and git_repo_root; the upstream workspace key uses repository root before cwd. Current paging and search must survive grouping.

## Goals / Non-Goals

Goals: share folder grouping logic across platforms and keep iOS controls compact.
Non-goals: full project management, filesystem access, and workspace reassignment.

## Decisions

Keep a nullable folder path on each chat, parsed by the existing repository. Group loaded chats by that path rather than fetching the project tree, because this request groups filesystem folders and does not manage named Projects. Preserve pinned and list ordering, use full path identities, and disambiguate colliding basenames.

Keep device grouping and folder disclosure state in preferences. Reuse the existing Mac recency disclosure storage. Ignore storage failures and guard preference restoration against user changes.

Add Recent and Folder to a small ellipsis menu on the first visible section header. An empty list shows a Chats header with the same menu. Keep disclosure and grouping as separate buttons, so opening the menu does not collapse the section. Use plain secondary-text headers with touch targets on iOS and existing source-list headers on Mac. Other platforms keep their existing flat Recent list but can opt into folders.

Platforms: iOS, Android, macOS, Windows, Linux. watchOS unchanged. No native project, entitlement, or manifest changes. Existing generated API and token storage remain unchanged.

## Risks / Trade-offs

Counts cover loaded pages only; retain Show more and automatic paging. Folder metadata for chats created during this app session is unknown until their session rows are read again; they use No folder meanwhile. Older servers lack metadata; keep their chats usable.
