# Local Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tell the user, with a local notification, when a reply finishes or the agent asks for an approval or an answer while the app is not focused or the thread is not on screen.

**Architecture:** A pure function (`attentionFor`) decides whether an event deserves a notification. A `NotificationService` interface posts it and reports taps; the real one wraps `flutter_local_notifications` on macOS, iOS and Android and does nothing elsewhere. `NotificationSettings` (a `ChangeNotifier` like `ThemeController`) holds the on/off switch and permission state. `ChatScreen` tracks app focus, asks the policy about each reply event, asks for permission once after the first send, and opens the thread when a notification is tapped.

**Tech Stack:** Flutter, Dart 3, `flutter_local_notifications`, `provider`, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-19-local-notifications-design.md`

## Global Constraints

- Run every command from the worktree root. Never `cd` elsewhere. Never use bare `git stash`.
- Before each commit: `dart format lib test` and `flutter analyze` must be clean. CI also runs `dart format --output=none --set-exit-if-changed .`.
- Semantic commit messages, one concern per commit (`feat(notifications): ...`, `test(...)`, `build(...)`). No "and" in a subject.
- No code comments unless they explain something the code cannot. Match the surrounding doc-comment style (`///` on public types).
- New behavior needs a test written first. Follow `test/theme_controller_test.dart` (settings), `test/appearance_setting_test.dart` (dialog and menu) and `test/chat_streaming_test.dart` (screen with `FakeChatTransport`).
- Platforms: macOS, iOS and Android only. On any other platform the service does nothing and never throws.
- Notification wording, exactly: finished reply → a preview of the reply (whitespace collapsed, cut at 120 characters with `…`), `Reply ready` if the reply is empty, `Reply failed` if the turn failed; approval → `Waiting for your approval`; clarify → `Has a question for you`. The title is the thread's title. The payload is the thread id and nothing else. Approval and clarify notifications never carry the command or question text.
- The Notifications dialog states, exactly: `Alerts arrive while Hermes is running, including for a short time after you leave it.` and, when permission was denied, `Turn on notifications for Hermes in system settings.`
- Do not touch `packages/hermes_api` (generated client, never hand-edited).
- Preferences keys: `hermes.notifications_enabled`, `hermes.notifications_permission_asked`, `hermes.notifications_permission_denied`. The switch defaults to on.

---

## File Structure

| File                                                                                                                                                                                                | Change | Responsibility                                                           |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------ |
| `lib/src/notifications/attention_policy.dart`                                                                                                                                                       | create | `AttentionNotification`, `replyPreview`, `attentionFor` (pure)           |
| `lib/src/notifications/notification_settings.dart`                                                                                                                                                  | create | On/off switch and permission state, persisted                            |
| `lib/src/notifications/notification_service.dart`                                                                                                                                                   | create | `NotificationService` interface                                          |
| `lib/src/notifications/local_notification_service.dart`                                                                                                                                             | create | Plugin-backed service, pure helpers                                      |
| `lib/src/notifications/notifications_dialog.dart`                                                                                                                                                   | create | Settings dialog                                                          |
| `lib/src/chat/chat_screen.dart`                                                                                                                                                                     | modify | Focus, policy hook, permission after first send, tap and launch handling |
| `lib/src/chat/widgets/thread_sidebar.dart`                                                                                                                                                          | modify | "Notifications" menu item                                                |
| `lib/main.dart`                                                                                                                                                                                     | modify | Provide the settings and the service                                     |
| `pubspec.yaml`, `pubspec.lock`                                                                                                                                                                      | modify | Add `flutter_local_notifications`                                        |
| `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`                                                                                                                          | modify | `POST_NOTIFICATIONS`, plugin build requirements                          |
| `ios/Runner/AppDelegate.swift`, `macos/Runner/AppDelegate.swift`                                                                                                                                    | modify | Notification center delegate                                             |
| `PRIVACY.md`                                                                                                                                                                                        | modify | Note about previews and the stored switch                                |
| `test/support/fake_notification_service.dart`                                                                                                                                                       | create | Hand-driven service                                                      |
| `test/support/pump_chat.dart`                                                                                                                                                                       | modify | Optional extra providers                                                 |
| `test/attention_policy_test.dart`, `test/notification_settings_test.dart`, `test/local_notification_service_test.dart`, `test/chat_notifications_test.dart`, `test/notifications_setting_test.dart` | create | Tests per task                                                           |

---

### Task 1: The attention policy

**Files:**

- Create: `lib/src/notifications/attention_policy.dart`
- Test: `test/attention_policy_test.dart`

**Interfaces:**

- Produces (used by Tasks 3 and 5):
  - `class AttentionNotification { const AttentionNotification({required String threadId, required String title, required String body}); final String threadId; final String title; final String body; }`
  - `String replyPreview(String text)`
  - `AttentionNotification? attentionFor({required ChatEvent event, required ChatThread thread, required bool appFocused, required String? selectedThreadId, required bool enabled})`
  - Constants `kReplyReadyBody`, `kReplyFailedBody`, `kApprovalBody`, `kQuestionBody`, `kPreviewLength`.

- [ ] **Step 1: Write the failing tests**

Create `test/attention_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';

ChatThread _thread([String id = 't1']) =>
    ChatThread(id: id, title: 'Release notes', updatedAt: DateTime(2026));

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

const _question = ClarifyRequest(
  requestId: 'r2',
  questions: [ClarifyQuestion(qid: '', question: 'Which colour?')],
);

AttentionNotification? _for(
  ChatEvent event, {
  bool focused = false,
  String? selected,
  bool enabled = true,
}) => attentionFor(
  event: event,
  thread: _thread(),
  appFocused: focused,
  selectedThreadId: selected,
  enabled: enabled,
);

void main() {
  group('replyPreview', () {
    test('keeps a short reply as it is', () {
      expect(replyPreview('Done.'), 'Done.');
    });

    test('collapses whitespace and newlines', () {
      expect(replyPreview('  a\n\n  b\tc '), 'a b c');
    });

    test('cuts a long reply at 120 characters with an ellipsis', () {
      expect(replyPreview('x' * 200), '${'x' * 120}…');
    });

    test('does not add an ellipsis at exactly 120 characters', () {
      expect(replyPreview('x' * 120), 'x' * 120);
    });
  });

  group('what is said', () {
    test('a finished reply carries its preview under the thread title', () {
      final n = _for(const ReplyCompleted('Done.'))!;

      expect(n.threadId, 't1');
      expect(n.title, 'Release notes');
      expect(n.body, 'Done.');
    });

    test('an empty reply says it is ready', () {
      expect(_for(const ReplyCompleted(''))!.body, kReplyReadyBody);
    });

    test('a failed reply says so, not its error text', () {
      final n = _for(const ReplyCompleted('boom: trace', failed: true))!;

      expect(n.body, 'Reply failed');
    });

    test('an approval never shows the command', () {
      final n = _for(const ApprovalRequested(_approval))!;

      expect(n.body, 'Waiting for your approval');
      expect(n.body, isNot(contains('rm')));
    });

    test('a clarify question never shows the question', () {
      final n = _for(const ClarifyRequested(_question))!;

      expect(n.body, 'Has a question for you');
    });
  });

  group('when it is said', () {
    const events = <ChatEvent>[
      ReplyCompleted('Done.'),
      ApprovalRequested(_approval),
      ClarifyRequested(_question),
    ];

    test('never while the app is focused on that thread', () {
      for (final event in events) {
        expect(_for(event, focused: true, selected: 't1'), isNull);
      }
    });

    test('when the app is focused on another thread', () {
      for (final event in events) {
        expect(_for(event, focused: true, selected: 't2'), isNotNull);
      }
    });

    test('when the app is focused and no thread is selected', () {
      expect(_for(events.first, focused: true, selected: null), isNotNull);
    });

    test('when the app is not focused, even on the selected thread', () {
      for (final event in events) {
        expect(_for(event, focused: false, selected: 't1'), isNotNull);
      }
    });

    test('never when notifications are off', () {
      for (final event in events) {
        expect(_for(event, enabled: false), isNull);
      }
    });

    test('not for events that are not worth an alert', () {
      const quiet = <ChatEvent>[
        ReplyStarted(),
        ReplyDelta('x'),
        ToolStarted(name: 'shell'),
        ToolFinished(name: 'shell'),
        ThreadTitled('New title'),
        ThreadBound('t9'),
        InputRequestExpired('r1'),
      ];
      for (final event in quiet) {
        expect(_for(event), isNull);
      }
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/attention_policy_test.dart`
Expected: compile error, `attention_policy.dart` not found.

- [ ] **Step 3: Implement**

Create `lib/src/notifications/attention_policy.dart`:

```dart
import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';

const kPreviewLength = 120;
const kReplyReadyBody = 'Reply ready';
const kReplyFailedBody = 'Reply failed';
const kApprovalBody = 'Waiting for your approval';
const kQuestionBody = 'Has a question for you';

/// What to tell the user about, and for which thread.
class AttentionNotification {
  const AttentionNotification({
    required this.threadId,
    required this.title,
    required this.body,
  });

  final String threadId;
  final String title;
  final String body;
}

/// The start of [text] on one line, for a notification body.
String replyPreview(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= kPreviewLength) return flat;
  return '${flat.substring(0, kPreviewLength).trimRight()}…';
}

/// The notification [event] on [thread] deserves, or null. Nothing is said
/// while the app is focused on that very thread, or while notifications are
/// off. Approval and clarify notifications stay generic on purpose: the
/// command or question must not show on a lock screen.
AttentionNotification? attentionFor({
  required ChatEvent event,
  required ChatThread thread,
  required bool appFocused,
  required String? selectedThreadId,
  required bool enabled,
}) {
  if (!enabled) return null;
  if (appFocused && selectedThreadId == thread.id) return null;
  final body = switch (event) {
    ReplyCompleted(:final text, :final failed) =>
      failed
          ? kReplyFailedBody
          : (replyPreview(text).isEmpty ? kReplyReadyBody : replyPreview(text)),
    ApprovalRequested() => kApprovalBody,
    ClarifyRequested() => kQuestionBody,
    _ => null,
  };
  if (body == null) return null;
  return AttentionNotification(
    threadId: thread.id,
    title: thread.title,
    body: body,
  );
}
```

- [ ] **Step 4: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/attention_policy_test.dart`
Expected: analyze clean; all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(notifications): decide what deserves an alert"
```

---

### Task 2: Notification settings

**Files:**

- Create: `lib/src/notifications/notification_settings.dart`
- Test: `test/notification_settings_test.dart`

**Interfaces:**

- Produces (used by Tasks 5 and 6): `class NotificationSettings extends ChangeNotifier` with `NotificationSettings({SharedPreferencesAsync? prefs})`, `bool get enabled` (default true), `bool get permissionAsked` (default false), `bool get permissionDenied` (default false), `Future<void> load()`, `Future<void> setEnabled(bool value)`, `Future<void> recordPermission({required bool granted})`.

- [ ] **Step 1: Write the failing tests**

Create `test/notification_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/notifications/notification_settings.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<NotificationSettings> relaunch() async {
    final settings = NotificationSettings();
    await settings.load();
    return settings;
  }

  test('starts on, not asked, not denied', () async {
    final settings = await relaunch();

    expect(settings.enabled, isTrue);
    expect(settings.permissionAsked, isFalse);
    expect(settings.permissionDenied, isFalse);
  });

  test('keeps the switch across launches', () async {
    await NotificationSettings().setEnabled(false);

    expect((await relaunch()).enabled, isFalse);
  });

  test('turning it back on is remembered too', () async {
    final settings = NotificationSettings();
    await settings.setEnabled(false);
    await settings.setEnabled(true);

    expect((await relaunch()).enabled, isTrue);
  });

  test('a granted permission is remembered as asked, not denied', () async {
    await NotificationSettings().recordPermission(granted: true);

    final settings = await relaunch();
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isFalse);
  });

  test('a denied permission is remembered as asked and denied', () async {
    await NotificationSettings().recordPermission(granted: false);

    final settings = await relaunch();
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isTrue);
  });

  test('a later grant clears an earlier denial', () async {
    final settings = NotificationSettings();
    await settings.recordPermission(granted: false);
    await settings.recordPermission(granted: true);

    expect((await relaunch()).permissionDenied, isFalse);
  });

  test('listeners hear about a change', () async {
    final settings = NotificationSettings();
    var heard = 0;
    settings.addListener(() => heard++);

    await settings.setEnabled(false);

    expect(heard, 1);
  });

  test('loading does not undo a change made while it was reading', () async {
    await NotificationSettings().setEnabled(true);
    final settings = NotificationSettings();

    final loading = settings.load();
    await settings.setEnabled(false);
    await loading;

    expect(settings.enabled, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/notification_settings_test.dart`
Expected: compile error, `notification_settings.dart` not found.

- [ ] **Step 3: Implement**

Create `lib/src/notifications/notification_settings.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsEnabledKey = 'hermes.notifications_enabled';
const _prefsAskedKey = 'hermes.notifications_permission_asked';
const _prefsDeniedKey = 'hermes.notifications_permission_denied';

/// Whether the user wants notifications, and what the system said when the
/// app asked for permission. Kept across launches.
class NotificationSettings extends ChangeNotifier {
  NotificationSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  bool _enabled = true;
  bool _asked = false;
  bool _denied = false;
  int _edits = 0;
  Future<void> _lastWrite = Future.value();

  bool get enabled => _enabled;
  bool get permissionAsked => _asked;
  bool get permissionDenied => _denied;

  Future<void> load() async {
    final editsBefore = _edits;
    final enabled = await _prefs.getBool(_prefsEnabledKey);
    final asked = await _prefs.getBool(_prefsAskedKey);
    final denied = await _prefs.getBool(_prefsDeniedKey);
    if (_edits != editsBefore) return;
    _enabled = enabled ?? true;
    _asked = asked ?? false;
    _denied = denied ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) => _change(
    () => _enabled = value,
    {_prefsEnabledKey: value},
  );

  Future<void> recordPermission({required bool granted}) => _change(
    () {
      _asked = true;
      _denied = !granted;
    },
    {_prefsAskedKey: true, _prefsDeniedKey: !granted},
  );

  Future<void> _change(void Function() apply, Map<String, bool> values) {
    _edits++;
    apply();
    notifyListeners();
    return _lastWrite = _lastWrite.catchError((_) {}).then((_) async {
      for (final entry in values.entries) {
        await _prefs.setBool(entry.key, entry.value);
      }
    });
  }
}
```

- [ ] **Step 4: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/notification_settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(notifications): remember the switch and the permission answer"
```

---

### Task 3: The notification service

**Files:**

- Modify: `pubspec.yaml`, `pubspec.lock`
- Create: `lib/src/notifications/notification_service.dart`
- Create: `lib/src/notifications/local_notification_service.dart`
- Create: `test/support/fake_notification_service.dart`
- Test: `test/local_notification_service_test.dart`

**Interfaces:**

- Consumes: `AttentionNotification` (Task 1).
- Produces (used by Tasks 5 and 6):
  - `abstract interface class NotificationService { Future<bool> requestPermission(); Future<void> show(AttentionNotification notification); Stream<String> get taps; Future<String?> launchThreadId(); Future<void> dispose(); }` `taps` emits thread ids. `requestPermission` returns false when denied or unsupported. `show` never throws. `launchThreadId` is the thread of the notification whose tap started the app, or null.
  - `LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])`.
  - Top-level helpers `String? threadIdFromResponse(NotificationResponse response)` and `int notificationIdFor(String threadId)` (stable, non-negative).
  - `FakeNotificationService({bool permission = true, String? launchThread})` with `shown` (`List<AttentionNotification>`), `permissionRequests` (`int`), `void tap(String threadId)`, and a settable `permission`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add flutter_local_notifications`
Expected: it resolves against `sdk: ^3.13.4` and the existing `dependency_overrides` and adds the package under `dependencies:`. If resolution fails, stop and report the exact error.

Then read the installed version's README for the exact API: `ls ~/.pub-cache/hosted/pub.dev | grep flutter_local_notifications` and open `README.md` and the `initialize` / `show` signatures in `lib/src/flutter_local_notifications_plugin.dart`. Some versions take positional arguments, newer ones named (`initialize(settings: ...)`, `show(id: ..., title: ..., ...)`). The code below uses the named form; adjust it to the installed version if `flutter analyze` complains.

- [ ] **Step 2: Write the failing tests**

Create `test/local_notification_service_test.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/notifications/local_notification_service.dart';

NotificationResponse _response(String? payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
);

void main() {
  group('threadIdFromResponse', () {
    test('is the payload', () {
      expect(threadIdFromResponse(_response('s1')), 's1');
    });

    test('is null without a payload', () {
      expect(threadIdFromResponse(_response(null)), isNull);
    });

    test('is null for an empty payload', () {
      expect(threadIdFromResponse(_response('')), isNull);
    });
  });

  group('notificationIdFor', () {
    test('is the same for the same thread', () {
      expect(notificationIdFor('s1'), notificationIdFor('s1'));
    });

    test('is never negative', () {
      for (final id in ['s1', 's2', 'a-long-thread-id-1234567890', '']) {
        expect(notificationIdFor(id), greaterThanOrEqualTo(0));
      }
    });

    test('differs between threads', () {
      expect(notificationIdFor('s1'), isNot(notificationIdFor('s2')));
    });
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/local_notification_service_test.dart`
Expected: compile error, `local_notification_service.dart` not found.

- [ ] **Step 4: Create the interface**

`lib/src/notifications/notification_service.dart`:

```dart
import 'attention_policy.dart';

/// Posts local notifications and reports when the user taps one.
abstract interface class NotificationService {
  /// Asks the system for permission to post. Returns false when it was
  /// denied, or when this platform cannot post notifications.
  Future<bool> requestPermission();

  /// Posts [notification], replacing an earlier one for the same thread.
  /// Never throws: a notification that cannot be shown is dropped.
  Future<void> show(AttentionNotification notification);

  /// The thread ids of notifications the user tapped while the app ran.
  Stream<String> get taps;

  /// The thread of the notification whose tap started the app, if one did.
  Future<String?> launchThreadId();

  Future<void> dispose();
}
```

- [ ] **Step 5: Implement the plugin-backed service**

`lib/src/notifications/local_notification_service.dart`:

```dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'attention_policy.dart';
import 'notification_service.dart';

const _channelId = 'agent_activity';
const _channelName = 'Agent activity';

/// The thread a tapped notification was posted for.
String? threadIdFromResponse(NotificationResponse response) {
  final payload = response.payload;
  return payload == null || payload.isEmpty ? null : payload;
}

/// One id per thread, so a new notification replaces the earlier one.
int notificationIdFor(String threadId) => threadId.hashCode & 0x7fffffff;

/// [NotificationService] on `flutter_local_notifications`. On platforms other
/// than macOS, iOS and Android it does nothing.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _initialized;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _initialize() => _initialized ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: (response) {
      final threadId = threadIdFromResponse(response);
      if (threadId != null) _taps.add(threadId);
    },
  );

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _initialize();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (mac != null) {
        return await mac.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> show(AttentionNotification notification) async {
    if (!_supported) return;
    try {
      await _initialize();
      await _plugin.show(
        id: notificationIdFor(notification.threadId),
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Replies and requests from Hermes',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        payload: notification.threadId,
      );
    } on Object {
      return;
    }
  }

  @override
  Future<String?> launchThreadId() async {
    if (!_supported) return null;
    try {
      await _initialize();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final response = details.notificationResponse;
      return response == null ? null : threadIdFromResponse(response);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> dispose() => _taps.close();
}
```

- [ ] **Step 6: Create the fake for later tasks**

`test/support/fake_notification_service.dart`:

```dart
import 'dart:async';

import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';

/// A [NotificationService] the test drives by hand: every notification is
/// recorded, and a tap is simulated with [tap].
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permission = true, this.launchThread});

  /// What [requestPermission] answers.
  bool permission;

  /// The thread whose notification started the app, if any.
  String? launchThread;

  final shown = <AttentionNotification>[];
  var permissionRequests = 0;
  final _taps = StreamController<String>.broadcast();

  void tap(String threadId) => _taps.add(threadId);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> show(AttentionNotification notification) async =>
      shown.add(notification);

  @override
  Future<String?> launchThreadId() async => launchThread;

  @override
  Future<void> dispose() => _taps.close();
}
```

- [ ] **Step 7: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/local_notification_service_test.dart`
Expected: analyze clean; tests PASS. Then run the full suite once: `flutter test`. Expected: PASS (nothing else uses the new files yet).

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib test
git commit -m "feat(notifications): a service that posts local notifications"
```

---

### Task 4: Platform setup

**Files:**

- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts` (only if the plugin's README for the installed version requires it)
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `macos/Runner/AppDelegate.swift`
- Modify: `ios/Podfile.lock`, `macos/Podfile.lock` (as the builds update them)

**Interfaces:**

- Consumes: the `flutter_local_notifications` dependency (Task 3).
- Produces: builds that still succeed with the plugin, and a native side that can show notifications while the app is in the foreground.

This task has no unit test: the change is native configuration. The check is that all three platform builds succeed, as CI does.

- [ ] **Step 1: Read the installed plugin's setup notes**

Open the `README.md` of the installed `flutter_local_notifications` (path from Task 3, Step 1), the Android, iOS and macOS setup sections. Note whether it requires core library desugaring on Android and which delegate lines the two AppDelegates need. Follow the installed version's README where it differs from the steps below.

- [ ] **Step 2: Android**

In `android/app/src/main/AndroidManifest.xml`, next to the `INTERNET` permission add:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

If the README requires core library desugaring, in `android/app/build.gradle.kts` add `isCoreLibraryDesugaringEnabled = true` inside `compileOptions`, and add at the end of the file:

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

(Use the desugar library version the README names.)

- [ ] **Step 3: iOS**

In `ios/Runner/AppDelegate.swift`, add `import UserNotifications` and, at the start of `application(_:didFinishLaunchingWithOptions:)` before the `super` call:

```swift
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
```

- [ ] **Step 4: macOS**

In `macos/Runner/AppDelegate.swift`, add `import UserNotifications` and, at the start of `applicationDidFinishLaunching(_:)`:

```swift
        UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
```

If the README for macOS says the plugin sets the delegate itself, keep only what it asks for.

- [ ] **Step 5: Build every platform**

Run, and expect success from each:

```bash
flutter build macos --debug
flutter build ios --simulator --debug --no-codesign
flutter build apk --debug
```

If a toolchain is missing on this machine (for example no Android SDK), say which build was not run and rely on CI for it. Do not skip macOS: it is the platform for the manual check in Task 7. Fix any build error (desugaring, minimum SDK, pod install) by following the README, and note what was needed in the report.

- [ ] **Step 6: Commit**

```bash
git add android ios macos
git commit -m "build(notifications): set up the notification plugin on macOS, iOS and Android"
```

---

### Task 5: Chat screen integration

**Files:**

- Modify: `lib/src/chat/chat_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/support/pump_chat.dart`
- Test: `test/chat_notifications_test.dart`

**Interfaces:**

- Consumes: `attentionFor` (Task 1), `NotificationSettings` (Task 2), `NotificationService` and `FakeNotificationService` (Task 3).
- Produces: the screen looks up `NotificationService` and `NotificationSettings` from the widget tree if they exist (both optional: without them nothing changes, so existing screen tests keep working); `pumpChatScreen(..., providers: [...])` takes extra providers.

Behaviour to build:

- App focus comes from `AppLifecycleState`; only `resumed` (or no state known yet) is focused.
- `_onReplyEvent` asks the policy after handling the event and shows what it returns.
- Right after the first send that goes through a transport, permission is requested once: only when settings exist, the switch is on and `permissionAsked` is false; the answer is recorded with `recordPermission`. A second send while the first request is still open does not ask again.
- A tap on a notification selects that thread if the screen has it.
- A notification tap that started the app selects that thread once the first page of threads has loaded, if it is in the list.

- [ ] **Step 1: Let the pump helper take providers**

In `test/support/pump_chat.dart`, add the import `import 'package:provider/single_child_widget.dart';`, a parameter `List<SingleChildWidget> providers = const [],` to `pumpChatScreen`, and spread it into the `MultiProvider` list after the two existing providers: `...providers,`.

- [ ] **Step 2: Write the failing tests**

Create `test/chat_notifications_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/pump_chat.dart';

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late FakeNotificationService service;
  late NotificationSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    service = FakeNotificationService();
    settings = NotificationSettings();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [
          messageRow(id: 2, role: 'user', content: 'Draft the notes.'),
        ]),
      );
  });

  Future<void> pump(WidgetTester tester) => pumpChatScreen(
    tester,
    server: server,
    transport: transport,
    providers: [
      ChangeNotifierProvider<NotificationSettings>.value(value: settings),
      Provider<NotificationService>.value(value: service),
    ],
  );

  Future<FakeSend> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    return transport.sends.last;
  }

  void leaveTheApp(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
  }

  Future<void> finish(WidgetTester tester, FakeSend turn, String text) async {
    turn.emit(ReplyCompleted(text));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String? selected(WidgetTester tester) =>
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId;

  testWidgets('a reply that finishes while the app is away is announced', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');

    final n = service.shown.single;
    expect(n.threadId, 's1');
    expect(n.title, 'Run failure');
    expect(n.body, 'Nothing new.');
  });

  testWidgets('nothing is said while the app is focused on that thread', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown, isEmpty);
  });

  testWidgets('a reply for a thread you are not looking at is announced', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Release notes'),
      ),
    );
    await tester.pump();

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown.single.threadId, 's1');
  });

  testWidgets('an approval is announced without its command', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'Clean up');
    leaveTheApp(tester);

    turn.emit(const ApprovalRequested(_approval));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown.single.body, kApprovalBody);
  });

  testWidgets('a clarify question is announced generically', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'Ask me');
    leaveTheApp(tester);

    turn.emit(
      const ClarifyRequested(
        ClarifyRequest(
          requestId: 'r2',
          questions: [ClarifyQuestion(qid: '', question: 'Which colour?')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown.single.body, kQuestionBody);
  });

  testWidgets('nothing is said when notifications are off', (tester) async {
    await settings.setEnabled(false);
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown, isEmpty);
  });

  testWidgets('permission is asked once, after the first send', (tester) async {
    await pump(tester);
    expect(service.permissionRequests, 0);

    await send(tester, 'One');
    await send(tester, 'Two');
    await tester.pump();

    expect(service.permissionRequests, 1);
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a refusal is remembered', (tester) async {
    service.permission = false;
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(settings.permissionDenied, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('permission is not asked when notifications are off', (
    tester,
  ) async {
    await settings.setEnabled(false);
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(service.permissionRequests, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('permission is not asked again once it was asked', (
    tester,
  ) async {
    await settings.recordPermission(granted: true);
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(service.permissionRequests, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping a notification opens its thread', (tester) async {
    await pump(tester);
    expect(selected(tester), 's1');

    service.tap('s2');
    await tester.pump();

    expect(selected(tester), 's2');
  });

  testWidgets('a tap for a thread that is not listed changes nothing', (
    tester,
  ) async {
    await pump(tester);

    service.tap('gone');
    await tester.pump();

    expect(selected(tester), 's1');
  });

  testWidgets('a notification that started the app opens its thread', (
    tester,
  ) async {
    service.launchThread = 's2';

    await pump(tester);

    expect(selected(tester), 's2');
  });

  testWidgets('a launch thread that is not listed falls back to the first', (
    tester,
  ) async {
    service.launchThread = 'gone';

    await pump(tester);

    expect(selected(tester), 's1');
  });
}
```

Note: if `FakeSend` is not exported by `support/fake_chat_transport.dart` under that name, use the class name defined there (it is `FakeSend`).

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/chat_notifications_test.dart`
Expected: the notification assertions FAIL (`service.shown` empty, `permissionRequests` 0, taps ignored). If the file does not compile, fix the test helper imports first.

- [ ] **Step 4: Implement in `chat_screen.dart`**

Add imports: `import '../notifications/attention_policy.dart';`, `import '../notifications/notification_service.dart';`, `import '../notifications/notification_settings.dart';`.

Change the state class declaration to `class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {`.

Add fields next to the other state fields:

```dart
  NotificationService? _notifications;
  NotificationSettings? _notificationSettings;
  StreamSubscription<String>? _notificationTaps;
  Future<String?>? _launchLookup;
  var _focused = true;
  var _askingPermission = false;
```

Add a helper (near `_showMessage`):

```dart
  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
```

In `initState`, right after `super.initState();` add:

```dart
    _notifications = _maybeRead<NotificationService>();
    _notificationSettings = _maybeRead<NotificationSettings>();
    _launchLookup = _notifications?.launchThreadId();
    _notificationTaps = _notifications?.taps.listen(_openFromNotification);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _focused = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
```

In `dispose`, before `super.dispose()`: `WidgetsBinding.instance.removeObserver(this);` and `_notificationTaps?.cancel();`.

Add the lifecycle and tap handlers:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _focused = state == AppLifecycleState.resumed;
  }

  void _openFromNotification(String threadId) {
    if (_threads.any((t) => t.id == threadId)) _selectThread(threadId);
  }
```

In `_loadThreads`, right after `final first = await _repository!.loadThreadPage(profile: profile);` add:

```dart
      final launchId = await _launchLookup;
      _launchLookup = null;
```

and replace `_selectedId = threads.isNotEmpty ? threads.first.id : null;` inside the `setState` with:

```dart
        _selectedId = threads.any((t) => t.id == launchId)
            ? launchId
            : (threads.isNotEmpty ? threads.first.id : null);
```

Add the announce and permission methods (near `_onReplyEvent`):

```dart
  void _announce(ChatThread thread, ChatEvent event) {
    final service = _notifications;
    if (service == null) return;
    final notification = attentionFor(
      event: event,
      thread: thread,
      appFocused: _focused,
      selectedThreadId: _selectedId,
      enabled: _notificationSettings?.enabled ?? true,
    );
    if (notification != null) unawaited(service.show(notification));
  }

  Future<void> _askForNotificationPermission() async {
    final service = _notifications;
    final settings = _notificationSettings;
    if (service == null || settings == null) return;
    if (!settings.enabled || settings.permissionAsked || _askingPermission) {
      return;
    }
    _askingPermission = true;
    try {
      final granted = await service.requestPermission();
      await settings.recordPermission(granted: granted);
    } finally {
      _askingPermission = false;
    }
  }
```

At the end of `_onReplyEvent` (after the `switch`), add `_announce(thread, event);`.

In `_send`, in the `else` branch that calls `_streamReply(...)`, add after it: `unawaited(_askForNotificationPermission());`.

- [ ] **Step 5: Provide the settings and the service**

In `lib/main.dart` add imports for `src/notifications/local_notification_service.dart`, `src/notifications/notification_service.dart` and `src/notifications/notification_settings.dart`, and add to the `providers` list after the `ThemeController` entry:

```dart
        ChangeNotifierProvider(create: (_) => NotificationSettings()..load()),
        Provider<NotificationService>(
          create: (_) => LocalNotificationService(),
          dispose: (_, service) => service.dispose(),
        ),
```

- [ ] **Step 6: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/chat_notifications_test.dart`
Expected: PASS. Then the full suite: `flutter test`. Expected: PASS (screens without the providers behave as before).

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat(notifications): announce replies and requests from the chat screen"
```

---

### Task 6: The Notifications setting

**Files:**

- Create: `lib/src/notifications/notifications_dialog.dart`
- Modify: `lib/src/chat/widgets/thread_sidebar.dart`
- Modify: `PRIVACY.md`
- Test: `test/notifications_setting_test.dart`

**Interfaces:**

- Consumes: `NotificationSettings` (Task 2), provided in the widget tree.
- Produces: `Future<void> showNotificationsDialog(BuildContext context)`; a "Notifications" entry in the account menu.

- [ ] **Step 1: Write the failing tests**

Create `test/notifications_setting_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_share_inbox.dart';

void main() {
  late NotificationSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = NotificationSettings();
  });

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
  }

  testWidgets('the account menu opens the dialog with the switch on', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('the dialog says alerts need the app to be running', (
    tester,
  ) async {
    await openDialog(tester);

    expect(
      find.text(
        'Alerts arrive while Hermes is running, including for a short time '
        'after you leave it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('flipping the switch turns notifications off', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(settings.enabled, isFalse);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
  });

  testWidgets('a denied permission points to system settings', (tester) async {
    await settings.recordPermission(granted: false);

    await openDialog(tester);

    expect(
      find.text('Turn on notifications for Hermes in system settings.'),
      findsOneWidget,
    );
  });

  testWidgets('no permission hint when nothing was denied', (tester) async {
    await openDialog(tester);

    expect(
      find.text('Turn on notifications for Hermes in system settings.'),
      findsNothing,
    );
  });

  testWidgets('no permission hint while the switch is off', (tester) async {
    await settings.recordPermission(granted: false);
    await settings.setEnabled(false);

    await openDialog(tester);

    expect(
      find.text('Turn on notifications for Hermes in system settings.'),
      findsNothing,
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/notifications_setting_test.dart`
Expected: FAIL, no 'Notifications' menu entry.

- [ ] **Step 3: Implement the dialog**

Create `lib/src/notifications/notifications_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/hermes_theme.dart';
import 'notification_settings.dart';

Future<void> showNotificationsDialog(BuildContext context) {
  final settings = context.read<NotificationSettings>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: const _NotificationsDialog(),
    ),
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NotificationSettings>();
    final subtle = context.hermesColors.subtleText;
    final note = TextStyle(fontSize: 12.5, color: subtle);
    return SimpleDialog(
      title: const Text('Notifications'),
      children: [
        SwitchListTile(
          title: const Text('Notify me'),
          subtitle: const Text(
            'When a reply finishes or Hermes needs you, while the app is not '
            'in front.',
          ),
          value: settings.enabled,
          onChanged: (value) => settings.setEnabled(value),
        ),
        if (settings.enabled && settings.permissionDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(
              'Turn on notifications for Hermes in system settings.',
              style: note.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(
            'Alerts arrive while Hermes is running, including for a short '
            'time after you leave it.',
            style: note,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add the menu entry**

In `lib/src/chat/widgets/thread_sidebar.dart`, import `../../notifications/notifications_dialog.dart`, add to the `onSelected` handler:

```dart
          if (value == 'notifications') showNotificationsDialog(context);
```

and add, right after the `appearance` item:

```dart
          const PopupMenuItem(
            value: 'notifications',
            child: Text('Notifications'),
          ),
```

- [ ] **Step 5: Update PRIVACY.md**

Under "On your device", add to the list of what the app stores: `- whether notifications are on, and whether you have been asked for permission, in app preferences`. After the list, before "Removing the app deletes this data.", add a paragraph:

```
When a reply finishes while Hermes is in the background, the notification can show the first part of the reply, and so on a lock screen. The text is made and shown on your device and is not sent anywhere. Turn notifications off in the account menu if you do not want that.
```

- [ ] **Step 6: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/notifications_setting_test.dart test/appearance_setting_test.dart`
Expected: PASS. Then `flutter test`. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib test PRIVACY.md
git commit -m "feat(notifications): a Notifications setting in the account menu"
```

---

### Task 7: Check it on macOS

**Files:** none (verification only; commit only if it turns up a fix).

- [ ] **Step 1: Everything green**

Run: `dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`
Expected: all clean, all pass.

- [ ] **Step 2: Try it on macOS**

Use the `verify-in-app` skill to run the app on macOS against a Hermes backend. Real notifications cannot be shown from tests, so this is the only place they are seen. Each real prompt costs model money (see the project memory on the dev backend), so use at most two. Check:

1. After the first send the system asks for notification permission, once.
2. Send a prompt, then switch to another app before the reply arrives: a notification appears with the thread title and the start of the reply. Clicking it brings Hermes forward on that thread.
3. Turn notifications off in the account menu and repeat: nothing appears.

If the model does not produce a reply, an approval or a question on demand, say so and report only what was seen. Do not claim more than was observed.

- [ ] **Step 3: Report**

State what was seen on macOS and what was only covered by tests (iOS and Android are covered by the platform builds only).
