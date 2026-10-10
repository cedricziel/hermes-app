Prerequisite: `mac-drag-out-files` is merged (plugin decision, `lib/src/drag_out/`). One PR, `feat(chat)`, about 400 lines.

## 1. Export function

- [ ] 1.1 Start with failing tests for a thread export function: output is `# <title>`, a blank line, then exactly `threadTranscript(messages)`; an empty thread yields the heading only; file name is the sanitized title with `.md`, empty title gives `Chat.md`, `../../x/y: z` has no separators or colon.

## 2. Widgetbook

- [ ] 2.1 Add use cases (light and dark, phone and desktop width) for the message grip on hover (finished reply, sent bubble, streaming without grip) and a draggable thread row, using `NoDragOutSource` and a fake. Extend `test/widgetbook_test.dart` coverage.

## 3. Wire the sources

- [ ] 3.1 Message text. Start with failing tests: grip on finished replies and sent bubbles, none while streaming or with no text, the dragged item carries the Markdown source as plain text and Markdown (no file), selection still works. Wire into `MessageActions` and the sent bubble; extend the adapter to offer both text formats.
- [ ] 3.2 Threads. Start with failing tests: the file content equals the export function's output across unloaded pages (fake server with 3 pages), unsaved thread not draggable, history failure logs `failure: history` and produces no file. Wrap `MacThreadRow` in `ThreadSidebar._row`; keep tap, double-click, right-click and hover buttons working.
- [ ] 3.3 Extend the observability allow-list test with kinds `text` and `thread` and failure `history`.

## 4. Documentation and verification

- [ ] 4.1 Update `.claude/skills/verify-in-app/SKILL.md` with the checks (drag a reply into a text app, drag a long thread to the Desktop), update CLAUDE.md's chat and sidebar notes, and check the `workflow-screenshots` flows for the grip.
- [ ] 4.2 Run `openspec validate mac-drag-out-text --strict`, `dart format`, `flutter analyze`, `flutter test`; build macOS and run `verify-in-app` against an isolated backend: drag a reply and a long thread and compare contents with Copy Transcript.
