# Platform gestures, navigation, and presentation checklist

Created 2026-10-12. Scope: the gesture, navigation-stack, and macOS transition issues discussed in this chat. This backlog is being delivered through bounded OpenSpec changes and reviewed PRs. Checkboxes describe complete outcomes; partial coverage is recorded below.

## Findings and current status

| Area | Finding | Source |
| --- | --- | --- |
| Shared row actions | iOS gets swipe and long-press actions; macOS gets right-click. Other platforms receive the unmodified child. | `lib/src/widgets/row_actions.dart` |
| Thread actions | iOS uses swipe and long-press; macOS has a dedicated row; other platforms offer an inline menu with long-press and secondary tap. | `lib/src/chat/widgets/thread_sidebar.dart` |
| Kanban dragging | Wide-layout cards distinguish mouse/trackpad from touch/stylus. The generic narrow-layout path uses long-press selection and a drag handle. macOS has its own column layout. | `lib/src/kanban/widgets/kanban_card_drag.dart`, `lib/src/kanban/kanban_screen.dart`, `openspec/specs/kanban/spec.md` |
| Main destinations | An `IndexedStack` preserves mounted section state. Selection does not push a route or record section history. | `lib/src/shell/app_shell.dart` |
| External navigation | Deep links, notification taps, sharing, Show in Main Window, and scheduled-run chat handoffs use the guarded queue (#646, #653, #657, #680). Bot opening and menu/intent entry points still need audit. | `lib/src/shell/app_shell.dart` |
| Page transitions | The app uses `MaterialPageRoute`. The macOS theme specifies a short stationary fade; mobile builders retain the installed SDK defaults. Feature-specific dialogs and sheets still need their own policy. | `lib/src/app.dart`, `lib/src/theme/hermes_theme.dart` |
| Dialogs and sheets | Compact macOS Plugin details and MCP catalog installation details use desktop dialogs (#687, #697). Compact non-macOS layouts retain sheets, and wide layouts retain panes. Several Kanban and settings surfaces use `showDialog`; other feature modal APIs remain pending. | `lib/src/plugins/catalog_tab.dart`, `lib/src/plugins/installed_tab.dart`, `lib/src/mcp/mcp_catalog_screen.dart`, `lib/src/widgets/adaptive_sheet.dart` |

Device behavior and the exact transitions in the reported build still need verification. Missing section history or a nested navigator is a design choice, not automatically a defect. Existing specs deliberately preserve section state and specify sidebar/drawer navigation.

## 1. Confirm behavior and agree on conventions

- [ ] Reproduce the reported macOS transitions and record each trigger, destination, presentation type, and app build.
- [ ] Identify the Flutter SDK used by that build; inspect its transition defaults rather than relying on another installed SDK.
- [x] Inventory every route push, dialog, bottom sheet, popup, drawer, inspector, and tab view. Include main, conversation, and quick-panel windows. See [the source inventory](platform-navigation-inventory.md).
- [ ] Finish the interaction matrix, including keyboard focus and accessibility behavior on devices. Source gesture and pointer bindings are inventoried in [the source inventory](platform-navigation-inventory.md).
- [ ] Build an expected-behavior matrix for iOS/iPadOS, Android, macOS, Windows, and Linux, Treat the web Widgetbook catalog as a preview target; there is no supported web app target today.
- [ ] Include touch, stylus, mouse, trackpad, keyboard, and assistive technology in that matrix. Distinguish supported input from unsupported hardware capabilities.
- [x] Agree on macOS page motion and modal direction. User confirmed restrained desktop presentation with dialogs/popovers and no mobile bottom sheets. Inspector and reduced-motion verification remain open below.
- [x] Decide whether main destinations are peers without Back history or participate in history. User confirmed peer sections without Back history. Root Back and repeated selection remain to be verified below.
- [x] Decide whether each destination needs an independent detail stack. Keep the current shared detail stack; the confirmed peer-section behavior does not require nested navigators.
- [x] Decide whether desktop mouse Back/Forward buttons are supported. User requested desktop Forward history alongside guarded Back. Keep peer sections without history; detail-history design and implementation remain open. Trackpad navigation and scrolling conflicts still require matrix review.
- [ ] Confirm drawer edge gestures and iOS route-back gestures can coexist without ambiguous actions.
- [x] Reconcile this backlog with [the adaptive UI series](../openspec/adaptive-ui-series.md), so existing work is not duplicated. Its component migrations are complete; modal routes, input behavior, and device verification remain open.
- [ ] Before implementation, create bounded OpenSpec changes for the agreed behavior. Update affected requirements and validate each change.

Acceptance: every inventoried interaction has an expected result; unresolved decisions are explicit rather than silently becoming implementation requirements.

## 2. Protect unsaved work during external navigation

Priority: first behavior fix. Sources: `lib/src/shell/app_shell.dart`, `lib/src/widgets/route_dismissal.dart`, and existing `PopScope` users.

- [x] Add a failing regression test: a notification arriving over a dirty editor must not silently discard the draft.
- [x] Define whether an external request waits, prompts, or opens elsewhere while navigation is blocked. Preserve the request until it is handled or explicitly cancelled.
- [ ] Replace unconditional stack resets for ordinary external navigation with a flow that respects dismissal guards.
- [x] Cover notification taps, shared text/files/quotes, chat/new-chat/request deep links, Kanban links, schedule links, scheduled-run chat handoffs, and Show in Main Window.
- [ ] Audit every `PopScope`: skill editor, schedule form, MCP JSON editor/sign-in, bot saving, plugin installation, and platform-hint prompt.
- [ ] Preserve Save, Discard, and Stay behavior when several guarded routes are open. Stop unwinding when a route refuses dismissal.
- [ ] Handle save failures, busy operations, and a save completing while navigation is pending without popping the next route.
- [ ] Define ordering and deduplication when multiple requests arrive during confirmation or saving.
- [x] Keep external navigation pending while App Lock covers the app; revalidate targets after unlock.
- [ ] Revalidate server/profile, destination availability, and target existence before applying a delayed request.

PR #680 checks connection readiness, authorization, and owner generation. The full per-entry-point revalidation audit remains open.
- [ ] Audit explicit `pop`, `removeRoute`, and `dismissRoute` calls. Keep deliberate completion/removal distinct from user Back and external navigation.
- [x] Define the authentication policy: recover drafts after expiry only for the same verified account; clear old screens and drafts on explicit sign-out or server departure.
- [ ] Implement authentication teardown, same-account draft recovery, and pending-request handling under that policy.

Acceptance: guarded work cannot disappear silently because of an external navigation request; allowed navigation reaches its target once and leaves a valid stack.

## 3. Make stack ownership and Back behavior consistent

- [ ] Map root routes, section state, selected chat/task, dialogs, sheets, inspectors, and auxiliary windows to their navigation owner.
- [ ] Implement the section-history policy agreed in section 1; preserve existing lazy loading and mounted section state.
- [ ] If independent stacks are required, retain each stack on section switches and target the correct navigator for pushes, results, and modal dismissal.
- [ ] Define Back precedence for a modal, detail route, transient search/selection mode, sidebar overlay, drawer, and root destination.
- [ ] Use the same guarded Back behavior for toolbar buttons, macOS `⌘[`, Android system Back, and supported navigation gestures.
- [ ] Add desktop Forward history for eligible detail destinations, with dismissal guards, target revalidation, and history reset on explicit session departure. Keep peer-section selection outside history.
- [ ] Define which root interactions consume Back and which allow the platform to leave or close the view.
- [ ] Ensure only the visible route/window enables Back and other navigation commands; offstage sections must not capture them.
- [ ] Define repeated selection of the current destination, including whether it retains details or returns to the section root.
- [ ] Handle plugin/destination removal while its detail route is open without leaving orphaned screens or listeners.
- [ ] Handle profile switches, sign-out, server changes, and session expiry without retaining routes bound to obsolete repositories.
- [ ] Ensure deep links produce the agreed parent context and Back destination, whether received at startup or in a running app.
- [ ] Preserve route results and asynchronous completion during stack changes; extend `route_dismissal_test.dart` and `skill_editor_navigation_test.dart` where needed.
- [ ] Verify navigation in conversation windows and the quick panel does not mutate or dismiss the main window's stack.

Acceptance: every entry path has a defined Back result, and section/window changes preserve only the state intended by the policy.

## 4. Apply platform-appropriate page transitions

- [x] Add an explicit transition policy to the shared theme or route construction path, following the decision in section 1.
- [ ] Preserve iOS interactive edge-swipe Back and verify Android system/predictive Back against the SDK and app configuration actually shipped.
- [x] Apply the macOS policy to both light and dark themes and all app entry points, including auxiliary windows.
- [ ] Audit route pushes in Chat, Skills, Plugins, MCP, Kanban, Schedules, Profiles, Messaging, account/connection settings, attachment viewers, and group chat.
- [ ] Check full-screen attachment/media views separately; select presentation according to the task rather than applying one animation blindly.
- [ ] Respect reduced motion; avoid unexpected animation on destination switching and inspector opening.
- [ ] Verify forward, reverse, interrupted, and rapid repeated navigation. Prevent duplicate routes where repeated activation is unintended.
- [ ] Preserve route settings, return values, focus, semantics, and existing navigation observers when changing route construction.

Acceptance: no inventoried page uses accidental framework fallback motion; supported Back gestures still work.

## 5. Apply platform-appropriate modal presentation

- [x] Extend or replace `showAdaptiveSheet` so platform conventions and input matter alongside width. macOS dialogs apply at every width; keyboard traversal and activation are covered by widget tests. Native input verification remains open.
- [x] Separate adaptive dialog content from adaptive route animation through the shared dialog policy. Feature-specific callers still need migration and presentation review.
- [x] Migrate plugin catalog details and installed-plugin details to the agreed presentation.
- [x] Present MCP catalog installation details as a desktop dialog on compact macOS layouts; preserve mobile sheets and wide panes.
- [ ] Audit MCP configuration, sign-in, installed-server, and report dialogs for the agreed presentation.
- [ ] Audit Kanban board import/export, bulk actions, worker logs, task editing/pickers, create flows, and error dialogs.
- [ ] Preserve the existing macOS task inspector and iOS task detent/form-sheet behavior; do not replace them with generic dialogs.
- [ ] Audit Skills detail/job/status surfaces and the editor against the existing adaptive UI series.
- [ ] Audit model picker, attachment-source picker, notification settings, dictation, Spotlight, App Lock, Appearance, About, and account settings.
- [ ] Audit new-profile, bot deletion, group disbanding, thread rename, and other confirmation dialogs.
- [ ] Audit popup/context-menu animation independently from full-screen routes and dialogs.
- [ ] Give each modal an explicit dismissal policy for Escape, outside click/tap, close/cancel controls, swipe, system Back, and busy/dirty state.
- [ ] Restore focus to the invoking control when a modal closes. Preserve keyboard traversal and screen-reader labels.
- [ ] Recheck constraints, safe areas, scrollability, keyboard appearance, resizing, and minimum window sizes after migration.

Acceptance: macOS surfaces follow the agreed desktop presentation, mobile surfaces retain their expected behavior, and dismissal does not bypass work protection.

## 6. Make action gestures consistent across inputs

- [ ] Define shared row behavior for Android, Windows, and Linux instead of leaving the decision implicit in `RowActions`.
- [ ] Apply that behavior to profiles, schedules, installed plugins, MCP servers, and Kanban list rows.
- [ ] Keep actions discoverable through visible controls and keyboard/accessibility access; never require a gesture as the sole path.
- [ ] Retain iOS swipe and long-press actions and macOS right-click actions; ensure destructive actions use the intended confirmation.
- [ ] Audit thread rows across platforms and mixed-input iPads; ensure menu, swipe, double-click, and drag-out do not trigger each other.
- [ ] Test row buttons separately from their parent gesture areas so an action button does not open a row, drag, or unrelated menu.
- [ ] Audit Kanban gesture selection across actual platform/layout branches before changing width-dependent behavior.
- [ ] If the matrix requires it, allow immediate mouse/trackpad card dragging on compact layouts while retaining touch scrolling and long-press selection.
- [ ] Resolve touch/stylus long-press selection versus drag initiation explicitly; preserve drag-handle access and invalid-drop restrictions.
- [ ] Verify resizing or changing input devices does not lose selection, an active edit, or the open inspector.
- [ ] Audit attachments, Quick Look, drag-out, and text selection for gesture-arena conflicts. Keep native-only capabilities gated.
- [ ] Verify tab swiping, segmented-control interaction, drawer dragging, sidebar resizing, and scroll gestures do not conflict.
- [ ] Supply equivalent semantic actions and keyboard focus for every added context action.

Acceptance: each supported input follows the matrix without accidental navigation, lost scrolling, or inaccessible actions.

## 7. Verify and ship in bounded changes

- [ ] Extend existing behavioral tests in `app_shell_test.dart`, `test/deep_links/app_shell_deep_link_test.dart`, `route_dismissal_test.dart`, and `skill_editor_navigation_test.dart` for guarded navigation.
- [ ] Extend `hermes_theme_test.dart`, `adaptive_back_button_test.dart`, and adaptive dialog/tab tests for the agreed transition and Back policies.
- [ ] Extend row and drag tests, including `row_actions_test.dart`, `mac_thread_row_gestures_test.dart`, and attachment/Kanban drag tests, for changed input behavior.
- [ ] Test nested modal/detail dismissal, request ordering, target removal, profile changes, and async completion. Assert visible behavior and retained data rather than only widget types.
- [ ] Run device checks on macOS for the originally reported screens, keyboard navigation, right-click, trackpad scrolling, reduced motion, resizing, and auxiliary windows.
- [ ] Run iPhone/iPad checks for edge-back, drawers, sheets, keyboard visibility, touch/stylus, and connected mouse/trackpad where supported.
- [ ] Run Android checks for system/predictive Back, drawer gestures, guarded editors, and root behavior.
- [ ] Run Windows/Linux checks for supported menus, keyboard navigation, pointer actions, and mouse navigation buttons if adopted.
- [ ] Use isolated test accounts, data, and processes for app verification; record device/build coverage and any unverified targets.
- [ ] Run relevant formatting, analysis, tests, and OpenSpec validation for each implementation slice.
- [ ] Deliver separate reviewable changes for unsaved-work protection, stack semantics, page transitions, modal migrations, and gesture consistency. Split modal migrations by feature when needed.
- [ ] Update this checklist and the adaptive UI series as work lands; record deferred decisions and remaining gaps explicitly.

Completion: all agreed matrix entries are implemented and verified, existing behavior remains covered, and no confirmed issue from this discussion is left without a resolution or an explicit deferral.

## Delivery progress

- Merged: [PR #646](https://github.com/cedricziel/hermes-app/pull/646), `guard-external-navigation`. Protects dirty/busy routes during deep-link navigation, delays payload delivery, retains the latest link, rechecks App Lock and availability, and cancels on shell disposal. Skill and schedule editors also retain drafts and errors when an in-flight save fails. All CI test shards and Android/iOS/macOS/Linux builds passed. Later entry-point delivery is recorded below.
- Merged: [PR #653](https://github.com/cedricziel/hermes-app/pull/653), `guard-notification-navigation`. Warm/launch notifications wait behind dirty/busy routes and App Lock; newer navigation wins over late launch lookup. Confirmed-unavailable jobs are discarded. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived.
- Merged: [PR #657](https://github.com/cedricziel/hermes-app/pull/657), `guard-sharing-navigation`. Warm/launch sharing waits behind guarded editors and App Lock. Newer destinations retain the payload for the next explicit Chat entry. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived.
- Merged: [PR #659](https://github.com/cedricziel/hermes-app/pull/659), protected HTTP session lifetimes (`guard-session-api-clients`), the foundation for same-account draft recovery. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived. Navigator covering and draft restoration remain open.
- Merged: [PR #670](https://github.com/cedricziel/hermes-app/pull/670), verified ownership of auxiliary-window targets and restoration (`guard-window-session-ownership`), following native-host safety in [PR #672](https://github.com/cedricziel/hermes-app/pull/672). All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived. Restoring target metadata does not restore unsaved window drafts; main and auxiliary draft retention and native lifecycle verification remain open.
- Merged: [PR #654](https://github.com/cedricziel/hermes-app/pull/654), `restrained-macos-page-transitions`. macOS pages, including Material full-screen image viewers, use a 150 ms stationary fade and show content immediately under reduced motion. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived.
- Merged: [PR #674](https://github.com/cedricziel/hermes-app/pull/674), `restrained-macos-modal-presentation`. Shared confirmations, MCP command reviews, and platform-hint prompts use stationary 150 ms Mac dialogs with reduced-motion bypass; common Mac alert actions support guarded keyboard and pointer/accessibility activation. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived. Feature migrations and native verification remain open.
- Merged: [PR #676](https://github.com/cedricziel/hermes-app/pull/676), `restrained-macos-skill-job-presentation`. Mac job status uses content-sized dialogs with scrollable logs and a fixed dismissal control. Generated-client tests cover background execution and completed-job cleanup; other platforms retain sheets. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived. Native interaction and browser Phone-preview pointer dismissal remain unverified.
- Merged: [PR #677](https://github.com/cedricziel/hermes-app/pull/677), `guard-kanban-action-lifetime`. Late typed/generic failures do not show snackbars from disposed callers. The affected Quick Look tests await preview/controller completion before teardown. All CI test shards and Android/iOS/macOS/Linux builds passed. Main requirements are synced and the change is archived.
- Merged: [PR #679](https://github.com/cedricziel/hermes-app/pull/679), renewable chat transport. Suspension rejects new protected work, cancels streams, fences stale results, and supports explicit renewal. CI shards and Android, iOS, macOS, and Linux builds passed. Application wiring, route retention, editor drafts, auxiliary-window snapshots, and desktop history remain open.
- Merged: [PR #680](https://github.com/cedricziel/hermes-app/pull/680), guarded Show in Main Window and scheduled-run chat handoffs. The root queue retains the latest destination behind guarded routes and App Lock, then checks connection readiness, authorization, and owner generation before delivery. CI shards and Android, iOS, macOS, and Linux builds passed.
- Merged: [PR #683](https://github.com/cedricziel/hermes-app/pull/683), verified-owner activity lifetime; [PR #684](https://github.com/cedricziel/hermes-app/pull/684), scheduled-task alert suspension; [PR #685](https://github.com/cedricziel/hermes-app/pull/685), dictation suspension; [PR #690](https://github.com/cedricziel/hermes-app/pull/690), Kanban controller suspension; and [PR #692](https://github.com/cedricziel/hermes-app/pull/692), Chat controller suspension. These changes pause protected work in named consumers. CI shards and Android, iOS, macOS, and Linux builds passed. They do not retain authentication routes or restore main and auxiliary drafts.
- Merged: [PR #695](https://github.com/cedricziel/hermes-app/pull/695), AttentionNotifier suspension. It invalidates delayed announcements while activity is paused and continues handing notification taps and launch targets to the routing owner. Shared activity wiring and the guarded platform notification service remain integration work; screen and draft retention are out of scope.
- Merged: [PR #687](https://github.com/cedricziel/hermes-app/pull/687), compact macOS Plugin detail dialogs; and [PR #697](https://github.com/cedricziel/hermes-app/pull/697), compact macOS MCP catalog installation dialogs. Both preserve mobile sheets and wide panes. Native presentation, keyboard interaction, and accessibility remain unverified.
- Open: [PR #699](https://github.com/cedricziel/hermes-app/pull/699) adds guarded desktop history with Workers as the only Forward-eligible detail route. It is not merged and does not complete the broader Forward-history checklist.
- Native auth foundation verification: macOS connection/departure/reconnection against an isolated backend completed. Native client-storage isolation was not verified. Connection Details remained above setup after Change server until toolbar Back; this reproduces the open navigator teardown issue. Native gated login/expiry remains unverified; HTTP/controller journeys cover it.
- Authentication audit: pushed routes can remain above the replacement Login/Setup home screen. Cover old-session UI immediately during teardown. User confirmed draft recovery after expiry only for the same verified account; explicit sign-out and server changes clear old screens.
- Adaptive component reconciliation: Skills details/status, Kanban components, connection screens, and chat autocomplete are already migrated in the adaptive UI series. Compact macOS Plugin details (#687) and MCP catalog installation details (#697) now use desktop dialogs. Other feature modal routes remain open; source and widget coverage do not establish native device behavior.
- Native verification: macOS Skills/editor pushes and toolbar Back against an isolated backend completed. Native client-storage isolation was not verified. The automated keyboard `⌘[` action had no effect; keyboard Back parity remains open. Widget tests cover light/dark page motion, reduced motion, full-screen page routes, interrupted Back, metadata, and results.
- Source inventory complete: route pushes, modal APIs, platform branches, and pointer gestures. Device verification remains open.
- Confirmed sharing policy: newer notification/link navigation wins; waiting share content stays pending until the next explicit Chat entry.
- Confirmed decisions: keep Chat, Kanban, and Schedules as peer sections without Back history; retain the shared detail stack; use restrained macOS page motion and desktop dialogs/popovers. Preserve current iOS behavior and the macOS Kanban inspector. Update and validate the specs with each implementation slice.
- Delivery order: deep-link safety; other external navigation entry points; explicit transition policy; shared modal presentation; feature migrations; gesture/input consistency; device verification and final reconciliation.
