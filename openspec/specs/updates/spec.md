# Updates Specification

## Purpose

Describes how the app tells the user that a newer version has been released. It is built on the `upgrader` package: the App Store and Google Play lookups it ships with, plus a custom store, `GithubReleaseStore`, for platforms without a store.

## Requirements

### Requirement: Update check

The system SHALL look up the latest published version when the signed-in shell opens and each time the app returns to the foreground. On GitHub the latest non-draft, non-prerelease release counts, and a tag `vX.Y.Z` is version `X.Y.Z`. The check SHALL NOT use the Hermes server connection or its credentials.

#### Scenario: Newer release exists

- **WHEN** the latest release is newer than the installed version
- **THEN** a dialog offers to update, to be reminded later, or to ignore that version

#### Scenario: App is current

- **WHEN** the latest release equals or is older than the installed version
- **THEN** no dialog is shown

#### Scenario: Lookup fails

- **WHEN** the request fails, is rate limited, or returns something that is not a release
- **THEN** no dialog is shown and no error is surfaced

### Requirement: Source per platform

The system SHALL ask the App Store on iOS and macOS and Google Play on Android for the listed version, so a version still in review is never offered. Before the app is listed, that lookup finds nothing and no dialog is shown. On Linux and Windows, which have no store, the system SHALL use the latest GitHub release. "Update Now" SHALL open the store listing, or the GitHub release page on Linux and Windows. The dialog SHALL NOT show release notes.

#### Scenario: Update on Linux

- **WHEN** the user taps "Update Now" on Linux
- **THEN** the release page opens in the browser

#### Scenario: Version in review

- **WHEN** GitHub has a release that the App Store has not published yet
- **THEN** an iOS or macOS user is not prompted

### Requirement: Reminders

"Later" SHALL suppress the dialog for three days unless a newer release appears. "Ignore" SHALL suppress it for that version. Both choices SHALL survive a restart.

#### Scenario: Ignored version

- **WHEN** the user ignored version 0.2.0 and the latest release is still 0.2.0
- **THEN** no dialog is shown
