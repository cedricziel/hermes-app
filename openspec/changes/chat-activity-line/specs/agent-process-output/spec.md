# Spec Delta

## MODIFIED Requirements

### Requirement: Expanded output preserves the conversation viewport

Process output SHALL be listed in the Activity panel's Now section, not above the transcript. Expanded process output SHALL use a bounded scrolling text viewport inside the panel. The transcript and composer SHALL keep their space whatever the number or size of process outputs. Omission labels SHALL remain available below the output tail and below an evicted-process group.

#### Scenario: A long process tail is expanded

- **WHEN** the user opens process details containing a long output tail
- **THEN** the output scrolls within its bounded area in the Activity panel and the transcript remains usable
