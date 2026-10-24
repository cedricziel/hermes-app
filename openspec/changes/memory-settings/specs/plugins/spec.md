## MODIFIED Requirements

### Requirement: Plugins screen has Installed, Catalog and Providers tabs

The system SHALL show the Plugins screen with three tabs, Installed, Catalog and Providers, in that order, Installed selected when the screen opens, except when it is opened from the Memory screen's provider row, which selects Providers. Each tab SHALL keep its own state (list, search text, open details, unsaved choices) while the user switches between them. The catalog SHALL NOT be requested until the Catalog tab has been opened for the first time, and the provider settings SHALL NOT be requested until the Providers tab has been opened for the first time.

#### Scenario: Opens on Installed

- **WHEN** the Plugins screen opens
- **THEN** the Installed tab is selected and no catalog request and no provider request has been made

#### Scenario: Opened from Memory

- **WHEN** the user opens the Plugins screen from the Memory screen's provider row
- **THEN** the Providers tab is selected, the provider settings are requested and the catalog is not

#### Scenario: Catalog opened

- **WHEN** the user selects the Catalog tab for the first time
- **THEN** the catalog is requested

#### Scenario: Providers opened

- **WHEN** the user selects the Providers tab for the first time
- **THEN** the provider settings are requested

#### Scenario: Tabs keep their state

- **WHEN** the user types a search in the Catalog tab, selects Installed, and selects Catalog again
- **THEN** the search text and the list are still there and the catalog is not requested again
