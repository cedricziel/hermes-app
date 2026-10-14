## Decisions

Extract a plain KanbanWorkerLog component before wiring. Bound its scroll region to preserve newest-output positioning inside the shared grouped dialog. Use platform row padding and an adaptive Close action. Keep task/board identity and repository reads unchanged.

## Verification

Cover all visible states in the standalone catalog, run task panel/repository tests and native worker-log workflows, inspect native renders and a disposable fake-data app, then format, analyze and validate OpenSpec.
