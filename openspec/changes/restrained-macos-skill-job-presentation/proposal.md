## Why

The Skills job status still opens a mobile bottom sheet on macOS, despite the agreed desktop presentation. Its already adapted content and background job behavior should remain intact while the route changes.

## What Changes

- Present Skills job progress/results in a restrained, centered macOS dialog at every window width, using the shared dialog policy.
- Keep the existing bottom sheet on other platforms and preserve running jobs when their status view closes.
- Show running, success, failure, and unknown outcomes in the catalog before caller wiring; cover dismissal, resizing/scrolling, and job completion with behavioral tests.

Non-goals: change job execution, server contracts, other feature modals, authentication recovery, or the adaptive Skills content series.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `skills`: platform-appropriate background-job status presentation while retaining existing progress, completion, and background execution behavior.

## Impact

The Skills job route and catalog examples, with existing job/controller tests extended as needed. Depends on the shared macOS dialog policy in PR #674. No backend route, RPC method, response shape, minimum Hermes version, dependency, native entitlement, manifest, or Xcode change.

Security/privacy impact: none; credentials, storage, and telemetry remain unchanged. Closing status does not cancel or confirm backend work.

Observability: none. This local presentation change uses the existing job lifecycle signals and adds no span, event, breadcrumb, or user-content attribute.
