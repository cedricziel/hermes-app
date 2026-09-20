The design gave a five-step delivery plan and no task list; these tasks follow that plan. Steps 1 to 4 shipped. Step 5 has open PRs, so it is not marked done.

## 1. Detection and navigation shell (#64)

- [x] 1.1 `HermesPluginsRepository`: `GET /api/dashboard/plugins`, on when an entry is named `kanban`, any failure reads as off
- [x] 1.2 `AppShell` with a bottom bar (phone) or rail (wide) for Chat and Kanban, only while the plugin is on; the chat keeps its state when the tab appears
- [x] 1.3 Re-check on connect and on app resume
- [x] 1.4 Tests: plugin off, phone, wide, turned off on resume

## 2. Board and live events (#65)

- [x] 2.1 Load `/api/plugins/kanban/board`; status chips over a card list on phones, columns on wide screens
- [x] 2.2 Follow `/api/plugins/kanban/events` with the chat gateway's ticket or token auth; debounced refetch, resume from the last cursor, reconnect with backoff
- [x] 2.3 Search, assignee, tenant and archived filters, and a board switcher
- [x] 2.4 Tests: refetch per burst, cursor resume, reconnect, filters, board switch, 404 means plugin off

## 3. Task detail, create, edit, comments, dependencies (#66)

- [x] 3.1 Task detail (bottom sheet on phones, dialog on wide screens): move to a status, assign, prioritise, edit, comment, add or remove dependencies, archive, delete
- [x] 3.2 Create form, defaulting to Triage; drag between columns on wide screens
- [x] 3.3 Show the plugin's refusal message as is
- [x] 3.4 Tests: request bodies, refusal messages, task panel, create form, tap to open, drag to move

## 4. Triage, bulk, dispatcher, orchestration (#68)

- [x] 4.1 Decompose and Specify for triage tasks, Reclaim for running tasks
- [x] 4.2 Selection mode with Move, Assign, Priority and Archive, reporting which tasks could not change
- [x] 4.3 Board menu: Run dispatcher now, and an Orchestration dialog
- [x] 4.4 Tests: repository, task panel, board and controller

## 5. Boards, runs, attachments

- [ ] 5.1 Manage boards: create, rename, archive, delete, remember the chosen board (#74, open). Board export and import are left out
- [ ] 5.2 Runs with a worker-log viewer, Terminate for the active run, diagnostics, and attachment listing and removal (#76, open)
- [ ] 5.3 Uploading and downloading attachments. Not started: #76 leaves it out because it needs a file picker and an authenticated download path

## 6. Verify

- [x] 6.1 Run `dart format`, `flutter analyze` and `flutter test` for each shipped PR
- [ ] 6.2 The same for steps 5.1 to 5.3 once they merge
