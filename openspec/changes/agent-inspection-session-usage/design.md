## Context

The implementation consumes session counters from `session.usage` and completion usage. The inspected backend baseline is `167e9fdb84248cd0fff80762dc57b6a914b6e930`. In `tui_gateway/methods_session.py`, `session.usage` uses the session-scoped method decorator. `tui_gateway/server.py::_sess_nowait` resolves only the in-memory runtime ID and rejects unknown IDs; it never resolves a stored chat ID or falls back to the active profile. `_session_usage_snapshot` reads the session agent or session metadata mirror. Earliest released-version support remains unverified.

## Goals / Non-Goals

Goals: show one scoped usage snapshot and preserve unavailable, estimated, and stale states.

Non-goals: storing usage history, adding usage to Watch payloads, or allocating session counters to individual messages.

## Decisions

Add a small validated usage value to gateway events and chat state. Render a compact disclosure beside the active conversation controls. Preserve numeric presence rather than applying schema default zeros locally. Reject negative or non-finite metrics; tolerate unknown optional fields. Use the existing gateway event envelope runtime ID and stamp its physical connection token before routing; the nested usage object has no session identifier. Do not route broadcast usage to whichever session happens to be open.

Fetch `session.usage` when opening the disclosure and after a confirmed reconnect. The optional read uses the already owned runtime and the current connection directly with a bounded timeout; it never resumes a chat, guesses a runtime from a stored ID, or enters the generic RPC failure path that drops a socket. Preserve the resolved profile. A nullable profile is allowed only with this confirmed runtime proof: the pinned resolver does not consult the ambient profile, and the decoder ignores account and credits lines that could contain ambient fallback data.

`OwnedSessionTransport` exposes a pure lookup and a separate ownership stream. Bindings compare physical connection identity, confirmed runtime, and profile. Same-socket send/watch takeover keeps an equal binding; socket loss invalidates lookup, and reclaim retires its binding. Activity or profile replacement clears controllers and rejects pending reads. The ownership stream carries an opaque resume token before an existing resume request and the optional `todo_state` subset on confirmation, so later consumers can reject a delayed snapshot after newer live state without adding a new resume call. Initial confirmation precedes delivery of buffered chat events. Apply generation guards to fetch results. Live events replace the visible snapshot; `message.complete.usage` takes precedence at completion. Do not add a polling loop or sum ticks. Use transport ordering and ignore obsolete fetch generations when a newer live event has arrived.

Affected platforms: iOS, Android, macOS, Windows, and Linux. watchOS is unchanged. No entitlements, manifests, or Xcode project changes.

Auth storage and concurrent-401 invariants remain unchanged. Existing gateway RPC authentication owns authorization; the feature never stores tokens or adds hand-written REST calls.

Record `chat.usage.fetch` span at the chat usage fetch boundary with fixed outcome and inherited `hermes.*` connection attributes. Record `chat.usage.fetch_failed` through AppEventLogger with fixed failure category. Record `chat.usage.open` breadcrumb at disclosure opening, with no IDs or content. Telemetry remains opt-in and failure-tolerant.

## Risks / Trade-offs

- Session totals can decrease after a backend reset. Replace them with the new snapshot; do not enforce monotonic client counters.
- A final payload can omit usage. Retain freshness explicitly and allow refresh.
- Earliest release support is unknown. Test the pinned contract and keep optional-read failures independent of chat.
- The standalone module and shared ownership wiring exceed the original approximate 500-line target. Keep one coherent usage change as requested; later todo consumers depend on the neutral binding API.

## Migration Plan

Ship as an additive disclosure. Rollback removes the UI and mapping without server or stored-data migrations.
