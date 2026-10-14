# navigation Specification

## Purpose

Keep navigation to linked app content safe while an editor or busy operation protects the current screen.
## Requirements
### Requirement: Deep links respect route dismissal guards

The system SHALL dismiss routes above the signed-in shell using their existing Back behavior before applying a deep link. It SHALL NOT change the destination, selected chat, profile, composer, or dictation because of that link until those routes have closed. If a route refuses dismissal, the latest link SHALL remain pending until the route closes. A newer link SHALL replace an older pending link without opening another discard confirmation.

#### Scenario: Keep editing
- **WHEN** a deep link arrives over a dirty editor and the user chooses Keep editing
- **THEN** the editor and its draft remain intact and the link stays pending
- **AND** the underlying destination and chat are unchanged

#### Scenario: Discard and continue
- **WHEN** the user allows the guarded editor to close
- **THEN** the app dismisses any remaining routes through their Back behavior and applies the latest pending link once

#### Scenario: Save after keeping the editor open
- **WHEN** the user saves the editor successfully after choosing Keep editing
- **THEN** the editor closes and the latest pending link is applied

#### Scenario: Save fails while a link waits
- **WHEN** a deep link arrives while an editor save is running and that save fails
- **THEN** the editor retains the draft and error, and the link stays pending until the editor closes

#### Scenario: Busy operation
- **WHEN** a route blocks Back while an operation runs
- **THEN** the link remains pending without forcing the route closed

### Requirement: Delayed links revalidate navigation conditions

Before delivering a delayed link, the system SHALL recheck App Lock and the destination's availability. A link SHALL remain held while App Lock covers the app. A destination no longer offered SHALL be ignored. Disposing the signed-in shell SHALL cancel its queued navigation work. Existing link target validation and backend routes/RPC methods SHALL remain unchanged; this feature SHALL require no additional Hermes version or API contract.

#### Scenario: Lock covers the app while editing
- **WHEN** the app becomes locked before the guarded route closes
- **THEN** the link starts no chat work or dictation until unlock

#### Scenario: Destination disappears
- **WHEN** a pending Kanban or Schedules link becomes unavailable before delivery
- **THEN** it is ignored without selecting that destination

#### Scenario: Shell is disposed
- **WHEN** authentication teardown disposes the shell while a link waits
- **THEN** its pending action is never delivered to a replacement shell

### Requirement: Notifications respect protected screens

The system SHALL keep a notification's target unapplied until routes above the signed-in shell allow dismissal. This SHALL cover session taps, unsent-question prompts, scheduled-job notifications, and initial launch notifications. A protected editor SHALL retain its draft and error if saving fails. Keeping the editor open SHALL retain the latest target without repeatedly prompting; successful save or explicit dismissal SHALL release it once.

#### Scenario: Tap while editing
- **WHEN** a notification arrives while a dirty editor is open
- **THEN** the existing discard confirmation is used and the underlying chat/destination remains unchanged until dismissal

#### Scenario: Save fails
- **WHEN** a notification waits behind an editor whose save fails
- **THEN** the editor retains its draft and error, and the target remains pending

#### Scenario: Unsent question
- **WHEN** a notification carrying an unsent question arrives over a protected screen
- **THEN** no new chat or draft is created until that screen allows dismissal

#### Scenario: Scheduled job
- **WHEN** a job notification arrives over a protected screen
- **THEN** Schedules and the job detail are not opened before dismissal

### Requirement: Notification ordering preserves the latest intent

The system SHALL deliver only the latest pending external navigation request after a guard closes. An older launch notification resolving after a warm tap SHALL NOT supersede that tap. A newer notification or link SHALL invalidate older navigation requests held for destination discovery.

#### Scenario: Several taps while editing
- **WHEN** two notification targets arrive while the editor remains open
- **THEN** closing the editor delivers only the later target

#### Scenario: Delayed launch notification
- **WHEN** a warm tap arrives before an older launch lookup completes
- **THEN** the warm target is retained and the launch target does not change selection

#### Scenario: Availability-held request is superseded
- **WHEN** a newer notification or link arrives while an older request waits for destination discovery
- **THEN** later discovery does not deliver the older request

### Requirement: Notification delivery rechecks navigation conditions

The system SHALL hold notification delivery while App Lock covers the app, including during launch, and resume after unlock. It SHALL cancel queued work when the signed-in shell is disposed. Schedule targets SHALL wait while availability is unknown and SHALL be ignored when Schedules is known to be unavailable. Ordinary session notifications SHALL retain existing profile matching and SHALL NOT fetch sessions absent from the loaded list.

The backend contract SHALL remain the existing chat and scheduled-task contracts, including GET /api/sessions, GET /api/sessions/{id}/messages, and GET /api/cron/jobs/{id} with existing profile scoping and response shapes. No additional RPC, response shape, or minimum Hermes version SHALL be required.

#### Scenario: App Lock
- **WHEN** a notification arrives while locked or the app locks before delivery
- **THEN** it changes no chat/profile/draft until unlock

#### Scenario: Unavailable schedules
- **WHEN** availability is confirmed false before a queued job target is delivered
- **THEN** the app ignores it without selecting Schedules

#### Scenario: Shell disposal
- **WHEN** the signed-in shell is disposed before delivery
- **THEN** its queued notification work is cancelled

#### Scenario: Missing session
- **WHEN** an accepted ordinary session notification names a chat outside the loaded list or another profile
- **THEN** the existing failure behavior is preserved without fetching that session

### Requirement: Restrained macOS page motion

macOS page navigation, including full-screen image-viewer pages, SHALL use a short opacity transition without translating or scaling the page in either direction. The policy SHALL apply to light and dark themes in the main app and auxiliary app windows that present pages. Page navigation SHALL preserve route results, route metadata, and dismissal guards.

#### Scenario: Push and Back
- **WHEN** a macOS page is pushed or dismissed
- **THEN** its content stays in place while fading between visible and hidden states

#### Scenario: Full-screen image viewer
- **WHEN** a macOS image viewer opens as a full-screen page
- **THEN** it uses the same stationary opacity transition instead of a mobile vertical entrance

#### Scenario: Reduced motion
- **WHEN** macOS requests reduced motion
- **THEN** page content appears without an opacity, translation, or scale animation

#### Scenario: Theme and window parity
- **WHEN** a page is opened in a main or auxiliary window using either theme mode
- **THEN** it follows the same macOS page-motion policy

#### Scenario: Completion
- **WHEN** a page returns a value or a transition is interrupted by Back
- **THEN** its caller receives the normal route result and navigation remains valid

### Requirement: Preserve mobile page Back behavior

The macOS motion policy SHALL preserve existing iOS interactive edge Back and Android predictive/system Back behavior. It SHALL not change backend routes, RPC methods, response shapes, or the required Hermes Agent version.

#### Scenario: iOS navigation
- **WHEN** an iOS page uses an interactive edge Back gesture
- **THEN** existing platform page navigation remains available

#### Scenario: Android navigation
- **WHEN** Android performs predictive or system Back
- **THEN** existing platform page navigation remains available

### Requirement: Shared content respects protected screens

Shared text, files, and selected-text quotes SHALL remain pending until routes above the shell allow dismissal and App Lock allows navigation. Receiving content SHALL NOT modify the selected chat, composer, or attachments before that boundary. Keeping an editor open or failing a save SHALL retain both the editor draft and the shared content. Delivery SHALL send no message automatically.

#### Scenario: Share while editing
- **WHEN** text or files arrive while a dirty editor is open
- **THEN** the existing discard confirmation is used and the share remains unapplied until dismissal

#### Scenario: Locked delivery
- **WHEN** shared content arrives while App Lock covers the app
- **THEN** the content stays pending until unlock and is delivered once

#### Scenario: Held launch share
- **WHEN** shared content is waiting when the shell starts
- **THEN** it uses the same guarded delivery boundary

### Requirement: Navigation replacement retains shared payloads

Waiting text and files SHALL accumulate independently of the latest navigation request. Only the latest waiting selected-text quote SHALL be retained, matching existing share behavior. A newer notification or link SHALL win navigation and SHALL leave shared payloads pending for the next explicit Chat section entry, including repeated selection of Chat. Disposing the shell SHALL cancel its callback without consuming pending content.

The backend contract SHALL remain existing chat/session/attachment behavior, with no new REST routes, RPC methods, response shapes, or minimum Hermes Agent version. Existing pending-quote sign-out cleanup SHALL remain intact.

#### Scenario: Several shares
- **WHEN** several text/file shares and quotes arrive while navigation waits
- **THEN** accepted delivery includes every text/file and only the latest quote once

#### Scenario: Newer navigation wins
- **WHEN** a newer notification or link replaces waiting share navigation
- **THEN** its destination opens and shared content remains pending until an explicit Chat entry

#### Scenario: Deferred Chat recovery
- **WHEN** a newer external request arrives after Chat selection but before share recovery runs
- **THEN** recovery does not override that request and the share remains pending

#### Scenario: Delayed initial lookup
- **WHEN** launch-inbox content arrives after newer navigation or a newer waiting quote
- **THEN** it does not replace that navigation or quote, and its remaining text/files stay retained

#### Scenario: Shell disposal
- **WHEN** the shell is disposed before share delivery
- **THEN** its callback does not mutate chat and untaken content remains pending

### Requirement: Shared macOS modals use restrained desktop presentation

Shared confirmation dialogs, command-server execution reviews, and optional platform-hint prompts SHALL use desktop dialog presentation on macOS, including compact windows. Dialog content SHALL use a stationary 150 ms fade without slide or scale motion and SHALL appear immediately under reduced motion. Caller themes, confirmation results, and busy dismissal guards SHALL remain intact. Existing non-macOS presentation choices SHALL remain unchanged.

These presentation changes SHALL require no backend route, RPC method, response shape, or minimum Hermes Agent version change. Existing confirmation callbacks SHALL retain their backend contracts.

#### Scenario: Compact Mac window
- **WHEN** a command-server review or platform-hint prompt opens in a compact Mac window
- **THEN** it appears as a desktop dialog rather than a mobile bottom sheet

#### Scenario: Dialog motion
- **WHEN** a shared Mac modal opens or closes
- **THEN** its content remains stationary and changes opacity over 150 ms

#### Scenario: Reduced motion
- **WHEN** reduced motion is enabled
- **THEN** shared Mac dialog content appears immediately without slide or scale motion

#### Scenario: Confirmation cancellation
- **WHEN** a cancellable shared Mac confirmation receives Escape or barrier dismissal
- **THEN** it returns false without invoking the confirmed operation

#### Scenario: Busy prompt
- **WHEN** a shared Mac prompt refuses dismissal while saving
- **THEN** Escape, Back, and barrier interaction leave it open

### Requirement: Common macOS alert actions support keyboard navigation

Enabled common macOS alert actions SHALL be keyboard focusable and activatable with Enter or Space, with visible focus feedback. Disabled actions SHALL not activate or receive traversal focus. Focus SHALL remain within the modal, and an action from a dismissed or superseded dialog SHALL not pop an underlying route.

#### Scenario: Keyboard confirmation
- **WHEN** the user moves focus to an enabled common Mac alert action and presses Enter or Space
- **THEN** that action runs once

#### Scenario: Disabled action
- **WHEN** a common Mac alert action is disabled
- **THEN** keyboard traversal skips it and activation cannot invoke it

#### Scenario: Dismissed action
- **WHEN** a dialog starts closing before another activation arrives
- **THEN** its old action does not dismiss the underlying screen

### Requirement: Guarded desktop detail history

Desktop Back SHALL use the current route's dismissal guard. A successful Back from an explicitly eligible workers page SHALL make that page available to Forward. Rejected Back SHALL retain the route and history. Editors, completed actions, transient dialogs, removals, replacements, and external navigation unwinds SHALL NOT become Forward targets. Forward SHALL be disabled while a transient modal covers the main route. The history SHALL retain at most 32 targets.

#### Scenario: Workers round trip
- **WHEN** the user opens workers for a board, goes Back, then Forward
- **THEN** the app opens a new workers page for that board after confirming the plugin and board are available
- **AND** reconstruction performs reads and never stops a worker

#### Scenario: Guard rejects Back
- **WHEN** the current page refuses Back
- **THEN** its route and Forward history remain intact

#### Scenario: Branch changes
- **WHEN** a new page or a different Chat, Kanban, or Schedules section is selected after Back
- **THEN** the old Forward branch is cleared and section selection adds no history

#### Scenario: External navigation commits
- **WHEN** a guarded external request unwinds pages and commits its newest target
- **THEN** the unwind creates no Forward entries and the old Forward branch is cleared

### Requirement: Desktop history availability and input

macOS SHALL offer View > Forward with Cmd+] alongside guarded Back. Desktop mouse Back/Forward buttons SHALL use the same actions. Ordinary pointer scrolling and trackpad scrolling SHALL remain scrolling. A key auxiliary conversation window or native windowless state SHALL disable main-window history commands. A focus transition SHALL cancel pending Forward resolution even if the main window becomes key again before validation completes. Auth, lock, and Handoff overlays SHALL block history commands. Explicit session departure or changed verified owner SHALL clear history; expiry for the same verified owner SHALL pause it.

#### Scenario: Covered session
- **WHEN** App Lock, login, or a Handoff gate covers the main app
- **THEN** neither history command changes the main route

#### Scenario: Cancel external navigation
- **WHEN** an external request waiting behind a protected eligible page is cancelled
- **THEN** history suppression ends even while a framework dismissal guard remains pending, later user Back can record Forward, and the cancelled request never commits. Cancellation SHALL NOT promise to undo dismissal effects already requested from the navigation framework

#### Scenario: Focus changes during validation
- **WHEN** the user moves focus to an auxiliary window while Forward validates its target
- **THEN** validation completion does not push a main-window page, even after focus returns

#### Scenario: Scroll
- **WHEN** a pointer emits a horizontal or vertical scroll event
- **THEN** history does not navigate

#### Scenario: Missing target
- **WHEN** Forward finds the Kanban plugin unavailable or the board deleted
- **THEN** the stale target is dropped and the current route stays intact

The backend contract remains GET /api/dashboard/plugins (enabled plugin list), GET /api/plugins/kanban/boards (`boards` rows with `slug`), and GET /api/plugins/kanban/workers/active (`workers` rows). No new routes, response shapes, RPC methods, or minimum Hermes version are required.
