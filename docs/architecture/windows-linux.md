# Windows and Linux

**What the desktop builds are** (`windows/`, `linux/`, `scripts/package-linux.sh`, `.github/workflows/ci.yml`, `release-please.yml`). Both are stock Flutter runners with no custom native code (no method channels, unlike `macos/Runner`). CI builds Windows (`flutter build windows --release`) and Linux (release bundle, packaged by `scripts/package-linux.sh` into a tar.gz and a `.deb`, x86_64 and arm64) and never launches either. Releases attach an unsigned Windows x64 zip (no MSIX, no installer), so SmartScreen warns and Windows notifications would run without package identity. The `.deb` depends on GTK 3, `libsecret`, `libjsoncpp`, `pulseaudio-utils` and `libmpv2`.

**How a feature is turned off.** There is no shared "desktop" helper. Each feature checks `defaultTargetPlatform` itself and, on a platform it does not list, returns null or a no-op (`createPlatformShareInbox` returns `NoopShareInbox`, `SurfaceSnapshotStore` and `DeepLinks` are `null`, `BackgroundScheduler._supported` is false). Windows and Linux therefore fall through every list that names iOS, Android and macOS. Where a check names `windows`/`linux` it enables the feature (`DesktopNavigationCommands` in `app.dart`, the Bot Screen's desktop key and focus handling, the Ctrl-V attachment paste).

Everything below is read from code and plugin metadata. Nothing was run on Windows. Linux was not run either: `flutter build linux --release` got as far as configuring the plugins and stopped in `media_kit_libs_linux`, whose `mimalloc` download came back as an empty file (an integrity check failure from the sandbox's network, not a repository fault).

## Evidence per feature

| Feature | Evidence | Windows (from code, not run) | Linux |
| --- | --- | --- | --- |
| Sign-in | `auth/sign_in_browser.dart`: `ExternalBrowser` (`url_launcher`, Windows and Linux backends) everywhere except iOS and macOS; the loopback listener is `dart:io` | Works | Works |
| Session storage | `auth/token_store.dart` uses `flutter_secure_storage`: Windows keeps AES-GCM files keyed from Credential Manager; Linux uses `libsecret` and needs a Secret Service daemon | Works | Partly: no keyring daemon, no stored session |
| Session lock between engines | `auth/session_mutex_native.dart`: `sqlite3` file in the app support directory | Works | Works |
| Durable send queue | `chat/queue_storage/queue_directory.dart`: app support directory; `chmod 700` on Linux only; the key is in secure storage | Works (no explicit directory permissions; relies on the per-user profile) | Works |
| Attachments | `plugin_attachment_source.dart`: files origin only (photos and camera are `_isPhone`); `desktop_drop`, `pasteboard.files` | Works | Works |
| Voice playback | `media_kit` with `media_kit_libs_windows_audio` and `media_kit_libs_linux` (libmpv) | Works | Works with `libmpv2` |
| Dictation | `voice/voice_recorder.dart`: `record` with `pcm16bits`; `DictationSettings.offered` is iOS/macOS only, so the engine is Hermes | Works | Partly: `record_linux` needs `parecord`, `pactl` and `ffmpeg` |
| Voice calls | `chat_screen_calls.dart`: iOS only; `hermes_calls` and `hermes_speech` have no Windows or Linux code | Not available | Not available |
| Bot Screen | `chat_screen_bot_screen.dart` lists both as desktop; `screen_keyboard.dart` has a Windows branch | Works | Works |
| Notifications | `notifications/local_notification_service.dart`: `_supported` is Android, iOS, macOS; `_start` passes only Android and Darwin settings | Not available | Not available |
| Notification answers and background refresh | `app/providers/notification_providers.dart` (`RequestAnswers` null), `background_scheduler.dart` (`_supported` is iOS and Android) | Not available | Not available |
| Messages from Hermes, schedule alerts | `agent_messages/agent_message_watcher.dart` names Android, iOS, macOS; schedule alerts need notifications | Not available | Not available |
| App Lock | `app_lock/device_authenticator.dart` over `local_auth` (Windows Hello via `local_auth_windows`; no Linux backend, handled as `MissingPluginException` and reported unavailable) | Partly | Not available |
| Deep links | `app/providers/deep_link_providers.dart` returns null outside iOS, macOS, Android; `app_links` itself supports both, but nothing registers `hermes://` (the `.desktop` file has no `MimeType`, Windows has no registry entry) | Not available | Not available |
| Receive share, Spotlight, quick actions, widgets, Live Activities, Watch | `share/share_inbox.dart`, `spotlight_*`, `surface_providers.dart`, `watch_providers.dart`: iOS, Android or macOS only | Not available | Not available |
| Drag out, quick panel, menu bar, Dock, conversation windows, Quick Look | `drag_out/mac_drag_out_source.dart`, `windows/conversation_window_app.dart` and the others check macOS; `desktop_multi_window` is linked on both but only macOS starts a second engine | Not available | Not available |
| Update check | `update/github_release_store.dart` (`onLinux`, `onWindows`): latest GitHub release, link only | Works | Works |
| Network | `network/network_signals.dart` reports VPN on Windows and Android; user-installed CAs are loaded on Android only (Dart uses the system store on the desktops) | Works | Works |

## Gaps

Cheap to close, in the order that helps most:

1. **Notifications on Windows and Linux.** `flutter_local_notifications` (^23.0.2, already a dependency, maintained by MaikuB) already ships `flutter_local_notifications_windows` (FFI, WinRT toasts) and `flutter_local_notifications_linux` (D-Bus, Desktop Notifications spec). The Windows FFI plugin is already in `windows/flutter/generated_plugins.cmake`; the Linux one is pure Dart and needs no native step. The work is in `local_notification_service.dart`: add `LinuxInitializationSettings` (needs a default action name) and `WindowsInitializationSettings` (app name, an AppUserModelID and a GUID) to `_start`, extend `_supported`, build `LinuxNotificationDetails` and `WindowsNotificationDetails` next to the Android and Darwin ones, and extend the `defaultTargetPlatform` checks in `notification_providers.dart` and `agent_message_watcher.dart` so request answers and messages from Hermes follow. Limits to state in the UI or docs: the Linux plugin's actions depend on the notification server's capabilities (`getCapabilities`); on Windows an unpackaged app cannot cancel or list shown toasts (that needs MSIX, e.g. the `msix` package) and `periodicallyShow` throws, which the app does not use. Nothing here needs a new dependency.
2. **App Lock explanation.** `app_lock_dialog.dart` always tells the user to set up Face ID, Touch ID or a passcode in system settings, which on Linux can never help. Say instead that App Lock is not available on Linux (no system prompt exists for it), and on Windows point to Windows Hello. This is a text change plus a platform branch, with the strings moved to the ARB files. No plugin to add; a Linux lock would need a PAM or polkit prompt, which has no mature Flutter plugin.
3. **Linux keyring message.** When `libsecret` finds no Secret Service, tell the user to install and unlock GNOME Keyring or KWallet instead of a generic sign-in failure. Needs a verified failure path on a Linux desktop first.
4. **`.deb` dependencies.** Add `ffmpeg` to `Depends` (or `Recommends`) if dictation needs it on Linux; check on a Linux desktop first. Adding `Recommends: gnome-keyring | kwalletmanager` is a one-line packaging change.
5. **`hermes://` links.** `app_links` already supports Linux and Windows. It needs the scheme registered (`MimeType=x-scheme-handler/hermes;` and `%u` in the `.desktop` `Exec`; a registry entry from an installer on Windows) and single-instance handling (`linux/runner/my_application.cc` uses `G_APPLICATION_NON_UNIQUE`), then the platform lists in `deep_link_providers.dart` extended. Medium: needs an installer on Windows.

Larger and not planned here: background refresh (`workmanager` has no desktop support; a tray resident process would be a different design), drag out, quick panel, share targets, signing and an installer for Windows.
