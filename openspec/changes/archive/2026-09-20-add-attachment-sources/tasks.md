## 1. Dependencies and native setup

- [x] 1.1 Add `image_picker`, `desktop_drop` and `pasteboard` (files use the existing `file_picker`); confirm `flutter pub get` still resolves with the `flutter_otel` pins
- [x] 1.2 Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`
- [x] 1.3 Check that both macOS entitlement files already carry the user-selected file entitlement (Kanban attachments added `read-write`)

## 2. Sources

- [x] 2.1 Add the `AttachmentSource` interface and a plugin-backed implementation (files, gallery, camera, paste)
- [x] 2.2 Add a fake source under `test/support/`
- [x] 2.3 Add the attach control to the composer with the platform-dependent menu
- [x] 2.4 Wrap the chat in a `DropTarget` with the drop indicator, desktop only
- [x] 2.5 Bind the paste chord in the composer with the text fallback

## 3. Verification

- [x] 3.1 Widget tests for the menu per platform, drop, paste image and paste text, and camera denied
- [x] 3.2 Try each source in the running macOS app (verify-in-app skill); note camera and drop on iOS/Android as untested if no device is available
- [x] 3.3 Update `openspec/specs/chat` cross-references if the shared-content wording moves
