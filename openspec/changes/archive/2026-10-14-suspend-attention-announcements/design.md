## Context

AttentionNotifier waits for an outstanding device permission request before posting an announcement. Notification services may also await native initialization or category registration. Either wait can cross a session pause.

## Goals / Non-Goals

Fence announcements by session activity while preserving device permission state and notification routing intents. Screen retention, background work, and root routing remain outside this change.

## Decisions

Use an optional ValueListenable<bool> activity signal. Absence means active. Each activity transition advances an epoch, so a pause followed by resume cannot authorize an old announcement. Dispose also invalidates the epoch and removes the activity listener.

Authorization reads the live activity value because an earlier listener may invoke notification work before the notifier's own activity listener runs. Every delivered activity notification invalidates the epoch. An earlier listener can resume activity reentrantly, so comparing only the final value with a cached value can miss the intervening pause.

Check activity before computing a private announcement or requesting new permission. Capture the epoch for each announcement and check it after an outstanding permission request. Supply the same predicate to GuardedNotificationService for its final platform dispatch. Services without that capability receive a check immediately before show.

An already requested permission result is device state and remains recorded after pause or dispose. Tap listeners and takeLaunchTarget continue forwarding intents during pause; the root routing owner decides when to act on them. Dispose retains its existing tap-subscription cleanup.

Platforms affected are iOS, Android, macOS, Windows, and Linux. watchOS companion behavior is unchanged. No native entitlement, manifest, or Xcode project changes are required. Existing App Lock notification redaction remains in place.

No spans, log events, breadcrumbs, or attributes are added. No telemetry receives user content. Authentication state and secure token storage remain unchanged.

## Risks / Trade-offs

Already dispatched platform calls cannot be recalled. A service without guarded delivery cannot recheck after its own asynchronous preparation. Native guard implementation and its tests belong to root integration.

## Verification

The focused notifier suite passes all 33 tests, including eleven activity regressions using held permission and preparation futures. Six initial tests first failed on stale delivery or work starting during suspension, while the two intent-preservation tests remained green. Three further listener-order regressions reproduced announcement and permission requests during pause and stale publication after reentrant resume before the live-value and epoch fix. The combined notifier, local notification service, chat notification, request notification, and policy suites pass all 194 tests. `dart format lib/src/notifications/attention_notifier.dart test/attention_notifier_test.dart`, focused `flutter analyze --no-pub`, and `openspec validate suspend-attention-announcements --strict` pass.

The shared verify-in-app isolation instructions were reviewed. No native fixture was launched. Native presentation, persistent device storage, and integrated UI behavior require separate evidence from an isolated client fixture. Root integration remains unfinished.
