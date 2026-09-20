## 1. Dependencies and native setup

- [ ] 1.1 Add `file_selector`, `image_picker`, `desktop_drop` and `pasteboard`; confirm `flutter pub get` still resolves with the `flutter_otel` pins
- [ ] 1.2 Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`
- [ ] 1.3 Add `com.apple.security.files.user-selected.read-only` to both macOS entitlement files

## 2. Sources

- [ ] 2.1 Add the `AttachmentSource` interface and a plugin-backed implementation (files, gallery, camera, paste)
- [ ] 2.2 Add a fake source under `test/support/`
- [ ] 2.3 Add the attach control to the composer with the platform-dependent menu
- [ ] 2.4 Wrap the chat in a `DropTarget` with the drop indicator, desktop only
- [ ] 2.5 Bind the paste chord in the composer with the text fallback

## 3. Verification

- [ ] 3.1 Widget tests for the menu per platform, drop, paste image and paste text, and camera denied
- [ ] 3.2 Try each source in the running macOS app (verify-in-app skill); note camera and drop on iOS/Android as untested if no device is available
- [ ] 3.3 Update `openspec/specs/chat` cross-references if the shared-content wording moves
