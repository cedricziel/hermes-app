## Context

The chat screen already owns a pending list of `SharedFile`s that the share sheet fills. This change only adds producers for that list; what happens on send belongs to `attach-files-in-chat`. Plugins were chosen by comparing pub.dev candidates for release recency, publisher, platform coverage and whether they resolve with our pinned `flutter_otel` and `win32` constraints.

## Goals / Non-Goals

**Goals:**
- One `AttachmentSource` seam so the composer does not know which plugin produced a file.
- No new behaviour beyond adding attachments.

**Non-Goals:**
- Anything after a file is in the list (limits, sending); that belongs to `attach-files-in-chat`.

## Decisions

- **File picking: `file_selector`.** Published by flutter.dev, covers all five platforms, and resolves with our pins. `file_picker` was the alternative; its newest release does not resolve against `win32 ^5`, which `flutter_secure_storage` and `package_info_plus` need.
- **Photos and camera: `image_picker`.** Published by flutter.dev. On desktop it only wraps file selection and its camera source throws, so the camera entry is shown on iOS and Android only.
- **Drag and drop: `desktop_drop`.** Wraps the chat body in a `DropTarget`, off on iOS. `super_drag_and_drop` was rejected: it forces old `device_info_plus`, which clashes with the `flutter_otel` pin, and needs a Rust toolchain.
- **Paste: `pasteboard`.** Flutter's `Clipboard` is text only. A `Shortcuts`/`Actions` binding on the paste chord tries `Pasteboard.image`, then `Pasteboard.files()`, and otherwise falls through to the default text paste. Same rejection of `super_clipboard` as above.
- **Seam.** `AttachmentSource` methods return `List<SharedFile>`; the chat screen adds the result to its pending list. Tests inject a fake source.

Platforms: iOS (`NSCameraUsageDescription`), Android (none for the picker), macOS (`com.apple.security.files.user-selected.read-only` in `DebugProfile.entitlements` and `Release.entitlements`), Windows and Linux (none). watchOS is not affected. No invariant from the project context is touched.

## Risks / Trade-offs

- macOS sandbox handling of dropped files must be verified on a real build; if the drop scope is not enough, the read-only entitlement already covers it.
- `pasteboard` and `desktop_drop` are single-maintainer packages. Both sit behind the seam, so replacing one touches one file.
