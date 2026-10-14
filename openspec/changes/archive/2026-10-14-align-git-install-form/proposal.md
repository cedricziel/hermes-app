## Why

Git installation uses an alert, outlined input and unrelated warning styling instead of the grouped forms used by the app.

## What Changes

Reuse grouped input, warning, acknowledgement and switch rows with a fixed action footer. Preserve explicit source trust, disabled install until valid and trusted, busy state, enable/force flags and secret handling. Non-goals: installation behavior or new permissions.

## Capabilities

No requirement changes. Presentation refactor; delta specs skipped.

## Impact

Git installation dialog, catalog and UI tests. Security/privacy: existing unreviewed-code warning and acknowledgement remain mandatory; suggestions remain disabled for source text. Observability: None added.
