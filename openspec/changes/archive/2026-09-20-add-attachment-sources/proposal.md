## Why

Attachments can only come from the OS share sheet today. Users expect a paperclip in the composer, a photo library and camera on phones, drag and drop and paste on desktop.

## What Changes

- Add an attach control to the composer: on every platform it opens the system file picker; on iOS and Android it also offers the photo library and the camera.
- On macOS, Windows and Linux, accept files dropped onto the chat and images or files pasted into the composer.
- Every source adds to the same pending-attachment list the composer already has for shared files, so sending behaves identically whatever the source.
- Add the camera usage description on iOS. The macOS user-selected file entitlement is already there for Kanban attachments.

Non-goals: recording video or audio, editing or cropping images before sending, an in-app file browser for the server, and drag and drop on iOS (the platform gives no drop target to Flutter here).

## Capabilities

### New Capabilities
- `attachment-sources`: where users can add attachments from, per platform.

### Modified Capabilities

## Impact

- New dependencies `image_picker`, `desktop_drop` and `pasteboard`, all maintained, with iOS, Android and desktop coverage between them. `image_picker` is published by flutter.dev. Files are picked with `file_picker`, which the Kanban attachments already use.
- Native: `NSCameraUsageDescription` in `ios/Runner/Info.plist`. Both macOS entitlement files already carry `com.apple.security.files.user-selected.read-write`, which covers picking and dropping.
- Security and privacy: picked files are read only when the user sends them; nothing is read in the background. The camera prompt is shown only when the user picks the camera. No new token or storage use.
- Telemetry: none.
- Independent of `attach-files-in-chat`: it only adds items to the pending list that exists today, so the two can merge in either order.
