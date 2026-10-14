One PR, `feat(drag-out)`, about 500 lines. Commits follow the task order.

## 1. Prove the approach

- [x] 1.1 Spike: build `super_drag_and_drop` on macOS, iOS, Android and Linux, record the cost in `design.md`, and fall back to a hand-written Swift channel if it is too costly. Done: it builds everywhere but needs a Rust toolchain on every build machine and a pre-release, so the change uses the Swift channel (see the design).
- [ ] 1.2 Check by hand, since a real drag cannot run in tests: with the controller registered and `DropTarget` mounted, a Finder file still attaches and a drag out of the app delivers a file. The pointer logic is covered by `mac_drag_out_source_test.dart`, the promises by `DragOutTests.swift`.
- [ ] 1.3 Verify a click on an attachment card, `SelectionArea` selection and the Kanban card drag are unchanged with a wrapped item (manual check recorded in the PR). Not run yet, same reason as 1.2.

## 2. Drag-out layer

- [x] 2.1 Start with failing unit tests for `sanitizeDragFileName` (separators, `..`, colon, leading dots, control characters, length, empty fallback, extension kept) and for `DragOutItem` laziness (`read` is not called until the drop); implement `lib/src/drag_out/`.
- [x] 2.2 Start with failing tests for `MacDragOutSource` against a mocked channel (drag past the slop starts a file or text session, a click or touch or secondary button does not, a null item cancels, reads are lazy, a failing read fails the call, write and cancel outcomes are logged) and `DragOutTests.swift` for the file promises and the text pasteboard item. Implement `MacDragOutSource`, `DragOut.swift` and `NoDragOutSource`; provide the source in `main.dart`.
- [x] 2.3 Start with failing tests that the `drag_out.started` breadcrumb, `drag_out.promise` span and `drag_out.completed` event are recorded with only allow-listed attributes (kind, outcome, failure) and that a logging failure does not break the drag; implement them in the adapter.

## 3. Widgetbook

- [x] 3.1 Add use cases (light and dark, phone and desktop width) for the attachment card with and without drag and the Kanban attachment row, using `NoDragOutSource` and a fake. Extend `test/widgetbook_test.dart` coverage.

## 4. Wire the sources

- [x] 4.1 Attachments. Start with failing widget tests using `FakeHermesServer`: an attachment with bytes, one with a path, one fetched from `/api/files/download`, one with a 404, one with only a relative path (no drag). Wrap `AttachmentCard` and the thumbnail.
- [x] 4.2 Kanban attachments. Start with failing tests: row drag reads `/api/plugins/kanban/attachments/{id}` with `board`, 404 fails cleanly, Save and Remove unaffected, card drag unchanged. Add the `onRead` callback to `KanbanTaskAttachments` and wire it from the task controller.

## 5. Documentation and verification

- [x] 5.1 Update `.claude/skills/verify-in-app/SKILL.md` with the drag-out checks (drag to Finder, Finder file still attaches), update CLAUDE.md's chat and Kanban notes, and the `component-catalog` skill if it lists use cases.
- [ ] 5.2 Run `openspec validate mac-drag-out-files --strict`, `dart format`, `flutter analyze`, `flutter test`; build macOS and run `verify-in-app` against an isolated backend: drag an attachment and a Kanban attachment to the Desktop and compare contents.
