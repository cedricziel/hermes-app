## Context

See proposal.md for motivation. `QueuedPrompt` holds text, display text, and `SharedFile` paths. `ChatController` holds queues by object identity and clears them when loading threads. Clipboard attachments can live in `Directory.systemTemp`. `accountKeyFor` already hashes server address and user identity. No authenticated queue-payload encryption adapter currently exists.

## Goals / Non-Goals

Provide a narrow storage adapter with testable commit, load, mark-submission-started, accept, discard, and identity-cleanup operations. Do not wire it into the controller in this PR. Existing chat behavior stays unchanged until the recovery proposal is applied.

## Decisions

Use separate authenticated encrypted record envelopes and encrypted attachment blobs, with a versioned content-free index in app-private non-backed-up storage. Use authenticated encryption from a maintained Dart cryptography package, with a random per-account key in `flutter_secure_storage`, fresh nonces, and authenticated identity/version metadata. `crypto` hashing alone cannot encrypt content. Secure storage is appropriate for keys, not base64 copies of large attachments. File permissions and OS data protection supplement encryption. iOS uses app-private storage rather than an app-group container. Configure backup exclusion on iOS and Android for queue storage. The queue key must not alter token storage options.

Serialize storage operations within the protected directory and take an exclusive file lock across processes. Commit files to temporary siblings, flush, and atomically rename the record envelope only after every attachment blob is durable, then update the index. Retain the preceding committed envelope on failure. An index failure after envelope commit is recoverable by scanning valid envelopes. Reclaim unreferenced temporary files during next load. Authenticate the complete record identity and encrypt attachment names. Embed identity, FIFO sequence, and state in each authenticated record envelope. The index contains only opaque local record references. If the index is corrupt, rebuild it from independently verified envelopes; never discard all records because one envelope fails integrity verification. If no valid envelopes exist, report corruption without claiming recovered data. Preserve a stable local record ID and FIFO sequence, exact profile value including null, persisted session identity or unresolved local identity, display text, submitted text, attachment metadata, and state. Never infer identity from titles.

Persist submission-started before a network send can begin. Atomically claim each record with a random local dispatch token and retain only its hash in the encrypted envelope. A second dispatcher cannot claim the same uncertain record. A proven pre-RPC failure can restore only the record carrying its exact dispatch claim. Legacy uncertain records without a claim remain uncertain. Persist acceptance before payload cleanup, then garbage-collect accepted records. A crash in either transition can leave an uncertain record but cannot silently reset it to unsent. The store does not validate backend acceptance itself. The controller provides that result in the dependent proposal.

Deletion first makes the identity inaccessible, then removes files and secure keys. Record a content-free cleanup tombstone where available and retry deletion on next unlock. Changing profiles is not deletion. Missing keys or corrupt envelopes produce explicit outcomes; do not generate a replacement key over unreadable records.

Platforms: iOS, Android, macOS, Windows, and Linux Dart storage. watchOS neither stores queues nor reads their keys. iOS backup exclusion and Android backup-rule changes may be needed; no new entitlement or Xcode capability is required. Desktop secure-storage availability must fail closed with an explicit persistence error.

Project invariants: tokens remain in secure storage; telemetry is optional and cannot break persistence; no REST client changes. The adapter records `chat.queue.storage` spans around operations with fixed operation/outcome, counts, bytes, and existing connection `hermes.*` attributes only when supplied. `chat.queue.storage_failed` logs operation, fixed reason, and error type. No text, identifiers, names, paths, tokens, addresses, or bytes are recorded.

## Risks / Trade-offs

- Encryption and attachments can exceed a small PR if combined with UI. Keep this adapter separate from recovery wiring and reuse existing attachment limits.
- Disk exhaustion or missing secure storage can prevent enqueueing. Return failure before the caller clears input.
- Secure deletion of flash storage cannot be promised. Destroy keys and remove app-owned blobs; do not claim forensic erasure.
- A rollback to an older app cannot read durable queues. Retain versioned records so reinstalling the newer app can recover them unless sign-out cleanup was requested.

## Migration Plan

No migration of prior in-memory queues is possible. Add the store without enabling dispatch. Test it across restarts using a temporary directory and fake secure-key adapter. Apply the dependent recovery change to enable it. Do not change generated APIs or backend contracts.

## Verification status

Temporary-directory tests use fake keys and establish record integrity, attachment retention, failure boundaries, deletion isolation, and privacy. Native backup flags, iOS file protection, and OS keychain behavior remain pending. Recovery and dispatch UI verification belongs to the dependent change.
