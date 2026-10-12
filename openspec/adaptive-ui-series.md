# Adaptive UI series

All listed UI changes are merged. Each change shipped in a separate PR.

- [x] MCP setup and installation, merged in [#636](https://github.com/cedricziel/hermes-app/pull/636)
- [x] MCP configuration editor and sign-in surfaces, merged in [#640](https://github.com/cedricziel/hermes-app/pull/640)
- [x] Skill editor, merged in [#642](https://github.com/cedricziel/hermes-app/pull/642)
- [x] Skill details and background job status, merged in [#643](https://github.com/cedricziel/hermes-app/pull/643)
- [x] Hub security-scan and preview status, merged in [#647](https://github.com/cedricziel/hermes-app/pull/647)
- [x] Kanban worker log, merged in [#649](https://github.com/cedricziel/hermes-app/pull/649)
- [x] Kanban task metadata and notification settings, merged in [#652](https://github.com/cedricziel/hermes-app/pull/652)
- [x] Kanban task header and action controls, merged in [#655](https://github.com/cedricziel/hermes-app/pull/655)
- [x] Kanban attachments, comments and activity, merged in [#660](https://github.com/cedricziel/hermes-app/pull/660)
- [x] Connection setup and details, merged in [#661](https://github.com/cedricziel/hermes-app/pull/661)
- [x] Chat teammate and slash-command autocomplete, merged in [#662](https://github.com/cedricziel/hermes-app/pull/662)

Preserve behavior and security safeguards. Validate standalone catalog states and native layouts for each change. Previous grouped form series is complete in PRs #627, #629, #630, #631, #632 and #633.

The [platform navigation backlog](../docs/platform-navigation-todo.md) tracks remaining modal route presentation, keyboard and pointer behavior, and device verification. Completed component content does not by itself verify route motion or authentication teardown. Preserve these components when changing their presentation.
