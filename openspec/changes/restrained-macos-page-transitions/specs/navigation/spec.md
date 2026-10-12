## ADDED Requirements

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
