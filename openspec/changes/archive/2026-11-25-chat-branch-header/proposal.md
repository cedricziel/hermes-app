# Proposal

## Why

Branching from a reply shipped in #880: every finished reply offers "Branch in new chat", and the copy opens as a new chat. Issue #458 asked for more, and that part is still missing. A branched chat does not say where it came from, and there is no way back to the chat it was cut from. In the chat list a branch looks like any other chat, and so does a chat that merely has the same title. A person who branched twice from one conversation cannot tell the three chats apart except by reading them.

## What Changes

- A branched chat shows one quiet row under its header: "Branched from <title>". A tap opens the original chat. The parent is unchanged.
- The row has five states: the title is known, the title is not loaded ("another chat"), opening, the original was deleted (information only), and Hermes could not be reached (tap to try again).
- In the chat list and the Mac sidebar a branch is marked by a small branch glyph before its title. Rows are not nested under the parent and gain no second line.
- On the Mac, Chat > Open Parent Chat does the same as the row.
- No "Branch from here" on a user prompt (decided, with the reason, in `design.md`).

## Non-goals

- Assistant-ui's in-place branch picker, as in #458: Hermes stores branches as separate sessions.
- Listing a chat's branches on the parent ("3 branches"). Needs a scan of every loaded row for `_branched_from` and says nothing for rows not loaded; later, if wanted.
- Nesting branches under their parent in the list, as Hermes' own desktop app does (`apps/desktop/src/lib/session-branch-tree.ts`). It conflicts with the app's recency sections, folder grouping, pins and swipe rows (see `design.md`).
- Using `session.branch`'s `count` or `idempotency_key` (the shipped flow cuts with `session.undo`; see `docs/architecture/chat.md`). Reusing an idempotency key on a retry is a separate item of #458.
- Conversation windows and the quick panel: `ChatScreen` is the only caller that passes the notice to `boundChatThreadView` (as it does `workspaceNotice`), so they show none.

## Security and privacy impact

The notice shows a chat title, so it is covered by App Lock like the rest of the screen. The parent's title and id never reach a breadcrumb, span, log, the surface snapshot, a notification, Spotlight, Handoff, a Live Activity or the watch. See `design.md`, Decisions 4 and Observability.

## Observability

One breadcrumb, `chat.branch_parent.open`, with `outcome` (`opened`, `deleted`, `unreachable`, `dropped`) and nothing else.

## Design pass

Canvas on the "Hermes App" design system: https://claude.ai/artifact/XJvFv9KZFAGCTNDLNFyFnS (private; ask its owner for access). Record: `docs/design-briefs/chat-branch-header.md`, and `design.md` here.
