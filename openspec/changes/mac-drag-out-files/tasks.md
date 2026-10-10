One PR, `feat(drag-out)`, about 500 lines. Commits follow the task order.

## 1. Prove the plugin

- [ ] 1.1 Spike: add `super_drag_and_drop` and build macOS (debug and release, universal), iOS simulator, Android debug and Linux in CI; record build time and bundle-size change, the macOS deployment target it needs, and whether the fastlane archive and `scripts/package-linux.sh` still work. Write the result into `design.md`. If it fails, switch the design to a `hermes_app/drag_out` Swift channel and revise this change and `mac-drag-out-text` before continuing.
- [ ] 1.2 Start with a failing test (or a documented manual check where the native view cannot run in tests): with the plugin added and `DropTarget` mounted, a Finder file still attaches and a drag out of the app starts. Resolve any conflict (move the chat drop to the plugin's `DropRegion` behind `AttachmentSource.dropTarget`).
- [ ] 1.3 Verify a click on an attachment card, `SelectionArea` selection and the Kanban card drag are unchanged with a wrapped item (manual check recorded in the PR).

## 2. Drag-out layer

- [ ] 2.1 Start with failing unit tests for `sanitizeDragFileName` (separators, `..`, colon, leading dots, control characters, length, empty fallback, extension kept) and for `DragOutItem` laziness (`read` is not called until the drop); implement `lib/src/drag_out/`.
- [ ] 2.2 Start with failing tests for `PluginDragOutSource` against a fake plugin boundary: virtual file writes the bytes, a failing `read` closes the sink with an error, a null item cancels, unsupported platforms return the child. Implement the adapter and `NoDragOutSource`, provide it in `main.dart`.
- [ ] 2.3 Start with failing tests that the `drag_out.started` breadcrumb, `drag_out.promise` span and `drag_out.completed` event are recorded with only allow-listed attributes (kind, outcome, failure) and that a logging failure does not break the drag; implement them in the adapter.

## 3. Widgetbook

- [ ] 3.1 Add use cases (light and dark, phone and desktop width) for the attachment card with and without drag and the Kanban attachment row, using `NoDragOutSource` and a fake. Extend `test/widgetbook_test.dart` coverage.

## 4. Wire the sources

- [ ] 4.1 Attachments. Start with failing widget tests using `FakeHermesServer`: an attachment with bytes, one with a path, one fetched from `/api/files/download`, one with a 404, one with only a relative path (no drag). Wrap `AttachmentCard` and the thumbnail.
- [ ] 4.2 Kanban attachments. Start with failing tests: row drag reads `/api/plugins/kanban/attachments/{id}` with `board`, 404 fails cleanly, Save and Remove unaffected, card drag unchanged. Add the `onRead` callback to `KanbanTaskAttachments` and wire it from the task controller.

## 5. Documentation and verification

- [ ] 5.1 Update `.claude/skills/verify-in-app/SKILL.md` with the drag-out checks (drag to Finder, Finder file still attaches), update CLAUDE.md's chat and Kanban notes, and the `component-catalog` skill if it lists use cases.
- [ ] 5.2 Run `openspec validate mac-drag-out-files --strict`, `dart format`, `flutter analyze`, `flutter test`; build macOS and run `verify-in-app` against an isolated backend: drag an attachment and a Kanban attachment to the Desktop and compare contents.
