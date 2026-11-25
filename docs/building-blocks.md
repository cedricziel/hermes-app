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
| List or read server files | `/api/fs` repository (`list`, `git-root`, `default-cwd`, `read-text`, `download`) | `lib/src/files/hermes_files_repository.dart` | `/api/fs` only. Every request carries `profile`, except the first `default-cwd`, whose folder is thrown away; `/api/files` is left to `MEDIA:` attachments. |
| Download a file | `MediaStore.stageDownload`, `FileExport` (Save) | `lib/src/chat/media/media_store.dart`, `lib/src/chat/media/file_export.dart` | Streams to a `.part` file, never in memory; nothing downloads without a tap. |
| Clear downloads on sign-out or lock | `MediaStore.clearFileDownloads`, `FilesLockCleanup` | `lib/src/chat/media/media_store.dart`, `files_lock_cleanup.dart` | Every Files download goes on sign-out and App Lock. |
| Secret-looking file names | `SecretNames` | `lib/src/files/secret_names.dart` | Ask first; cache under `fs-secret:` (`kSecretCopyKeyPrefix`, `lib/src/chat/media/media_store.dart`); delete when the preview closes. |
| Platform limits on files | `FilesPlatformPolicy` | `lib/src/files/files_platform_policy.dart` | No Open with... for runnable types on Windows; Mark of the Web on staged files. |
| Confirm an MCP command server | `showMcpCommandReview` / `McpCommandReview` | `lib/src/mcp/mcp_command_review.dart` | A command server is never sent without the reviewer's confirmation. |
| User-visible text | `context.l10n`, ARB files under `@@x-area-<dir>`, `kReleasedLocales` | `lib/l10n/l10n.dart`, `lib/l10n/arb/app_en.arb`, `app_de.arb` | No strings below the widget layer; none for telemetry names, ids or server values. |
| Breadcrumbs, spans, app events | `Breadcrumbs`, `Telemetry` | `lib/src/telemetry/breadcrumbs.dart`, `telemetry.dart` | Fixed names, counts, flags and outcomes only; never content, titles, profile names, addresses, ids or secrets. Must never break the app. |
| A preferences read that falls back to a default | `readSaved(() => prefs.getBool(key), 'the saved …')`, or a `try` with `on Object catch` that calls `reportUnreadablePrefs(error, stack, 'the saved …')` | `lib/src/settings/report_unreadable_prefs.dart` | Fixed setting name only, never a value. Hands the failure to `FlutterError.reportError` so the crash reporter still sees a broken store; `reportBug` ignores an `Exception`. A choice that guards something falls back to the safe side (`ifUnreadable`: App Lock counts as on, Spotlight and the saved-chat flag as off and set). `arch.prefs-read-unhandled` fails a read outside `readSaved` and outside a `try` that catches `Object`. |
| Server details on spans | `hermes.*` attributes | `lib/src/telemetry/hermes_server_attributes.dart` | Span attributes, never resource attributes. |
| A new system widget | `kSurfaceWidgetKinds` | `lib/src/surfaces/widget_kinds.dart` | Add the kind so snapshot writes reload it; extensions read only the snapshot. |
| A menu bar chord | `MacCommandScope`, `menuLayout` | `lib/src/macos/mac_commands.dart`, `lib/src/macos/menu_layout.dart` | The menu owns the chord; add no key handler for it. |
| Keyboard zoom and pan of an image | `ZoomKeyboardShortcuts` | `lib/src/widgets/zoom_keyboard_shortcuts.dart` | Wrap the `InteractiveViewer` and share its controller; Cmd (Apple) or Ctrl with `=`, `-`, `0`, arrows pan while zoomed. macOS resets with Cmd+Option+0, as the menu owns Cmd+0. Under an ancestor that takes focus on click (`QuickLookTarget`) add `ZoomKeyRelay` above it (`docs/architecture/chat.md`). |
| Cleartext `http://` | `isLocalHost`, `allowCleartext` | `lib/src/auth/server_address.dart` (`isLocalHost`), `lib/src/auth/auth_controller.dart` | Only local hosts unless the user confirmed it. |
| Platform hint text changed | `earlierAppPlatformHints` | `lib/src/platform_hint/platform_hint_repository.dart` | Add the old text when `appPlatformHint` changes. |

## UI

Owned by the style session; the rest is filled in a later PR.

| Need | Building block | Where | Rule it enforces |
| --- | --- | --- | --- |
| A dialog | `showAppDialog` (`barrierDismissible`: null keeps the platform default, false makes the barrier inert everywhere) | `lib/src/widgets/dialog_presentation.dart` | No raw `showDialog` or `showAdaptiveDialog` (`style.dialog`). |
| A sheet (dialog on a Mac and wide windows) | `showAdaptiveSheet` | `lib/src/widgets/adaptive_sheet.dart` | No raw `showModalBottomSheet` (`style.dialog`). |
| An iOS action sheet (title, entries, Cancel from `widgetsCancel`) | `showAppActionSheet`, `AppActionSheetEntry` | `lib/src/widgets/app_action_sheet.dart` | `style.dialog` catches a raw `showCupertinoModalPopup` (and the other `show*` dialog calls, `AlertDialog`, `CupertinoAlertDialog`) outside the building-block files; use this helper for an action sheet. |
| A bordered button at the end of a `GroupedRow` that must not overflow at large text | `trailingActionStacks` with `GroupedRow(trailingBelow:, separateTrailing: true)` | `lib/src/widgets/trailing_action_fit.dart`, `lib/src/widgets/grouped_list.dart` | Measures the label and the button's own `ButtonStyle`; at the default size and where it fits, the row is unchanged; the button is its own control at every size. |
| Show keyboard focus on a control | `focusRingShape` / `focusRingShapeOf` in a button style; `FocusRing` around a row, list tile or segment that a container clips; `FocusRingMenuItem` / `FocusRingCheckedMenuItem` (built by `AdaptivePopupMenuButton`); chips take it from the theme; `FocusRing.outside` round a control nothing clips (floating button, standalone tap target, `CupertinoSlidingSegmentedControl`); `HostFocusRing<H>` for the label of a control Material builds (`DisclosureTile`, the Android segments); `showRingMenu` for a context menu; `FocusableTap` (`lib/src/widgets/focusable_tap.dart`) makes a bare `GestureDetector` tap box a tab stop that Enter and Space activate, inside whichever of `FocusRing` or `FocusRing.outside` fits | `lib/src/theme/focus_ring.dart` | Keyboard focus only, a 2 px ring in the link colour; never a hand-drawn focus border or a raw colour. `arch.button-shape-without-focus-ring` fails on a button style's own shape without the ring, `arch.list-tile-without-focus-ring` on a list tile outside `FocusRing`, `arch.chip-shape-without-focus-ring` on a chip with its own shape and `arch.popup-menu-without-focus-ring` on a menu not built by `AdaptivePopupMenuButton`; `arch.sliding-control-without-focus-ring`, `arch.segmented-button-without-focus-ring`, `arch.expansion-tile-without-focus-ring` and `arch.floating-button-without-focus-ring` fail on those controls built bare; `arch.focus-ring-keyboard-override` keeps `markFocusRingKeyboardInput` to the catalog and tests (`docs/architecture/settings-screens.md`). |
