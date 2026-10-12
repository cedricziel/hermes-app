## Design

A plain suggestion panel accepts labels, descriptions, selected index and a selection callback. Grouped rows use platform spacing, explicit button semantics and selected state. Scroll constraints retain the existing maximum heights. Filtering and completion stay in the composer. When keyboard selection changes, only the suggestion panel scrolls enough to reveal the selected row; draft focus remains unchanged.

## Validation

Cover Apple and Material catalog states, slash keyboard completion and dismissal, teammate insertion and focus, native light/dark renders and isolated live input without sending messages.
