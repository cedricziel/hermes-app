## ADDED Requirements

### Requirement: Main chat handoffs respect protected screens

Show in Main Window and scheduled-run chat handoffs SHALL wait for pushed routes to authorize dismissal before changing the main chat target, profile, composer, or selected section. The root navigation queue SHALL retain the latest pending destination while an editor stays open or App Lock covers the app. A newer external destination SHALL supersede the waiting handoff without bypassing that guard.

#### Scenario: Show in Main Window arrives over a dirty editor
- **WHEN** an auxiliary window requests a main-window chat while a dirty editor is current
- **THEN** dismissal is guarded and neither the editor nor the current chat target changes until departure is authorized

#### Scenario: Scheduled run opens a chat over a dirty editor
- **WHEN** a scheduled-run callback requests Chat while a pushed editor refuses dismissal
- **THEN** the editor and current chat remain intact and the request stays pending until the editor closes

#### Scenario: Newer intent wins behind the guard
- **WHEN** a newer notification or link arrives while a handoff waits behind an editor
- **THEN** closing the editor delivers only the newer destination through the normal validated opening flow
