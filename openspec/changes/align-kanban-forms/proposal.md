## Why

Task editing, board import/export and orchestration still use Material alerts and controls rather than the app's grouped forms.

## What Changes

Use shared grouped dialogs, labelled fields, switches and profile menus. Preserve all values, validation, trimming, paths, changed-only configuration writes and error handling. Non-goals: new Kanban behavior, backend contracts or changes to brief confirmations/errors.

## Capabilities

No requirement changes. Presentation refactor; delta specs skipped.

## Impact

Three Kanban form files, existing behavior tests and render workflows. Security/privacy and observability: None; existing server-only path semantics and authenticated requests remain unchanged.
