## 1. Panel

- [x] 1.1 Failing test, then `KanbanTaskPanel.onClose` so archive and delete close an inspector instead of popping a route

## 2. Inspector state

- [x] 2.1 Failing tests, then `KanbanInspector` (open, toggle, close, remembered visibility)

## 3. Widgets (catalog first)

- [x] 3.1 `KanbanMacToolbar` and `MacToolbarMenu` with Widgetbook use cases (all profiles, filtered, compact)
- [x] 3.2 `KanbanInspectorLayout` with use cases (docked with and without a task, hidden, overlay)

## 4. Screen

- [x] 4.1 Failing widget tests (`test/kanban_mac_inspector_test.dart`), then wire `KanbanScreen` on macOS: toolbar, inspector, selected card, ⌥⌘I, ⌘N, Mac column sizes
- [x] 4.2 macOS steps in `test/workflows/kanban_workflow_test.dart` (large, medium, compact, dark)
- [x] 4.3 Check in the running macOS app against the dev backend

## 5. Docs

- [x] 5.1 Update CLAUDE.md's Kanban notes and sync the delta into `openspec/specs/kanban/spec.md`
