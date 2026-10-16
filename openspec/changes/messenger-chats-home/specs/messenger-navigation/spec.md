## Purpose

Make conversations the starting point on compact phone layouts while preserving existing chat ownership, navigation guards, and desktop behavior.

## ADDED Requirements

### Requirement: Chats is the compact home

On compact iOS and Android layouts, the signed-in app SHALL initially present a full-page Chats list unless an explicit launch action targets another screen. The list SHALL provide search, New message, and a menu for available shell destinations. Existing profile scope, ordering, paging, housekeeping, loading, empty, and retry behavior SHALL remain available. Opening the list SHALL NOT send a message or mark an unseen conversation as read.

#### Scenario: Ordinary launch
- **WHEN** the user opens the signed-in app without an explicit target on a compact phone layout
- **THEN** Chats is visible with the current profile's conversations and no conversation detail covering the list

#### Scenario: Empty or failed list
- **WHEN** the profile has no conversations or its list cannot load
- **THEN** Chats shows the existing empty or error/retry state and retains New message and the shell menu

#### Scenario: Reach another destination
- **WHEN** the user opens the menu from Chats
- **THEN** available management, Kanban, and Schedules destinations remain reachable under existing capability gates

### Requirement: Conversation detail returns to Chats

Selecting a conversation or search result SHALL open its detail on compact phone layouts. The header Back action, iOS interactive Back, and Android system Back SHALL return to Chats after any overlying guarded route permits dismissal. Returning SHALL preserve the list's search and scroll position, draft content, selected conversation, queued prompts, and ongoing generation within the existing signed-in shell.

#### Scenario: Return during a reply
- **WHEN** the user returns from a conversation while its reply runs and then opens it again
- **THEN** Chats remains usable and the same conversation resumes without restarting or stopping its reply

#### Scenario: Return with a draft
- **WHEN** the user enters an unsent draft and returns to Chats
- **THEN** reopening that conversation restores the draft without sending it

#### Scenario: Protected editor above detail
- **WHEN** Back is invoked with a dirty editor above a conversation
- **THEN** the editor's existing dismissal guard runs before the app returns to Chats

### Requirement: New message is explicit

Chats SHALL offer New message, which opens a new-chat composer with a profile recipient picker and existing draft rules. The chosen recipient SHALL be local to the app window and SHALL NOT change server profile configuration or the server active profile. An existing conversation SHALL keep its owning profile. Opening or leaving that composer SHALL NOT send a message.

#### Scenario: Start composing
- **WHEN** the user selects New message
- **THEN** the app offers available profiles and opens the composer for the chosen profile without changing the server default or sending until an explicit send action

#### Scenario: Another recipient before first send
- **WHEN** the user chooses a different profile before sending the first message
- **THEN** models, starters, and microphone availability match that profile and an unsupported model selection is cleared

#### Scenario: Existing conversation owner
- **WHEN** the user opens an existing conversation after choosing a different recipient for new messages
- **THEN** history, sending, pending answers, and reconnect use the existing conversation's profile and never retarget it

### Requirement: Preserve adaptive desktop and tablet behavior

Wide layouts SHALL retain their existing conversation list beside detail and existing sidebar visibility controls. macOS SHALL retain its existing compact overlay rules. Resizing between compact phone-style and wide layouts SHALL preserve the selected conversation and unsent composer state without creating duplicate chat work.

#### Scenario: Resize while composing
- **WHEN** a selected conversation with an unsent draft moves from compact to wide layout and back
- **THEN** the same detail and draft remain available and the wide list selects that conversation

#### Scenario: Compact Mac window
- **WHEN** a macOS window becomes narrower than its docked-sidebar threshold
- **THEN** its existing sidebar overlay and keyboard controls remain available

### Requirement: Explicit targets override ordinary home

Accepted links, notification taps, shared-content actions, and explicit new-chat actions SHALL open their intended detail instead of stopping at Chats. Existing route guards, App Lock, capability checks, profile matching, and latest-intent ordering SHALL apply. Returning from a compact conversation target SHALL reveal Chats. Sign-out or a server/account change SHALL discard presentation state with the existing signed-in shell.

#### Scenario: Targeted launch
- **WHEN** a valid conversation link launches the compact app
- **THEN** the app opens that conversation after existing authentication and lock checks and Back returns to Chats

#### Scenario: Locked or guarded target
- **WHEN** an external target arrives while App Lock or a protected editor blocks navigation
- **THEN** the existing queue holds the target without changing the underlying detail until navigation is allowed

### Requirement: Existing backend compatibility

The feature SHALL reuse the existing profile-scoped GET /api/sessions contract, including the sessions rows and optional total, and existing message-loading and authenticated /api/ws contracts. It SHALL require no additional routes, RPC methods, response fields, or minimum Hermes Agent version beyond the current app's requirements.

#### Scenario: Existing server
- **WHEN** the connected server supports the app's current session and chat contracts
- **THEN** compact Chats and detail navigation work without an additional capability or server upgrade

### Requirement: Avatars identify messenger participants

The app SHALL show the owning profile's avatar in conversation rows, recipient-picker entries and the selected recipient chip, and chat headers on compact and wide layouts across all Flutter platforms. Where the connected server supports reading a configured profile image, the app SHALL display that image through the existing authenticated profile-asset contract. Missing, unsupported, invalid, or failed images SHALL use a deterministic monogram and color for that profile without blocking conversation access. The profile name SHALL remain visible or available as an accessible label; color and imagery SHALL NOT be the only identity cues.

Avatar display SHALL NOT write profile assets or metadata, change the active server profile, or contact a third-party avatar service. Avatar results SHALL be scoped to the current server, account, and profile. A result from a previous recipient or account SHALL NOT replace the current avatar. Configured image reads SHALL use `profiles.get_asset` with the canonical profile in `name` and `asset: avatar`; the existing response contains `found`, `mime`, `size`, and the image `data` URL. Unsupported reads and invalid image data SHALL fall back without fetching arbitrary external URLs. No new backend endpoint, response field, or minimum Hermes Agent version SHALL be required for monogram display.

Group conversation rows and headers SHALL use a distinct group avatar when the separately planned Groups integration ships. This change SHALL NOT add group protocol behavior solely for avatar support.

#### Scenario: Configured profile image
- **WHEN** a profile has an image available through the supported authenticated server asset contract
- **THEN** its conversation row, recipient controls, and chat header display that profile image without mutating the profile

#### Scenario: Missing or failed image
- **WHEN** an image is absent, unsupported, invalid, or cannot load
- **THEN** the app displays a consistent monogram fallback and conversation access remains usable

#### Scenario: Accessible identity
- **WHEN** a user reads a recipient or conversation through assistive technology
- **THEN** the profile's name identifies the participant without requiring recognition of the avatar or its color

#### Scenario: Recipient or account changes during image loading
- **WHEN** an earlier avatar request completes after a recipient, account, or server change
- **THEN** its image is not displayed for the new identity and account-scoped cached images are cleared on account/server replacement or sign-out

#### Scenario: Groups integration
- **WHEN** a group conversation appears in the later Groups list or header
- **THEN** it has a distinct group avatar instead of presenting one member as the owner of the whole group
