# Building blocks

Need, building block, where, and the rule it enforces. Use the block instead of
a raw API; a guard that bans the raw API names the block as its replacement.
Rules are stated in full in the area's file under `docs/architecture/`.

## Non-UI

| Need | Building block | Where | Rule it enforces |
| --- | --- | --- | --- |
| Build or read a `hermes://` link | `deepLinkUri`, `parseDeepLink` | `lib/src/deep_links/deep_link_uri.dart`, `deep_link_parser.dart` | Never build or parse a link by hand; a link's `prompt` goes under the draft and is never sent. |
| Work without a screen (intents, notification answers, background refresh) | `withHeadlessHermes` | `lib/src/background/headless_hermes.dart` (used by `lib/src/intents/`, `lib/src/notifications/request_answers.dart`) | No second `AuthController`; never clears the stored session. |
| Call a REST route | `authController.api!.raw` (generated client) | `lib/src/auth/auth_controller.dart` (`api`), `packages/hermes_api` | One managed `Dio`; no hand-rolled calls. Never edit the generated package. |
| REST routes the spec cannot type | Hand-written exceptions: `/api/status`, `/api/auth/providers`, `/api/auth/me`, `fetchKanbanAttachment`, `fetchManagedFile`, `downloadFsFile`, `fetchSessionExport` | `lib/src/api/hermes_api_client.dart` | Add here only when the generated method decodes JSON and cannot return the bytes. |
| A path on the server | `ServerPath` | `lib/src/files/server_path.dart` | Every path is one the server returned; no join, never outside the git root. |
| List or read server files | `/api/fs` repository (`list`, `git-root`, `default-cwd`, `read-text`, `download`) | `lib/src/files/hermes_files_repository.dart` | `/api/fs` only, with `profile`; `/api/files` is left to `MEDIA:` attachments. |
| Download a file | `MediaStore.stageDownload`, `FileExport` (Save) | `lib/src/chat/media/media_store.dart`, `lib/src/chat/media/file_export.dart` | Streams to a `.part` file, never in memory; nothing downloads without a tap. |
| Clear downloads on sign-out or lock | `MediaStore.clearFileDownloads`, `FilesLockCleanup` | `lib/src/chat/media/media_store.dart`, `files_lock_cleanup.dart` | Every Files download goes on sign-out and App Lock. |
| Secret-looking file names | `SecretNames` | `lib/src/files/secret_names.dart` | Ask first; cache under `fs-secret:`; delete when the preview closes. |
| Platform limits on files | `FilesPlatformPolicy` | `lib/src/files/files_platform_policy.dart` | No Open with... for runnable types on Windows; Mark of the Web on staged files. |
| Confirm an MCP command server | `showMcpCommandReview` / `McpCommandReview` | `lib/src/mcp/mcp_command_review.dart` | A command server is never sent without the reviewer's confirmation. |
| User-visible text | `context.l10n`, ARB files under `@@x-area-<dir>`, `kReleasedLocales` | `lib/l10n/l10n.dart`, `lib/l10n/arb/app_en.arb`, `app_de.arb` | No strings below the widget layer; none for telemetry names, ids or server values. |
| Breadcrumbs, spans, app events | `Breadcrumbs`, `Telemetry` | `lib/src/telemetry/breadcrumbs.dart`, `telemetry.dart` | Fixed names, counts, flags and outcomes only; never content, titles, profile names, addresses, ids or secrets. Must never break the app. |
| Server details on spans | `hermes.*` attributes | `lib/src/telemetry/hermes_server_attributes.dart` | Span attributes, never resource attributes. |
| A new system widget | `kSurfaceWidgetKinds` | `lib/src/surfaces/widget_kinds.dart` | Add the kind so snapshot writes reload it; extensions read only the snapshot. |
| A menu bar chord | `MacCommandScope`, `menuLayout` | `lib/src/macos/mac_commands.dart`, `lib/src/macos/menu_layout.dart` | The menu owns the chord; add no key handler for it. |
| Cleartext `http://` | `isLocalHost`, `allowCleartext` | `lib/src/auth/server_address.dart` (`isLocalHost`), `lib/src/auth/auth_controller.dart` | Only local hosts unless the user confirmed it. |
| Platform hint text changed | `earlierAppPlatformHints` | `lib/src/platform_hint/platform_hint_repository.dart` | Add the old text when `appPlatformHint` changes. |

## UI

Owned by the style session; filled in a later PR.
