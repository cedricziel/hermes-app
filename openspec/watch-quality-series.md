# Watch quality series

This series covers the watch review's privacy, reliability, UX, and feature recommendations. Implementation ships in dependency-ordered PRs, with independent reviews before merging.

All 13 behavior changes have implementation and regression coverage. On 2026-10-13 the user excluded watch simulators
because earlier simulator work disrupted the host. Verification for this series
uses portable tests, static analysis, and compilation without launching a
simulator. Native visual and lifecycle checks remain unverified. This changes
the verification method, not the specified product behavior.

## Product decisions

- Cover every recommendation in staged changes.
- Review voice transcripts by default, with an optional fast-send setting.
- Interrupted recordings and recordings stopped by the duration limit always require review.
- After uncertain delivery, check for the original result and require an explicit resend. Never automatically resend a command that may have been accepted.
- Offer built-in starters without custom favorites or a favorites editor.

## Implementation order

The native verification fixture supports acceptance checks throughout the series. Privacy and identity provide the session boundaries used by durable send recovery and richer watch payloads.

| Stage | Change | Scope |
| --- | --- | --- |
| Foundation | [Native verification](changes/watch-native-verification/proposal.md) | Isolated watch and phone fixture, native callback tests, lifecycle and accessibility evidence |
| Foundation | [Session privacy](changes/watch-session-privacy/proposal.md) | Authenticate remembered replies and clear visible, cached, and pending private state |
| Foundation | [Context identity](changes/watch-context-identity/proposal.md) | Bind watch requests and caches to the current server and account |
| Reliability | [Send-attempt isolation](changes/watch-send-attempt-isolation/proposal.md) | Ignore late results after leaving a wait or starting another attempt |
| Reliability | [Send journal](changes/watch-send-journal/proposal.md) | Persist dispatch evidence and exact completed results; reject unsafe replay and bound storage |
| Reliability | [Send recovery](changes/watch-send-recovery/proposal.md) | Restore pending identities, check results, and require explicit confirmation for a new attempt |
| Voice | [Voice review](changes/watch-voice-review/proposal.md) | Review, edit, or discard transcription; optional manual fast-send; interruption and duration-limit recovery |
| Conversation | [Conversation usability](changes/watch-conversation-usability/proposal.md) | Preserve reading position and show failed outgoing messages with safe recovery actions |
| Requests | [Request guidance](changes/watch-request-guidance/proposal.md) | Explain notification and iPhone answer paths and make local waiting controls accurate |
| Requests | [Inline approvals](changes/watch-inline-approvals/proposal.md) | Show the complete approval and offered choices through the phone's existing security gates |
| Requests | [Inline questions](changes/watch-inline-questions/proposal.md) | Answer supported structured questions without sending ordinary chat prompts |
| Glanceability | [Glanceable chats](changes/watch-glanceable-chats/proposal.md) | Profile context, known request status, watch-local update markers, and cache freshness |
| Actions | [Contextual actions](changes/watch-contextual-actions/proposal.md) | Editable built-in starters, relevant follow-ups, and exact structured request actions |

Apply privacy before context identity, then the phone send journal before watch recovery. Send-attempt isolation can ship independently before recovery. Conversation usability consumes recovery; request guidance follows usability; inline approvals and then inline questions build on that foundation. Voice review requires privacy and attempt isolation. Glanceable chats require identity isolation and reliable pending-turn correlation. Contextual actions follow voice review, usability, and the inline request views. Native verification supplies the isolated fixture for acceptance checks throughout.

## Recommendation coverage

| Review recommendation | Planning owner |
| --- | --- |
| Remove private data after sign-out and authorize remembered replies | Session privacy |
| Bind chats to server and account | Context identity |
| Prevent stale replies after leaving a wait | Send-attempt isolation |
| Preserve send identity and avoid duplicate commands after restart | Send journal and send recovery |
| Recover the original result rather than a different assistant answer | Send journal |
| Review voice transcription and interrupted recordings | Voice review |
| Make approval and question waiting actionable | Request guidance, inline approvals, and inline questions |
| Preserve reading position and improve failed-send recovery | Conversation usability |
| Show profile, known status, update markers, and saved-data freshness | Glanceable chats |
| Replace generic reply chips with relevant built-in actions | Contextual actions |
| Verify native lifecycle, transport, and accessibility | Native verification and each feature's acceptance tasks |

## Existing spec baseline

The main watch spec predates several implemented, unarchived changes. In particular, `watch-handoff`, `watch-quick-replies`, `watch-complications`, and `actionable-request-notifications` describe behavior that the new changes must preserve or explicitly replace. Resolve those deltas before archiving this series. Do not treat the main spec's older approval termination behavior as the current implementation.

## Validation

Validate each change with `openspec validate <change-name> --strict`. The review ran 106 Swift core tests successfully using Xcode's bundled Swift toolchain. That result covers the existing core implementation, not the proposed behavior or native watch lifecycle.

All 13 changes pass strict validation and have their required planning artifacts complete. Each product change contains a proposal, design, delta spec, and task list. Native verification contains a proposal, design, and task list; its schema explicitly skips product specs because it adds verification tooling without changing product behavior.

Mark implementation tasks complete only when their specified source behavior and regression coverage are present. Keep verification tasks open until their prescribed checks have recorded evidence. Native UI previews supplement the Flutter catalog where the watch uses SwiftUI. An unavailable paired-device check is a coverage gap, not a pass.

## Shipping checkpoints

Nine foundation and identity PRs merged after independent reviews and cloud CI:
[verification #682](https://github.com/cedricziel/hermes-app/pull/682),
[attempt isolation #686](https://github.com/cedricziel/hermes-app/pull/686),
[context foundations #689](https://github.com/cedricziel/hermes-app/pull/689),
[journal library #691](https://github.com/cedricziel/hermes-app/pull/691),
[prompt receipt #693](https://github.com/cedricziel/hermes-app/pull/693),
[protected outbox #694](https://github.com/cedricziel/hermes-app/pull/694),
[phone privacy #696](https://github.com/cedricziel/hermes-app/pull/696),
[watch cleanup #698](https://github.com/cedricziel/hermes-app/pull/698), and
[identity runtime #706](https://github.com/cedricziel/hermes-app/pull/706).

The implementation PR map is independently reviewed and registered in GitHub
stack #719. Recovery #707, voice #708, conversation #709, guidance #710,
diagnostics #711, native request models #712, phone helper #713, inline activation
#714, freshness storage #715, read markers #716, glance UI #717, and contextual
actions #718 provide the remaining layers. Each revision must pass cloud CI before merging.

The exact identity compatibility checkpoint passed 105 phone-intent and background
notification tests plus two strict watch-context tests. The combined final phone
slice passed 109 focused headless tests, including inline eligibility, exact
accepted-answer recovery, journal recovery, glance metadata, complications, and
bridge behavior. The protected context library passed eight focused tests and
the journal library passed eighteen. These checkpoints do not establish native
layout or physical delivery behavior.

The final complete phone/watch headless suite passed 339 tests with two workers.
Formatting changed no files, and Flutter analysis found no issues. All 13 watch
changes pass strict OpenSpec validation. Implementation checkboxes
identify source and authored regression coverage. Combined native acceptance tasks
remain open. Local native builds and watch simulators are excluded by the user's
host-load constraint. Native visual, VoiceOver, gesture, microphone, and paired
lifecycle acceptance remains unverified; native RunnerTests execution also remains
unverified. Cloud core tests and platform compilation do not substitute for that
evidence.
