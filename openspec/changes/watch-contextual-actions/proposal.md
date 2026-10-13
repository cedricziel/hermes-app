## Why

The same reply chips appear in an empty chat and after every answer, while actual questions require structured actions. Contextual built-in actions give users a useful starting point without custom favorites configuration.

## What Changes

- Offer built-in starters in an empty new chat that populate an editable draft.
- Offer Continue and Summarize after a completed assistant reply.
- Delegate pending approval and question actions to their structured request views.
- Preserve voice review and optional manual fast-send gesture behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Replace fixed reply chips with context-dependent built-in starters and follow-ups.

## Impact

`ios/HermesWatch/ConversationView.swift`, portable action selection in the watch core, and native fixtures. Depends on `watch-voice-review`, `watch-conversation-usability`, `watch-inline-approvals`, and `watch-inline-questions`. Archive the completed `watch-quick-replies` baseline before its successors.

### Non-goals

Custom favorites, favorites persistence or configuration on watch or phone, server-generated suggestions, inferred Yes/No answers, new backend routes, and automatic starter submission.

### Security and privacy

No tokens or sensitive content are added to storage. Starters are fixed bundled text, and their editable drafts follow existing logout and connection-reset rules. Request actions retain authentication and App Lock gates from inline-request changes.

### Observability

None beyond existing content-free relay diagnostics. Action selection and draft presentation are local UI decisions; adding exported usage logs would not help resolve a relay failure.
