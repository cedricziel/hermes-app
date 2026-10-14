## ADDED Requirements

### Requirement: Main chat handoffs respect protected screens

Show in Main Window and scheduled-run chat handoffs SHALL wait for pushed routes to authorize dismissal before changing the main chat target, profile, composer, or selected section. The root navigation queue SHALL retain the latest pending destination while an editor stays open or App Lock covers the app. A newer external destination SHALL supersede the waiting handoff without bypassing that guard. Delivery SHALL also require a ready, authorized connection with the shell's captured owner generation unchanged; authentication notification timing or delayed credential cleanup SHALL NOT authorize a retired target.

#### Scenario: Show in Main Window arrives over a dirty editor
- **WHEN** an auxiliary window requests a main-window chat while a dirty editor is current
- **THEN** dismissal is guarded and neither the editor nor the current chat target changes until departure is authorized

#### Scenario: Scheduled run opens a chat over a dirty editor
- **WHEN** a scheduled-run callback requests Chat while a pushed editor refuses dismissal
- **THEN** the editor and current chat remain intact and the request stays pending until the editor closes

#### Scenario: Newer intent wins behind the guard
- **WHEN** a newer notification or link arrives while a handoff waits behind an editor
- **THEN** closing the editor delivers only the newer destination through the normal validated opening flow

#### Scenario: Authorization retires before credential cleanup finishes
- **WHEN** sign-out or server departure revokes protected access and advances the owner generation while the shell is still mounted
- **THEN** closing a guarded editor does not deliver the retired handoff or mutate the current chat

#### Scenario: A mounted shell resumes after a transient authorization pause
- **WHEN** protected access becomes available again for the unchanged owner generation while the shell remains mounted
- **THEN** the queued latest destination can resume through the dismissal guard; a changed generation cannot resume it
