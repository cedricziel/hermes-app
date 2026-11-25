# Design brief: Branched from, in a chat and in the list

Change: `openspec/changes/chat-branch-header/`. Read its design.md for the server facts (which row keys carry the parent, why `parent_session_id` alone is not a branch, what a deleted parent leaves behind, the `latest-descendant` probe); this brief is the visual and copy pass. Issue: #458. The "Branch in new chat" action already shipped in #880 (`docs/architecture/chat.md`, "Branching").

## Design (done)

Design (done): canvas published, local render reviewed

Canvas: https://claude.ai/artifact/XJvFv9KZFAGCTNDLNFyFnS (private; ask its owner for access). 11 boards on the "Hermes App" design system: five phone states of the notice (title known, title not loaded, opening, deleted, could not reach Hermes), largest text, dark, Android with a long title, the list rows on phone and Mac, the Mac window, and the notice as a component (the parametric page the others import).

Screens and states decided: one row under the header with five states; a branch glyph on the thread rows; one Mac menu entry.

Decisions, one line each:

- The notice is a fixed row between the header and the transcript, in the slot `FolderMismatchNotice` uses. Not in the app bar (the working-directory line is already there and would not wrap at large text), not the first transcript item (it would sit behind pages of "Load older" in a long branch).
- It is one `<button>`: muted "Branched from", the parent's title in the foreground colour at weight 500, a chevron. 44 pt on iPhone and iPad, 48 dp on Android, 32 pt on the Mac. It wraps to two lines, then ends in an ellipsis; at the largest text size it grows.
- The title is looked up in the loaded threads. A parent that is not loaded (another page, archived, or compressed since) reads "Branched from another chat" and is still tappable. The title is never fetched just to fill the row.
- A tap asks `latest-descendant` and opens the answered chat; the parent is not changed and has no counterpart row ("branches of this chat" is a non-goal).
- Deleted parent: the row becomes information (info icon, "The original chat was deleted.", no chevron, not a button). It is learned from the 404 of a tap, not guessed, and is kept in memory for the session only.
- Could not reach Hermes: warning icon, the sentence, and a "Try again" label in the link colour; the row stays a button. Nothing is retried by itself; the 10-second rule applies to "Opening the original chat…".
- Status is icon plus words in every state, no tint on the row. The row has no background of its own, only the hairline under it (`--h-border-subtle`).
- List: a 14 pt branch glyph (12 pt on the Mac source list) before the title, muted, "Branch" added to the accessibility label. No nesting under the parent (Hermes' desktop app nests; here it would fight recency sections, folder grouping, pins and swipe rows), no second line, no parent title in the row. Search results get the same glyph.
- No "Branch from here" on a user prompt: undo takes a prompt with its reply, so a branch can only end after a reply; the prompt variant is "Edit in a new chat", a different feature.
- Mac: Chat > Open Parent Chat, no chord, disabled when there is no parent or the parent is deleted. No row-menu entry.
- Conversation windows and the quick panel show no notice.

Corrections: the first render showed no icon in the "could not reach" state (the icon name `wifi_off` is not in the design system's set), so it uses the `warning` icon. The rows board was taller than its content and was cut to 280.

### Local render review

The canvas was rendered in headless Chrome from the published files (the runtime from the canvas, the design system from its copy) and the boards were looked at: the five phone states, largest text, dark, Android, the list rows and the Mac window. `Notice` alone and the claude.ai viewer were not checked.

What could not be checked: the canvas in the claude.ai viewer; real devices; largest text is CSS `zoom: 1.6`, not an OS text scale, and at that zoom the design system's own header truncates the chat title to "Mov…" (the app's header has its own large-text rule); the list rows are hand-made markup, not the design system's `ThreadSidebar` (it has no branch glyph); contrast by eye only (muted text on white passes AA, see the design-pass skill); the Mac chat menu entry (drawn in no board); screen-reader order.

Copy added by the design (English; German in the table):

- "Branched from {title}", "Branched from another chat", "Opening the original chat…", "The original chat was deleted.", "Couldn't reach Hermes. Check your connection.", "Try again", the Mac menu entry "Open Parent Chat", the row's semantics label "Branched from {title}. Opens the original chat.", the list glyph's label "Branch".

| Key (suggested) | English | German |
| --- | --- | --- |
| `chatWidgetsBranchNoticeFrom` | Branched from {title} | Verzweigt von {title} |
| `chatWidgetsBranchNoticeFromUnknown` | Branched from another chat | Verzweigt von einem anderen Chat |
| `chatWidgetsBranchNoticeOpening` | Opening the original chat… | Der ursprüngliche Chat wird geöffnet… |
| `chatWidgetsBranchNoticeDeleted` | The original chat was deleted. | Der ursprüngliche Chat wurde gelöscht. |
| `chatWidgetsBranchNoticeUnreachable` | Couldn't reach Hermes. Check your connection. | Hermes ist nicht erreichbar. Prüfe deine Verbindung. |
| `chatWidgetsBranchNoticeRetry` | Try again | Erneut versuchen |
| `chatWidgetsBranchNoticeSemantics` | Branched from {title}. Opens the original chat. | Verzweigt von {title}. Öffnet den ursprünglichen Chat. |
| `chatWidgetsBranchRowLabel` | Branch | Verzweigung |
| `macosMenuOpenParentChat` | Open Parent Chat | Übergeordneten Chat öffnen |

New components needed:

- `ChatBranchNotice`: the row, five states, plain model (`state`, `parentTitle`, `onTap`). Closest existing: `AppBanner` (tinted, for outcomes) and `FolderMismatchNotice`; neither fits a quiet link row, so it is new. Build it once in `lib/src/chat/widgets/`.
- A `branch` flag on the thread row models (`SidebarRow`'s child, `MacThreadRow`, search rows): the glyph. Closest existing: `MacThreadRow`'s avatar slot (Bot Chats), which stays separate.

Component props guessed and not confirmed: `HermesUI.Icon` takes `name` and `size`, `HermesUI.Spinner` takes `size` (both rendered correctly in the local render); the icon names `call_split`, `chevron_right`, `info`, `warning` rendered, `wifi_off` did not.

## Who uses it and why

Someone who branched a chat to try another approach, and later opens the branch from the list, or comes back to it after days. They need two things: to see at a glance that this chat is a branch, and to get back to the chat it was cut from. Today neither is possible short of reading both.

## Components to reuse

`FolderMismatchNotice`'s slot (between the header and the transcript), `NamedIconButton`-style 44 pt target rules, `BusyBar` or the shared spinner for "Opening…", `AppIcons` for the glyph (a new `branch` entry if none fits), `MacCommandScope` for the menu entry. Not `AppBanner`: a banner reports an outcome; this row is a link.

## Screens

1. **The notice, resting** (title known, title not loaded): the row, chevron on the right. Tap opens the parent as selecting it from the list does (phone: the page swaps, the drawer is the way back; Mac and iPad: the sidebar selection moves).
2. **Opening**: spinner in place of the chevron, "Opening the original chat…", the row ignores taps. Ends within 10 s.
3. **Deleted**: information only.
4. **Could not reach Hermes**: "Try again".
5. **List rows**: glyph before the title, phone, iPad, Mac source list, search results, swipe actions unchanged.
6. **Mac**: the row under the toolbar; Chat menu entry.

## Accessibility and motion

The row is one `Semantics` button with the label above (not for `deleted`, which is plain text with the same words). A state change is announced once (`SemanticsService.sendAnnouncement`): "Opening the original chat", then nothing on success (the chat changes), the sentence on failure. The spinner honours reduced motion. Touch targets 44 pt (48 dp), Mac 32 pt. The glyph carries no information the label does not.

## Differences by platform

iPhone and iPad: 44 pt row, Cupertino chevron. Android, Windows and Linux: 48 dp row, Material chevron. Mac: 32 pt row, 12 pt glyph in the source list, Chat menu entry. Conversation windows and the quick panel: nothing.

## App Lock, offline, deleted

App Lock covers the whole in-app UI, so the row is hidden with the rest; a read that finishes under the cover does not change the selection. Outside the app (snapshot, notifications, Spotlight, Handoff, Live Activities, watch) the parent's title and id never appear. Offline: a loaded parent still needs the one `latest-descendant` read, so the row ends in "could not reach Hermes" and offers a retry; chats cached elsewhere are not used.
