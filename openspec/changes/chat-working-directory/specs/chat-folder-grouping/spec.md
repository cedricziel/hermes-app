## ADDED Requirements

### Requirement: Folder labels agree with the chat header

A chat's folder section header SHALL use the same display label as the folder name the chat's header shows, disambiguated the same way when two paths share a basename. When a chat's working directory changes (`session.workspace.move`) the chat SHALL regroup under its new folder on the next list state without losing selection or changing the grouping choice.

#### Scenario: Same label

- **WHEN** a chat's repository root is `/home/me/code/demo` and the header shows `api` for its working directory
- **THEN** its section header reads `demo` and the header line reads `api`, and both show the full path "on your server" on request

#### Scenario: Moved chat regroups

- **WHEN** a chat is moved to `/home/me/code/other` while grouped by Folder
- **THEN** it leaves its old section, appears under `other`, and stays selected
