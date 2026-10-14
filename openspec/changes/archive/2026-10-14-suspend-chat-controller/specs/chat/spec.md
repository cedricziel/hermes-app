## ADDED Requirements

### Requirement: Suspended chat activity

The system SHALL stop new protected chat loads, searches, commands, sends, retries, answers and sidebar mutations while main session activity is suspended. In-flight results and errors SHALL NOT alter retained chat state, restore a draft, start another request or post a notification after suspension, including after subsequent recovery. The current profile, selection and local chat state SHALL remain available for verified recovery.

#### Scenario: In-flight work completes during sign-in

- **WHEN** session activity suspends with a chat load, reply stream or command still pending
- **THEN** the late result or error leaves retained state and notifications unchanged
- **AND** streams and timers stop and attempts to send or navigate issue no protected request

#### Scenario: An earlier listener invokes protected work during pause

- **WHEN** an earlier activity listener invokes a send or sidebar mutation while the signal already contains false
- **THEN** the controller and its sidebar helpers reject the action before their own activity listener runs

#### Scenario: Activity resumes reentrantly during pause delivery

- **WHEN** an earlier listener resumes activity before the controller observes the intermediate false value
- **THEN** the delivered activity notifications still invalidate old commands, reply streams, timers, and queued continuations

#### Scenario: A state notification or callback suspends activity

- **WHEN** a state notification or external callback suspends activity during command publication, reply publication, sending, sidebar mutation, or an opening
- **THEN** that operation cannot continue with a protected request, expanded prompt, prefill, private announcement, or automatic opening even if activity resumes before the callback returns

#### Scenario: Undo publication suspends activity

- **WHEN** a listener suspends and resumes activity while retry or edit publishes its undo state
- **THEN** the retired operation does not dispatch an undo or restore a composer draft
- **AND** the original transcript remains available

### Requirement: Chat reconciliation after recovery

After verified same-account activity resumes, the system SHALL reload server-owned chat state and preserve the selected profile and thread when they remain valid. It SHALL NOT automatically resend a submitted or queued prompt.

#### Scenario: Recover the selected conversation

- **WHEN** activity resumes and the previously selected profile and thread still exist
- **THEN** the refreshed transcript is selected on that profile without another prompt submission

#### Scenario: Recover queues outside the first page

- **WHEN** activity resumes with queued prompts in conversations outside the first session page
- **THEN** every queue is remapped to its recovered conversation without submitting a prompt
- **AND** a missing or unreadable target retains its queued prompts in a paused, unbound local draft
- **AND** an explicit send from that draft creates a new session instead of submitting to the unavailable stored session ID

#### Scenario: The previous profile is no longer available

- **WHEN** recovery switches away from a profile that no longer exists
- **THEN** queued prompts from that profile remain in local drafts
- **AND** a session with the same ID on the replacement profile does not inherit those prompts

#### Scenario: A local reply lost its stream before a server binding

- **WHEN** activity resumes with queued prompts in an unbound local conversation whose old reply stream was suspended
- **THEN** the old pending reply no longer blocks explicit queue submission
- **AND** its local thread, settled messages, and queued prompts remain available without automatic submission
- **AND** explicit queue submission creates a new session

#### Scenario: A fresh local send begins during reconciliation

- **WHEN** an authorized explicit send begins after resume while reconciliation is still pending
- **THEN** reconciliation preserves that fresh send and its pending reply

#### Scenario: A local queue or conversation is created during reconciliation

- **WHEN** an authorized user creates a local conversation or queues a prompt while resumed reconciliation waits
- **THEN** publication preserves the latest local conversation, selection, and queued text
- **AND** no prompt is submitted automatically and no queue is rebound to another profile's stored session

### Requirement: Interrupted external opening recovery

The system SHALL retain the target, prompt, and fetch permission of an external opening interrupted by suspension. Recovery SHALL NOT automatically apply that opening or mutate its composer. The active session owner MAY take the interrupted metadata once and requeue it after dismissal and arbitration with newer intents. A newer explicit opening SHALL supersede the retained opening.

#### Scenario: Opening was held behind a session load

- **WHEN** suspension interrupts an external opening held behind a session load
- **THEN** recovery leaves its target and draft unapplied
- **AND** the active owner can take its target, prompt, and `fetchMissing` flag once
- **AND** an inactive attempt to take it leaves the metadata retained

#### Scenario: The interrupted HTTP request remains pending

- **WHEN** recovery completes before the HTTP request of an interrupted opening
- **THEN** a fresh request to create a new chat does not wait for the retired HTTP request

#### Scenario: Publishing a fetched target suspends activity

- **WHEN** a listener suspends and resumes activity while an external opening publishes its fetched thread
- **THEN** the retired opening does not select that target or fetch its messages
- **AND** its target, prompt, and fetch permission remain available for explicit owner recovery

### Requirement: Existing recovery backend contracts

Recovery SHALL use existing profile and session REST routes and existing chat RPC methods without changing backend compatibility.

#### Scenario: Backend compatibility

- **WHEN** suspended activity resumes
- **THEN** reconciliation uses existing profile and session REST routes with their existing `profiles`, `sessions` and `messages` response envelopes and existing chat RPC methods
- **AND** no endpoint, RPC or minimum supported Hermes version changes
