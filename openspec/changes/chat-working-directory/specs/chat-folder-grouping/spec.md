## ADDED Requirements

### Requirement: Folder labels share one rule with the chat header

A chat's folder section header and the folder name in the chat's header SHALL both be made by the same label rule (last path segment, disambiguated alike), each applied to its own path. After `session.workspace.move` the chat's folder SHALL be the answer's `git_repo_root`, else its `cwd`, and the chat SHALL regroup with selection and grouping kept.

#### Scenario: Same rule, own path

- **WHEN** a chat's repository root is `/home/me/code/demo` and its working directory is `/home/me/code/demo/api`
- **THEN** its section header reads `demo` and the chat header reads `api`, each made by the same rule

#### Scenario: Moved chat regroups

- **WHEN** a chat is moved to `/home/me/code/other` while grouped by Folder
- **THEN** it leaves its old section, appears under `other`, and stays selected

#### Scenario: Moved to a folder outside git

- **WHEN** the move answer has `git_repo_root: null` and `cwd: "/srv/notes"`
- **THEN** the chat is grouped under `notes`
