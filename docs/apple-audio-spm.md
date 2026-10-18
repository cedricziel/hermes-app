# Audio libraries and Swift Package Manager

Release 0.1.66 failed before uploading either Apple build to TestFlight.
The published `media_kit_libs_ios_audio` and `media_kit_libs_macos_audio` 1.1.4
packages only support CocoaPods. Normal CI could fall back to the runner's
CocoaPods, but the release runs Flutter under `bundle exec fastlane` and the
Ruby bundle deliberately contains no CocoaPods dependency.

Keep Apple builds on SPM. The two overrides in `pubspec.yaml` pin the upstream
media-kit SPM implementations at commit
`c533e446755f51cf53c7e57aea873f2aa5355f81`. Those packages contain SPM manifests,
privacy manifests, and checksum-pinned audio-only binary XCFramework targets.
The Dart player and other platforms keep their published dependencies; OGG
Opus/Vorbis support stays in place. No CocoaPods or Ruby dependency is added.

Remove both overrides when pub.dev publishes versions containing these SPM
implementations, after checking native iOS and macOS builds. They currently
identify themselves as iOS 1.1.5 and macOS 1.1.6, but are unreleased on pub.dev.
The lockfile records the full git revision so dependency resolution cannot
silently adopt a later upstream change.

CI and TestFlight preflight run `scripts/check_apple_spm.py` after `flutter pub get`
to reject native Apple plugins missing an SPM package. Dart-only plugins are
excluded. This catches a CocoaPods fallback before it can hide in a successful
normal build and break the release again.

The failed 0.1.66 tag contains the old dependency snapshot. Re-running that tag
alone will reproduce the failure. A new release containing this fix is required;
do not move the existing release tag.
