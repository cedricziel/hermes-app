# Spec Delta

## ADDED Requirements

### Requirement: Android storage

On Android the snapshot SHALL be stored under the same key, `hermes.surface.v1`, in the `home_widget` plugin's app-private preferences, which the Android widgets read in the app's own process. The snapshot's content, limits and App Lock rules SHALL be the same as on iOS.

#### Scenario: Widget reads the snapshot

- **WHEN** the app writes a snapshot on Android
- **THEN** an Android widget redrawn afterwards reads that JSON and nothing else

### Requirement: Android widget reload

After a successful write the app SHALL ask the system to redraw each widget kind that has an Android provider, naming the provider class, and SHALL NOT ask for a kind that has none (the New Chat, Dictate and Quick launch kinds). A kind that fails to reload SHALL be logged as `widgets.reload_failed` and the others SHALL still reload, as on iOS.

#### Scenario: Write on Android

- **WHEN** a snapshot is written on an Android device
- **THEN** the Recent chats, Needs you and Board providers are asked to redraw and no other kind is requested

### Requirement: Snapshot excluded from Android backups

The Android app SHALL exclude the snapshot's preferences file from Auto Backup and device-to-device transfer, so that no chat title, snippet or job name leaves the device in a backup, and a restored install shows "Open Hermes to sign in" until the app writes a snapshot.

#### Scenario: Restore on a new phone

- **WHEN** the app is restored from a backup on a new phone and a widget is added before opening the app
- **THEN** the widget shows "Open Hermes to sign in"
