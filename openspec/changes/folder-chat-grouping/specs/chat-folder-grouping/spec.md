## Purpose

Let users browse chats by recent activity or server-reported folders through compact controls and collapsible section headers.

## ADDED Requirements

### Requirement: Compact grouping control
The system SHALL offer Recent and Folder in a compact Group by menu on the first section header, aligned with Pinned, a date, or a folder. An empty list SHALL retain the menu beside a Chats heading. Removing the first section SHALL move the single menu to the next section. Apple devices SHALL use adaptive native menus without a dedicated switch row. Changing grouping SHALL preserve the selected chat and SHALL NOT change its working directory. iOS and macOS SHALL show recency section headers in Recent mode.

#### Scenario: Switch to folders
- **WHEN** the user selects Folder
- **THEN** the same loaded chats appear under folder section headers and the selected conversation stays open

#### Scenario: Menu and disclosure remain separate
- **WHEN** the user opens the grouping menu on a collapsed section
- **THEN** that section stays collapsed until its header is tapped

### Requirement: Folder sections
The system SHALL derive a folder from each session's nonblank git_repo_root, falling back to cwd, from the existing GET /api/sessions response. Older servers without these optional fields SHALL remain usable through No folder. Paths SHALL remain remote server paths and SHALL NOT be resolved on the device. Pinned chats SHALL appear once in Pinned. Unpinned chats SHALL appear once in their folder or No folder. Distinct paths with the same basename SHALL have distinct, disambiguated headers. Counts SHALL describe loaded unpinned chats, and paging SHALL remain available.

#### Scenario: Repository metadata
- **WHEN** two chats have the same repository root and different working directories
- **THEN** both appear in one folder section

#### Scenario: Missing metadata
- **WHEN** a session lacks valid folder metadata
- **THEN** it appears under No folder

#### Scenario: Folder disclosure
- **WHEN** the user taps a folder header
- **THEN** its chats collapse or expand without navigating away and its count stays visible

### Requirement: Device preferences
The system SHALL remember grouping and collapsed folder sections locally per platform. A late preference read SHALL NOT override a newer user selection. Preference storage failure SHALL NOT prevent browsing chats. Search SHALL continue to show search results rather than folder sections.

#### Scenario: Return to the list
- **WHEN** the user reopens the list or restarts the app
- **THEN** grouping and collapsed folder sections are restored
