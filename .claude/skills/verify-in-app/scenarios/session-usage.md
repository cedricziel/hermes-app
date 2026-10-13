# Session usage

Follow the shared isolation procedure before launching. Use synthetic conversations on the pinned backend and record the backend revision and exact app source.

1. Start a conversation, then open Session usage. Confirm one `session.usage` read uses the already confirmed runtime and resolved profile. Rendering the closed disclosure must not request usage or resume a conversation.
2. Send a prompt long enough to observe live snapshots. Confirm repeated counters replace the previous values and the reply remains active until its normal completion. Confirm final completion usage replaces live values; omitted final usage preserves the last snapshot without claiming a new final measurement.
3. Show a fixture with partial metrics and estimated context. Confirm missing metrics are hidden, estimated context is labeled, and cost is shown only when the server supplies it.
4. Disconnect during a usage read. Confirm known values become stale. Reconnect the selected conversation through its normal attachment path and confirm a fresh bounded read uses the newly confirmed binding.
5. Switch profiles or lock the app while a read is pending. Confirm the old result and old live ticks cannot appear in the new protected context.
6. Return method-not-found or delay only the optional usage read. Confirm usage reports its availability/freshness while the same chat socket can still send another prompt.

The baseline `167e9fdb84248cd0fff80762dc57b6a914b6e930` resolves `session.usage` by in-memory runtime ID without ambient-profile fallback. Never substitute a stored ID or issue a resume solely for inspection. Nullable-profile reads require an owned runtime on the exact current connection; account/credits fallback lines are not displayed.

Record native observations separately from automated receipts. The implementation receipt is 43 focused tests and a clean scoped analyzer; native usage verification remains pending.
