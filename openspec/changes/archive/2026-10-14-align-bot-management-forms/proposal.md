## Why

Bot editing and group creation still use Material alerts instead of the grouped layout now used for bot creation.

## What Changes

Use the shared grouped dialog and labelled rows while preserving every field, validation rule, save/retry path, and member-selection constraint. Non-goals: new bot capabilities, messaging changes, and confirmation-dialog changes.

## Capabilities

No requirement changes. This is a presentation refactor; delta specs are skipped.

## Impact

Bot roster editor, hosted group creation, plain field previews, and existing widget tests. Security and privacy impact: None. Observability: None; existing request instrumentation remains sufficient.
