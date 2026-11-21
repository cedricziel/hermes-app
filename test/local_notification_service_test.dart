import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        Directory,
        File,
        InternetAddress,
        InternetAddressType,
        Link,
        ServerSocket,
        SocketException;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_posting.dart';

class _Posted {
  _Posted(this.id, this.title, this.body, this.payload, this.details);

  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final NotificationDetails? details;
}

/// Named like the `dbus` package's exception, which is matched by name.
class DBusServiceUnknownException implements Exception {}

/// Thrown locally by the package when the socket is already closed.
class DBusClosedException implements Exception {}

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final posted = <_Posted>[];
  var initializeCalls = 0;
  Exception? initializeError;
  Completer<void>? initializeHeld;
  Object? showError;
  bool? notificationsEnabled;
  NotificationAppLaunchDetails? launchDetails;
  Object? launchDetailsError;
  DidReceiveNotificationResponseCallback? onResponse;
  DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse;
  InitializationSettings? settings;
  void Function()? duringInitialize;
  Completer<void>? showGate;

  /// One hold per `show`, taken in order; a call past the list is not held.
  final showHolds = <Completer<void>>[];
  var showCalls = 0;
  Completer<void>? activeGate;
  Completer<void>? cancelGate;
  Completer<void>? launchGate;
  void Function()? onResolve;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls++;
    await initializeHeld?.future;
    if (initializeError case final error?) throw error;
    onResponse = onDidReceiveNotificationResponse;
    onBackgroundResponse = onDidReceiveBackgroundNotificationResponse;
    this.settings = settings;
    duringInitialize?.call();
    return true;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    showCalls++;
    if (showError case final error?) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    await showGate?.future;
    if (showHolds.isNotEmpty) await showHolds.removeAt(0).future;
    posted.add(_Posted(id, title, body, payload, notificationDetails));
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    await launchGate?.future;
    if (launchDetailsError case final error?) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    return launchDetails;
  }

  final active = <ActiveNotification>[];
  Object? activeError;
  Exception? cancelError;
  final cancelled = <int>[];
  final cancelledTags = <String?>[];

  /// Like the plugin's Android side: no payload, but the tag.
  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    await activeGate?.future;
    return _active();
  }

  List<ActiveNotification> _active() => [
    if (activeError case final error?)
      Error.throwWithStackTrace(error, StackTrace.current),
    for (final a in active)
      if (defaultTargetPlatform == TargetPlatform.android)
        ActiveNotification(id: a.id, tag: a.tag, title: a.title, body: a.body)
      else
        a,
  ];

  @override
  Future<void> cancel({required int id, String? tag}) async {
    await cancelGate?.future;
    if (cancelError case final error?) throw error;
    cancelled.add(id);
    cancelledTags.add(tag);
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      onResolve?.call();
      return _AndroidPermission(notificationsEnabled) as T;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AndroidPermission extends AndroidFlutterLocalNotificationsPlugin {
  _AndroidPermission(this.enabled);

  final bool? enabled;

  @override
  Future<bool?> areNotificationsEnabled() async => enabled;
}

class _LegacyNotifications implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingPoster implements NotificationService, NotificationPoster {
  @override
  Future<NotificationPostResult> post(
    AttentionNotification notification,
  ) async => throw StateError('private command');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationResponse _response(String? payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
);

NotificationResponse _action(
  String? payload,
  String actionId, [
  String? input,
]) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotificationAction,
  payload: payload,
  actionId: actionId,
  input: input,
);

AttentionNotification _request(InputRequest request) => attentionFor(
  event: switch (request) {
    ApprovalRequest() => ApprovalRequested(request),
    ClarifyRequest() => ClarifyRequested(request),
    _ => throw ArgumentError(request),
  },
  thread: ChatThread(id: 's1', title: 'Cleanup', updatedAt: DateTime(2026)),
  appFocused: false,
  selectedThreadId: null,
  enabled: true,
  profile: 'work',
)!;

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: '',
  choices: ['once', 'deny'],
);

const _question = ClarifyRequest(
  requestId: 'r2',
  batch: true,
  questions: [
    ClarifyQuestion(qid: 'q1', question: 'Which?', choices: ['a', 'b']),
  ],
);

void main() {
  group('posting compatibility', () {
    test('legacy services cannot establish OS acceptance', () async {
      final NotificationService service = _LegacyNotifications();

      final result = await service.post(_request(_approval));

      expect(result.status, NotificationPostStatus.unsupported);
    });

    test('a throwing poster reports only its error type', () async {
      final NotificationService service = _ThrowingPoster();

      final result = await service.post(_request(_approval));

      expect(result.status, NotificationPostStatus.failed);
      expect(result.errorType, 'StateError');
    });
  });

  group('targetFromResponse', () {
    NotificationTarget? roundTrip(NotificationTarget target) =>
        targetFromResponse(_response(encodeTarget(target)));

    test('round-trips a thread and its profile', () {
      final target = roundTrip(
        const NotificationTarget(threadId: 's1', profile: 'work'),
      )!;

      expect(target.threadId, 's1');
      expect(target.profile, 'work');
    });

    test('round-trips a message from Hermes and the summary', () {
      final message = roundTrip(
        const NotificationTarget.message(
          threadId: 'hermes-app-1',
          profile: 'w',
        ),
      )!;
      expect(message.isMessage, isTrue);
      expect(message.threadId, 'hermes-app-1');
      expect(message.profile, 'w');

      final summary = roundTrip(const NotificationTarget.messages())!;
      expect(summary.isMessageSummary, isTrue);
    });

    test('round-trips a thread without a profile', () {
      final target = roundTrip(const NotificationTarget(threadId: 's1'))!;

      expect(target.threadId, 's1');
      expect(target.profile, isNull);
    });

    test('leaves the profile out of the payload when there is none', () {
      expect(
        jsonDecode(encodeTarget(const NotificationTarget(threadId: 's1'))),
        {'t': 's1'},
      );
    });

    test('round-trips a scheduled task and its profile', () {
      final target = roundTrip(
        const NotificationTarget.job(jobId: 'j1', profile: 'work'),
      )!;

      expect(target.isJob, isTrue);
      expect(target.jobId, 'j1');
      expect(target.profile, 'work');
      expect(target.threadId, isEmpty);
    });

    test('writes a scheduled task without a thread', () {
      expect(
        jsonDecode(
          encodeTarget(const NotificationTarget.job(jobId: 'j1', profile: 'w')),
        ),
        {'j': 'j1', 'p': 'w'},
      );
    });

    test('a chat payload is still a chat', () {
      expect(
        roundTrip(const NotificationTarget(threadId: 's1'))!.isJob,
        isFalse,
      );
    });

    test('reads a plain thread id posted by an earlier build', () {
      final target = targetFromResponse(_response('s1'))!;

      expect(target.threadId, 's1');
      expect(target.profile, isNull);
    });

    test('reads a plain id that happens to be valid JSON', () {
      expect(targetFromResponse(_response('123'))!.threadId, '123');
      expect(targetFromResponse(_response('{"x":1}'))!.threadId, '{"x":1}');
    });

    test('reads a plain id that is not JSON at all', () {
      expect(targetFromResponse(_response('{oops'))!.threadId, '{oops');
    });

    test('is null without a payload', () {
      expect(targetFromResponse(_response(null)), isNull);
    });

    test('is null for an empty payload', () {
      expect(targetFromResponse(_response('')), isNull);
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

    test('is pinned to FNV-1a, so it survives a Dart upgrade', () {
      expect(notificationIdFor('s1'), 139573449);
      expect(notificationIdFor('s2'), 89240592);
      expect(notificationIdFor(''), 18652613);
      expect(notificationIdFor('a-long-thread-id-1234567890'), 1825842500);
    });

    test('fits a signed 32-bit int for a long thread id', () {
      expect(notificationIdFor('x' * 10000), lessThanOrEqualTo(0x7fffffff));
    });

    test('differs between threads', () {
      expect(notificationIdFor('s1'), isNot(notificationIdFor('s2')));
    });

    test('is unchanged by a null profile', () {
      expect(notificationIdFor('s1', profile: null), 139573449);
    });

    test('differs between profiles that hold the same thread id', () {
      final work = notificationIdFor('s1', profile: 'work');
      final home = notificationIdFor('s1', profile: 'home');

      expect(work, isNot(home));
      expect(work, isNot(notificationIdFor('s1')));
      expect(work, greaterThanOrEqualTo(0));
      expect(work, lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('requestPermission', () {
    test('is unavailable, not denied, when the plugin cannot answer', () async {
      final service = LocalNotificationService();
      addTearDown(service.dispose);

      expect(
        await service.requestPermission(),
        NotificationPermission.unavailable,
      );
    });
  });

  group('LocalNotificationService', () {
    late _FakePlugin plugin;
    late LocalNotificationService service;
    late List<List<String>> registered;

    setUp(() {
      plugin = _FakePlugin();
      registered = [];
      service = LocalNotificationService(
        plugin: plugin,
        registerCategories: (categories) async =>
            registered.add([for (final c in categories) c.id]),
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await service.dispose();
    });

    test('a refused caller does not initialize or post', () async {
      await service.showWhile(
        const AttentionNotification(
          threadId: 's1',
          title: 'Update',
          body: 'Done',
        ),
        () => false,
      );

      expect(plugin.initializeCalls, 0);
      expect(plugin.posted, isEmpty);
    });

    test(
      'revoked authorization during initialization prevents posting',
      () async {
        plugin.initializeHeld = Completer<void>();
        var allowed = true;
        final pending = service.showWhile(
          const AttentionNotification(
            threadId: 's1',
            title: 'Update',
            body: 'Done',
          ),
          () => allowed,
        );
        expect(plugin.initializeCalls, 1);
        allowed = false;
        plugin.initializeHeld!.complete();
        await pending;

        expect(plugin.posted, isEmpty);
      },
    );

    test(
      'revoked authorization during category registration prevents posting',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final held = Completer<void>();
        final started = Completer<void>();
        final guarded = LocalNotificationService(
          plugin: plugin,
          registerCategories: (categories) async {
            if (categories.any((category) => category.isDynamic)) {
              started.complete();
              await held.future;
            }
          },
        );
        addTearDown(guarded.dispose);
        var allowed = true;
        final pending = guarded.showWhile(_request(_question), () => allowed);
        await started.future;
        allowed = false;
        held.complete();
        await pending;
        expect(plugin.posted, isEmpty);
      },
    );

    test('posts a chat under its thread and profile', () async {
      await service.show(
        const AttentionNotification(
          threadId: 's1',
          profile: 'work',
          title: 'Hermes replied',
          body: 'Done.',
        ),
      );

      final posted = plugin.posted.single;
      expect(posted.id, notificationIdFor('s1', profile: 'work'));
      expect(posted.title, 'Hermes replied');
      expect(posted.body, 'Done.');
      final target = targetFromResponse(_response(posted.payload))!;
      expect(target.isJob, isFalse);
      expect(target.threadId, 's1');
      expect(target.profile, 'work');
    });

    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      test('posts plain Markdown previews on $platform', () async {
        debugDefaultTargetPlatformOverride = platform;
        await service.show(
          const AttentionNotification(
            threadId: 's1',
            title: 'Update',
            body: '**Done**\n\n- [Docs](https://example.com)\n- *Next*',
          ),
        );
        expect(plugin.posted.single.body, 'Done\n\n• Docs\n• Next');
      });
    }

    test('keeps literal formatting in an already rendered reply', () async {
      await service.show(
        const AttentionNotification(
          threadId: 's1',
          title: 'Update',
          body: '**literal**',
          bodyIsPlainText: true,
        ),
      );
      expect(plugin.posted.single.body, '**literal**');
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      test(
        'reply previews stay readable with a hidden-preview category on $platform',
        () async {
          debugDefaultTargetPlatformOverride = platform;
          await service.show(
            attentionFor(
              event: const ReplyCompleted('**Done** with the update.'),
              thread: ChatThread(
                id: 'preview',
                title: 'Update',
                updatedAt: DateTime(2026),
              ),
              appFocused: false,
              selectedThreadId: null,
              enabled: true,
            )!,
          );
          final note = plugin.posted.single;
          expect(note.body, 'Done with the update.');
          expect(
            note.details?.iOS?.categoryIdentifier,
            platform == TargetPlatform.iOS ? replyReadyCategory.id : null,
          );
          expect(note.details?.iOS?.interruptionLevel, isNull);
        },
      );
    }

    test('posts a scheduled task with a payload that opens the task', () async {
      await service.show(
        const AttentionNotification.job(
          jobId: 'j1',
          profile: 'work',
          title: 'Backup failed',
          body: 'Exit 1',
        ),
      );

      final target = targetFromResponse(
        _response(plugin.posted.single.payload),
      )!;
      expect(target.isJob, isTrue);
      expect(target.jobId, 'j1');
      expect(target.profile, 'work');
    });

    group('presentation', () {
      const reply = AttentionNotification(
        threadId: 's1',
        profile: 'work',
        title: 'Cleanup',
        body: 'Done.',
      );
      const task = AttentionNotification.job(
        jobId: 'j1',
        profile: 'work',
        title: 'Backup',
        body: 'Done',
      );
      final needsInput = attentionFor(
        event: const UnsupportedRequested(
          UnsupportedRequest(requestId: 'r3', kind: UnsupportedKind.secret),
        ),
        thread: ChatThread(
          id: 's1',
          title: 'Cleanup',
          updatedAt: DateTime(2026),
        ),
        appFocused: false,
        selectedThreadId: null,
        enabled: true,
        profile: 'work',
      )!;

      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        group('on $platform', () {
          setUp(() => debugDefaultTargetPlatformOverride = platform);

          DarwinNotificationDetails darwin() {
            final details = plugin.posted.last.details!;
            return platform == TargetPlatform.iOS
                ? details.iOS!
                : details.macOS!;
          }

          test('stacks a chat and a task under their own thread', () async {
            await service.show(reply);
            expect(darwin().threadIdentifier, 'chat:work/s1');
            await service.show(task);
            expect(darwin().threadIdentifier, 'job:work/j1');
          });

          test('leaves a reply and a task at the default level', () async {
            await service.show(reply);
            expect(darwin().interruptionLevel, isNull);
            await service.show(task);
            expect(darwin().interruptionLevel, isNull);
          });

          test('breaks through a Focus for every kind of request', () async {
            final requests = [
              _request(_approval),
              _request(_question),
              needsInput,
              attentionFor(
                event: const ApprovalRequested(_approval),
                thread: ChatThread(
                  id: 's1',
                  title: 'Cleanup',
                  updatedAt: DateTime(2026),
                ),
                appFocused: false,
                selectedThreadId: null,
                enabled: true,
                appLock: true,
              )!,
            ];
            for (final request in requests) {
              await service.show(request);
              expect(
                darwin().interruptionLevel,
                InterruptionLevel.timeSensitive,
              );
            }
          });

          test('keeps the category and the body', () async {
            await service.show(_request(_approval));
            expect(
              darwin().categoryIdentifier,
              'hermes.request.approval.once-deny',
            );
            expect(plugin.posted.last.body, 'rm -rf build');
          });
        });
      }

      test('leaves Android to bundle by itself', () async {
        await service.show(reply);

        expect(plugin.posted.single.details!.android!.groupKey, isNull);
      });

      test('a request replaces the chat\'s reply under the same id', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await service.show(reply);
        await service.show(_request(_approval));

        final [first, second] = plugin.posted;
        expect(second.id, first.id);
        expect(
          second.details!.iOS!.threadIdentifier,
          first.details!.iOS!.threadIdentifier,
        );
      });
    });

    group('a request', () {
      setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

      test('registers the fixed categories at start', () async {
        await service.show(_request(_approval));

        final darwin = plugin.settings!.iOS!.notificationCategories;
        expect(
          darwin.map((c) => c.identifier),
          staticRequestCategories().map((c) => c.id),
        );
        expect(registered.first, staticRequestCategories().map((c) => c.id));
        expect(plugin.onBackgroundResponse, isNotNull);
      });

      test(
        'a background service registers only the category it posts under',
        () async {
          final background = LocalNotificationService(
            plugin: plugin,
            background: true,
            registerCategories: (categories) async =>
                registered.add([for (final c in categories) c.id]),
          );
          addTearDown(background.dispose);
          final note = _request(_approval);

          await background.show(note);

          expect(plugin.settings!.iOS!.notificationCategories, isEmpty);
          expect(registered, [
            [note.category!.id],
          ]);
          expect(
            plugin.posted.single.details!.iOS!.categoryIdentifier,
            note.category!.id,
          );
        },
      );

      test('is posted under its category with the command', () async {
        await service.show(_request(_approval));

        final posted = plugin.posted.single;
        expect(posted.body, 'rm -rf build');
        expect(
          posted.details!.iOS!.categoryIdentifier,
          'hermes.request.approval.once-deny',
        );
      });

      test("registers a question's own category before posting it", () async {
        final note = _request(_question);

        await service.show(note);

        expect(registered.last, [note.category!.id]);
        expect(
          plugin.posted.single.details!.iOS!.categoryIdentifier,
          note.category!.id,
        );
      });

      test('carries what answering it needs', () async {
        await service.show(_request(_approval));

        final answer = answerFromAction(
          plugin.posted.single.payload,
          kAllowOnceAction,
          null,
        )!;
        expect(answer.target.threadId, 's1');
        expect(answer.target.profile, 'work');
        expect(answer.title, 'Cleanup');
        expect(answer.request.requestId, 'r1');
        expect((answer.answer as ApprovalChoiceAnswer).choice, 'once');
        expect(targetFromPayload(plugin.posted.single.payload)!.threadId, 's1');
      });

      test('withdraws the delivered ones that can be answered', () async {
        await service.show(_request(_approval));
        await service.show(
          const AttentionNotification(threadId: 's2', title: 't', body: 'b'),
        );
        plugin.active.addAll([
          for (final posted in plugin.posted)
            ActiveNotification(id: posted.id, payload: posted.payload),
        ]);

        await service.withdrawAnswerable();

        expect(plugin.cancelled, [plugin.posted.first.id]);
      });

      test('withdraws the ones that carry a reply or a draft too', () async {
        plugin.active.addAll([
          for (final (id, fields) in [
            (1, {'t': 's1', 'y': 1, 'n': 'Chat', 'a': 'x'}),
            (2, {'t': 's2', 'u': 'Try again', 'a': 'x'}),
            (3, {'t': 's3'}),
          ])
            ActiveNotification(id: id, payload: jsonEncode(fields)),
        ]);

        await service.withdrawAnswerable();

        expect(plugin.cancelled, [1, 2]);
      });

      test('withdraws the tagged ones on Android, leaves the rest', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await service.show(_request(_approval));
        await service.show(
          const AttentionNotification(threadId: 's2', title: 't', body: 'b'),
        );
        plugin.cancelled.clear();
        plugin.cancelledTags.clear();
        plugin.active.addAll([
          ActiveNotification(id: plugin.posted.first.id, tag: kAnswerableTag),
          ActiveNotification(id: plugin.posted.last.id),
        ]);

        await service.withdrawAnswerable();

        expect(plugin.cancelled, [plugin.posted.first.id]);
        expect(plugin.cancelledTags, [kAnswerableTag]);
      });

      group('on Android', () {
        setUp(
          () => debugDefaultTargetPlatformOverride = TargetPlatform.android,
        );

        test(
          'shows the command, the buttons and no lock screen text',
          () async {
            await service.show(_request(_approval));

            final posted = plugin.posted.single;
            final android = posted.details!.android!;
            expect(posted.body, 'rm -rf build');
            expect(android.visibility, NotificationVisibility.secret);
            expect(android.actions!.map((a) => a.id), [
              kAllowOnceAction,
              kDenyAction,
            ]);
            expect(android.importance, Importance.high);
            expect(android.priority, Priority.high);
          },
        );

        test('tags an answerable notification', () async {
          await service.show(_request(_approval));

          expect(plugin.posted.single.details!.android!.tag, kAnswerableTag);
        });

        test('a reply after a request replaces the tagged one', () async {
          await service.show(_request(_approval));
          final id = plugin.posted.single.id;
          plugin.cancelled.clear();
          plugin.cancelledTags.clear();

          await service.show(
            const AttentionNotification(
              threadId: 's1',
              profile: 'work',
              title: 't',
              body: 'b',
            ),
          );

          expect(plugin.cancelled, [id]);
          expect(plugin.cancelledTags, [kAnswerableTag]);
          expect(plugin.posted.last.details!.android!.tag, isNull);
        });

        test('a request after a reply replaces the untagged one', () async {
          await service.show(
            const AttentionNotification(
              threadId: 's1',
              profile: 'work',
              title: 't',
              body: 'b',
            ),
          );
          plugin.cancelled.clear();
          plugin.cancelledTags.clear();

          await service.show(_request(_approval));

          expect(plugin.cancelled, [plugin.posted.last.id]);
          expect(plugin.cancelledTags, [null]);
        });

        test('stays generic with no buttons for a generic body', () async {
          final note = _request(_approval);
          await service.show(
            AttentionNotification(
              threadId: note.threadId,
              profile: note.profile,
              title: note.title,
              body: kApprovalBody,
              category: note.category,
              request: note.request,
              needsInput: true,
            ),
          );

          final posted = plugin.posted.single;
          expect(posted.body, kApprovalBody);
          expect(posted.details!.android!.actions, isNull);
          expect(posted.details!.android!.tag, isNull);
          expect(posted.details!.android!.visibility, isNull);
        });

        test('shows a question with its buttons', () async {
          await service.show(_request(_question));

          final android = plugin.posted.single.details!.android!;
          expect(plugin.posted.single.body, 'Which?');
          expect(android.actions!.map((a) => a.id), [
            '${kChoiceActionPrefix}0',
            '${kChoiceActionPrefix}1',
            kReplyAction,
          ]);
        });

        test('stays generic with no buttons while App Lock is on', () async {
          final locked = attentionFor(
            event: const ApprovalRequested(_approval),
            thread: ChatThread(
              id: 's1',
              title: 'Cleanup',
              updatedAt: DateTime(2026),
            ),
            appFocused: false,
            selectedThreadId: null,
            enabled: true,
            appLock: true,
          )!;

          await service.show(locked);

          final posted = plugin.posted.single;
          expect(posted.body, kApprovalBody);
          expect(posted.details!.android!.actions, isNull);
          expect(posted.details!.android!.visibility, isNull);
        });

        test('stays generic without a known choice', () async {
          await service.show(
            _request(
              const ApprovalRequest(
                requestId: 'r9',
                command: 'rm -rf build',
                description: '',
                choices: ['later'],
              ),
            ),
          );

          final posted = plugin.posted.single;
          expect(posted.body, kApprovalBody);
          expect(posted.details!.android!.actions, isNull);
          expect(posted.details!.android!.visibility, isNull);
        });

        test('takes background button responses unless it is one', () async {
          await service.show(_request(_approval));
          expect(plugin.onBackgroundResponse, isNotNull);

          final background = _FakePlugin();
          final other = LocalNotificationService(
            plugin: background,
            background: true,
            registerCategories: (_) async {},
          );
          addTearDown(other.dispose);
          await other.show(_request(_approval));
          expect(background.onBackgroundResponse, isNull);
        });

        test('answers from a button', () async {
          await service.show(_request(_question));
          final answered = service.answers.first;

          plugin.onResponse!(
            _action(plugin.posted.single.payload, '${kChoiceActionPrefix}1'),
          );

          expect(((await answered).answer as QuestionAnswer).values, ['b']);
        });
      });

      test('reports an answer button on answers, not taps', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await service.show(_request(_question));
        final taps = <NotificationTarget>[];
        final sub = service.taps.listen(taps.add);
        final answered = service.answers.first;

        plugin.onResponse!(
          _action(plugin.posted.single.payload, '${kChoiceActionPrefix}1'),
        );

        final answer = (await answered).answer as QuestionAnswer;
        expect(answer.values, ['b']);
        await sub.cancel();
        expect(taps, isEmpty);
      });

      test('takes Other… and Open as a tap', () async {
        await service.show(_request(_question));
        final tapped = service.taps.first;

        plugin.onResponse!(_action(plugin.posted.single.payload, kOpenAction));

        expect((await tapped).threadId, 's1');
      });

      test('hands an answer that started the app over only once', () async {
        await service.show(_request(_approval));
        plugin.launchDetails = NotificationAppLaunchDetails(
          true,
          notificationResponse: _action(
            plugin.posted.single.payload,
            kDenyAction,
          ),
        );
        final answers = <NotificationAnswer>[];
        final sub = service.answers.listen(answers.add);
        addTearDown(sub.cancel);

        await service.launchTarget();
        await service.launchTarget();
        await pumpEventQueue();

        expect(answers, hasLength(1));
      });

      test('hands an answer that started the app to answers', () async {
        await service.show(_request(_approval));
        plugin.launchDetails = NotificationAppLaunchDetails(
          true,
          notificationResponse: _action(
            plugin.posted.single.payload,
            kDenyAction,
          ),
        );
        final answered = service.answers.first;

        expect(await service.launchTarget(), isNull);
        expect(
          ((await answered).answer as ApprovalChoiceAnswer).choice,
          'deny',
        );
      });
    });

    test('drops a notification the plugin cannot show', () async {
      plugin.showError = PlatformException(code: 'boom');

      await expectLater(
        service.show(
          const AttentionNotification(threadId: 's1', title: 't', body: 'b'),
        ),
        completes,
      );
    });

    test('reports OS acceptance without claiming presentation', () async {
      final result = await service.post(_request(_approval));

      expect(result.status, NotificationPostStatus.accepted);
      expect(plugin.posted, hasLength(1));
    });

    test('reports native posting failure without error contents', () async {
      plugin.showError = PlatformException(code: 'private-command');

      final result = await service.post(_request(_approval));

      expect(result.status, NotificationPostStatus.failed);
      expect(result.errorType, 'PlatformException');
      expect(plugin.posted, isEmpty);
    });

    test('reports unavailable platform without attempting a post', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      final result = await service.post(_request(_approval));

      expect(result.status, NotificationPostStatus.unsupported);
      expect(plugin.initializeCalls, 0);
      expect(plugin.posted, isEmpty);
    });

    test('reports denied permission without requesting it', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      plugin.notificationsEnabled = false;

      final result = await service.post(_request(_approval));

      expect(result.status, NotificationPostStatus.denied);
      expect(plugin.posted, isEmpty);
    });

    test('initializes the plugin once for several notifications', () async {
      const note = AttentionNotification(threadId: 's1', title: 't', body: 'b');

      await service.show(note);
      await service.show(note);

      expect(plugin.initializeCalls, 1);
      expect(plugin.posted, hasLength(2));
    });

    test('retries initialization after it failed', () async {
      const note = AttentionNotification(threadId: 's1', title: 't', body: 'b');
      plugin.initializeError = PlatformException(code: 'not yet');
      await service.show(note);

      plugin.initializeError = null;
      await service.show(note);

      expect(plugin.initializeCalls, 2);
      expect(plugin.posted, hasLength(1));
    });

    test('reports a tapped notification on taps', () async {
      await service.show(
        const AttentionNotification(
          threadId: 's1',
          profile: 'work',
          title: 't',
          body: 'b',
        ),
      );
      final tapped = service.taps.first;

      plugin.onResponse!(_response(plugin.posted.single.payload));

      final target = await tapped;
      expect(target.threadId, 's1');
      expect(target.profile, 'work');
    });

    test('ignores a tap without a payload', () async {
      await service.show(
        const AttentionNotification(threadId: 's1', title: 't', body: 'b'),
      );
      final taps = <NotificationTarget>[];
      final sub = service.taps.listen(taps.add);

      plugin.onResponse!(_response(null));
      await pumpEventQueue();
      await sub.cancel();

      expect(taps, isEmpty);
    });

    test('launchTarget is the notification that started the app', () async {
      plugin.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: _response(
          encodeTarget(const NotificationTarget.job(jobId: 'j1', profile: 'w')),
        ),
      );

      final target = (await service.launchTarget())!;

      expect(target.jobId, 'j1');
      expect(target.profile, 'w');
    });

    test('launchTarget is null when no notification started the app', () async {
      plugin.launchDetails = NotificationAppLaunchDetails(
        false,
        notificationResponse: _response('s1'),
      );

      expect(await service.launchTarget(), isNull);
    });

    test('launchTarget is null when the plugin fails', () async {
      plugin.launchDetailsError = PlatformException(code: 'boom');

      expect(await service.launchTarget(), isNull);
    });

    test('does nothing on a platform without notifications', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      plugin.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: _response('s1'),
      );

      await service.show(
        const AttentionNotification(threadId: 's1', title: 't', body: 'b'),
      );

      expect(plugin.posted, isEmpty);
      expect(await service.launchTarget(), isNull);
      expect(plugin.initializeCalls, 0);
    });
  });

  group('on Windows and Linux', () {
    late _FakePlugin plugin;
    late LocalNotificationService service;

    setUp(() {
      plugin = _FakePlugin();
      service = LocalNotificationService(
        plugin: plugin,
        registerCategories: (_) async => fail('no categories on a desktop'),
        hasLinuxSessionBus: () => true,
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await service.dispose();
    });

    const reply = AttentionNotification(
      threadId: 's1',
      profile: 'work',
      title: 'Cleanup',
      body: 'Done.',
    );

    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      group('$platform', () {
        setUp(() => debugDefaultTargetPlatformOverride = platform);

        test('posts a reply with the details of its own platform', () async {
          final result = await service.post(reply);

          expect(result.status, NotificationPostStatus.accepted);
          final posted = plugin.posted.single;
          expect(posted.title, 'Cleanup');
          expect(posted.body, 'Done.');
          expect(targetFromPayload(posted.payload)!.threadId, 's1');
          expect(
            platform == TargetPlatform.linux
                ? posted.details!.linux
                : posted.details!.windows,
            isNotNull,
          );
        });

        test('initializes with the settings of its own platform', () async {
          await service.post(reply);

          final settings = plugin.settings!;
          expect(settings.linux!.defaultActionName, isNotEmpty);
          final windows = settings.windows!;
          expect(windows.appName, 'Hermes');
          expect(windows.appUserModelId, 'com.cedricziel.hermesApp');
          expect(
            windows.guid,
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              ),
            ),
          );
          expect(plugin.onBackgroundResponse, isNull);
        });

        test('a request shows the placeholder, never the command', () async {
          await service.post(_request(_approval));

          final posted = plugin.posted.single;
          expect(posted.body, isNot(contains('rm -rf')));
          expect(posted.details!.linux?.actions ?? const [], isEmpty);
          expect(posted.details!.windows?.actions ?? const [], isEmpty);
        });

        test('a tap opens its chat', () async {
          final taps = <NotificationTarget>[];
          service.taps.listen(taps.add);
          await service.post(reply);

          plugin.onResponse!(_response(plugin.posted.single.payload));
          await Future<void>.delayed(Duration.zero);

          expect(taps.single.threadId, 's1');
        });

        test(
          'a tap in the shape the Windows plugin reports opens its chat',
          () async {
            final taps = <NotificationTarget>[];
            service.taps.listen(taps.add);
            await service.post(reply);
            final payload = plugin.posted.single.payload;

            // The Windows plugin sets actionId to the payload for a body tap.
            plugin.onResponse!(
              NotificationResponse(
                notificationResponseType:
                    NotificationResponseType.selectedNotification,
                payload: payload,
                actionId: payload,
              ),
            );
            await Future<void>.delayed(Duration.zero);

            expect(taps.single.threadId, 's1');
          },
        );

        test('a launch by a Windows-shaped tap opens its chat', () async {
          await service.post(reply);
          final payload = plugin.posted.single.payload;
          plugin.launchDetails = NotificationAppLaunchDetails(
            true,
            notificationResponse: NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotification,
              payload: payload,
              actionId: payload,
            ),
          );

          expect((await service.launchTarget())!.threadId, 's1');
        });

        test(
          'withdrawing answerable ones survives a plugin that cannot list',
          () async {
            plugin.activeError = PlatformException(code: 'unpackaged');

            await service.withdrawAnswerable();
          },
        );

        test('withdrawing survives a plugin that cannot cancel', () async {
          plugin.active.add(
            ActiveNotification(
              id: 1,
              payload: notificationPayload(_request(_approval)),
            ),
          );
          plugin.cancelError = PlatformException(code: 'unpackaged');

          await service.withdrawAnswerable();
        });

        test('a plugin that fails to post is reported, not thrown', () async {
          plugin.showError = PlatformException(code: 'no_server');

          final result = await service.post(reply);

          expect(result.status, NotificationPostStatus.failed);
          expect(result.errorType, 'PlatformException');
        });

        test('has no permission to report', () async {
          expect(await service.allowed(), isNull);
          expect(
            await service.requestPermission(),
            NotificationPermission.unavailable,
          );
        });
      });
    }
  });

  group('Linux without a session bus', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    const note = AttentionNotification(
      threadId: 's1',
      profile: 'work',
      title: 'Cleanup',
      body: 'Done.',
    );

    LocalNotificationService serviceWith(
      _FakePlugin plugin, {
      required bool bus,
    }) {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      return LocalNotificationService(
        plugin: plugin,
        registerCategories: (_) async {},
        hasLinuxSessionBus: () => bus,
      );
    }

    test('never initializes the plugin and reports unsupported', () async {
      final plugin = _FakePlugin();
      final service = serviceWith(plugin, bus: false);
      addTearDown(service.dispose);

      final result = await service.post(
        const AttentionNotification(
          threadId: 's1',
          profile: 'work',
          title: 'Cleanup',
          body: 'Done.',
        ),
      );

      expect(result.status, NotificationPostStatus.unsupported);
      expect(plugin.initializeCalls, 0);
      expect(plugin.posted, isEmpty);
      expect(
        await service.requestPermission(),
        NotificationPermission.unavailable,
      );
    });

    test(
      'a bus that fails between initialize and show posts nothing',
      () async {
        late Zone pluginZone;
        final plugin = _FakePlugin()
          ..duringInitialize = () {
            pluginZone = Zone.current;
          }
          // Runs once initialize is done and before show: the bus dies then.
          ..onResolve = () => pluginZone.handleUncaughtError(
            const SocketException('dead bus'),
            StackTrace.current,
          );
        final service = serviceWith(plugin, bus: true);
        addTearDown(service.dispose);

        final result = await service.post(note);

        expect(result.status, NotificationPostStatus.unsupported);
        expect(plugin.posted, isEmpty);
      },
    );

    test('a DBus-named exception ends the bus', () async {
      late Zone pluginZone;
      final plugin = _FakePlugin()
        ..duringInitialize = () {
          pluginZone = Zone.current;
        }
        ..onResolve = () => pluginZone.handleUncaughtError(
          DBusServiceUnknownException(),
          StackTrace.current,
        );
      final service = serviceWith(plugin, bus: true);
      addTearDown(service.dispose);

      expect(
        (await service.post(note)).status,
        NotificationPostStatus.unsupported,
      );
    });

    test('plain string errors of the dbus package end the bus too', () async {
      final plugin = _FakePlugin()
        ..duringInitialize = () {
          final controller = StreamController<int>();
          controller.stream.listen((_) {});
          controller.addError('D-Bus address transport not supported: x');
          unawaited(controller.close());
        };
      final service = serviceWith(plugin, bus: true);
      addTearDown(service.dispose);

      await service.post(note);
      await pumpEventQueue();

      expect(
        (await service.post(note)).status,
        NotificationPostStatus.unsupported,
      );
    });

    test('a FormatException and any String end the bus', () async {
      for (final error in [
        const FormatException(
          'Unable to determine transport of D-Bus address: x',
        ),
        'Invalid D-Bus address family',
        'Failed to resolve host',
      ]) {
        late Zone pluginZone;
        final plugin = _FakePlugin()
          ..duringInitialize = () {
            pluginZone = Zone.current;
          }
          ..onResolve = () =>
              pluginZone.handleUncaughtError(error, StackTrace.current);
        final service = serviceWith(plugin, bus: true);
        addTearDown(service.dispose);

        expect(
          (await service.post(note)).status,
          NotificationPostStatus.unsupported,
          reason: '$error',
        );
      }
    });

    test('an unrelated FormatException reaches the parent zone', () async {
      final uncaught = <Object>[];
      late Zone pluginZone;
      final plugin = _FakePlugin()
        ..duringInitialize = () {
          pluginZone = Zone.current;
        };
      final service = serviceWith(plugin, bus: true);
      addTearDown(service.dispose);

      await runZonedGuarded(() async {
        await service.post(note);
        // What the plugin's storage read does on a corrupt file.
        unawaited(
          pluginZone.run(() => Future<void>(() => jsonDecode('{not json'))),
        );
        await pumpEventQueue();
      }, (error, _) => uncaught.add(error));

      expect(uncaught.single, isA<FormatException>());
      expect(
        (await service.post(note)).status,
        NotificationPostStatus.accepted,
      );
    });

    test('an unrelated TimeoutException reaches the parent zone', () async {
      final uncaught = <Object>[];
      late StreamController<int> controller;
      final plugin = _FakePlugin()
        ..duringInitialize = () {
          controller = StreamController<int>();
          controller.stream.listen((_) {});
        };
      final service = serviceWith(plugin, bus: true);
      addTearDown(service.dispose);

      await runZonedGuarded(() async {
        await service.post(note);
        controller.addError(TimeoutException('something else'));
        await pumpEventQueue();
      }, (error, _) => uncaught.add(error));

      expect(uncaught.single, isA<TimeoutException>());
      expect(
        (await service.post(note)).status,
        NotificationPostStatus.accepted,
      );
      unawaited(controller.close());
    });

    test('no guarded call is retained once it finished', () async {
      final plugin = _FakePlugin();
      final service = serviceWith(plugin, bus: true);
      addTearDown(service.dispose);

      for (var i = 0; i < 20; i++) {
        await service.post(note);
      }
      await service.withdrawAnswerable();

      expect(plugin.posted, hasLength(20));
      expect(service.pendingGuardedCalls, 0);
    });

    test('a D-Bus error raised after initialize ends in unsupported', () async {
      final plugin = _FakePlugin()
        ..duringInitialize = () {
          // What the Linux plugin does: a subscription nobody handles errors on.
          final controller = StreamController<int>();
          controller.stream.listen((_) {});
          controller.addError(const SocketException('no bus'));
          unawaited(controller.close());
        };
      final service = serviceWith(plugin, bus: true);
      addTearDown(service.dispose);
      // The test zone fails the test on an uncaught error.
      await service.post(note);
      await pumpEventQueue();
      final result = await service.post(note);

      expect(result.status, NotificationPostStatus.unsupported);
      expect(plugin.initializeCalls, 1);
    });

    test(
      'an error that is not about the bus reaches the parent zone',
      () async {
        final uncaught = <Object>[];
        late StreamController<int> controller;
        final plugin = _FakePlugin()
          ..duringInitialize = () {
            controller = StreamController<int>();
            controller.stream.listen((_) {});
          };
        final service = serviceWith(plugin, bus: true);
        addTearDown(service.dispose);

        await runZonedGuarded(() async {
          await service.post(note);
          controller.addError(StateError('unknown action'));
          await pumpEventQueue();
        }, (error, _) => uncaught.add(error));

        expect(uncaught.single, isA<StateError>());
        expect(
          (await service.post(note)).status,
          NotificationPostStatus.accepted,
        );
        unawaited(controller.close());
      },
    );

    test(
      'an initialize failure that is not about the bus is retried',
      () async {
        final plugin = _FakePlugin()..initializeError = Exception('other');
        final service = serviceWith(plugin, bus: true);
        addTearDown(service.dispose);

        expect(
          (await service.post(note)).status,
          NotificationPostStatus.failed,
        );
        plugin.initializeError = null;

        expect(
          (await service.post(note)).status,
          NotificationPostStatus.accepted,
        );
      },
    );

    test('a connection that fails while show is pending ends the post', () {
      fakeAsync((async) {
        late StreamController<int> controller;
        final plugin = _FakePlugin()
          ..showGate = Completer<void>()
          ..duringInitialize = () {
            controller = StreamController<int>();
            controller.stream.listen((_) {});
          };
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? result;
        service.post(note).then((r) => result = r);
        async.flushMicrotasks();
        expect(result, isNull);

        // No time passes: only the failure signal can end the post.
        controller.addError(const SocketException('dead bus'));
        async.flushMicrotasks();

        expect(result?.status, NotificationPostStatus.failed);
        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.unsupported);
        unawaited(controller.close());
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test('a first show that never answers latches the bus as failed', () {
      fakeAsync((async) {
        // The real plugin's initialize returns at once, without the bus.
        final plugin = _FakePlugin()..showGate = Completer<void>();
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? result;
        service.post(note).then((r) => result = r);
        async.flushMicrotasks();
        expect(result, isNull);

        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();

        expect(result?.status, NotificationPostStatus.failed);
        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.unsupported);
        expect(plugin.showCalls, 1);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test(
      'a first show that answers after the deadline takes the timeout back',
      () {
        fakeAsync((async) {
          final plugin = _FakePlugin()..showGate = Completer<void>();
          final service = serviceWith(plugin, bus: true);
          NotificationPostResult? result;
          service.post(note).then((r) => result = r);
          async.flushMicrotasks();
          async.elapse(kLinuxCallTimeout);
          async.flushMicrotasks();
          expect(result?.status, NotificationPostStatus.failed);

          // The bus had answered; the plugin's cache write was what was slow.
          plugin.showGate!.complete();
          async.flushMicrotasks();
          plugin.showGate = null;

          NotificationPostResult? next;
          service.post(note).then((r) => next = r);
          async.flushMicrotasks();
          expect(next?.status, NotificationPostStatus.accepted);
          debugDefaultTargetPlatformOverride = null;
        });
      },
    );

    test('a bus failure is not taken back by a later answer', () {
      fakeAsync((async) {
        late Zone pluginZone;
        final plugin = _FakePlugin()
          ..showGate = Completer<void>()
          ..duringInitialize = () {
            pluginZone = Zone.current;
          };
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? result;
        service.post(note).then((r) => result = r);
        async.flushMicrotasks();
        pluginZone.handleUncaughtError(
          const SocketException('dead bus'),
          StackTrace.current,
        );
        async.flushMicrotasks();
        expect(result?.status, NotificationPostStatus.failed);

        plugin.showGate!.complete();
        async.flushMicrotasks();

        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.unsupported);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test('a timeout followed by a bus failure is not taken back either', () {
      fakeAsync((async) {
        late Zone pluginZone;
        final plugin = _FakePlugin()
          ..showGate = Completer<void>()
          ..duringInitialize = () {
            pluginZone = Zone.current;
          };
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? first;
        service.post(note).then((r) => first = r);
        async.flushMicrotasks();
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        expect(first?.status, NotificationPostStatus.failed);
        pluginZone.handleUncaughtError(
          const SocketException('dead bus'),
          StackTrace.current,
        );
        async.flushMicrotasks();

        plugin.showGate!.complete();
        async.flushMicrotasks();

        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.unsupported);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test('an initialize that finishes after the deadline is reused', () {
      fakeAsync((async) {
        final plugin = _FakePlugin()..initializeHeld = Completer<void>();
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? first;
        service.post(note).then((r) => first = r);
        async.flushMicrotasks();
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        expect(first?.status, NotificationPostStatus.failed);

        // A slow disk, not a dead bus: nothing is latched.
        plugin.initializeHeld!.complete();
        async.flushMicrotasks();
        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();

        expect(next?.status, NotificationPostStatus.accepted);
        expect(plugin.initializeCalls, 1);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test('a timeout fails only its own call', () {
      fakeAsync((async) {
        final secondHold = Completer<void>();
        final plugin = _FakePlugin()
          ..showHolds.addAll([Completer<void>(), secondHold]);
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? first;
        service.post(note).then((r) => first = r);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 4));
        NotificationPostResult? second;
        service.post(note).then((r) => second = r);
        async.flushMicrotasks();

        // The first call times out at 5 s; the second is still within its own.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(first?.status, NotificationPostStatus.failed);
        expect(second, isNull);

        secondHold.complete();
        async.flushMicrotasks();
        expect(second?.status, NotificationPostStatus.accepted);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test(
      'a show that fails with DBusClosedException ends the bus for good',
      () {
        fakeAsync((async) {
          final plugin = _FakePlugin()..showError = DBusClosedException();
          final service = serviceWith(plugin, bus: true);
          NotificationPostResult? first;
          service.post(note).then((r) => first = r);
          async.flushMicrotasks();
          expect(first?.status, NotificationPostStatus.failed);

          plugin.showError = null;
          NotificationPostResult? next;
          service.post(note).then((r) => next = r);
          async.flushMicrotasks();

          expect(next?.status, NotificationPostStatus.unsupported);
          expect(plugin.showCalls, 1);
          debugDefaultTargetPlatformOverride = null;
        });
      },
    );

    test('a slow call on a bus that answered before fails only that call', () {
      fakeAsync((async) {
        final plugin = _FakePlugin();
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? first;
        service.post(note).then((r) => first = r);
        async.flushMicrotasks();
        expect(first?.status, NotificationPostStatus.accepted);

        plugin.showGate = Completer<void>();
        NotificationPostResult? slow;
        service.post(note).then((r) => slow = r);
        async.flushMicrotasks();
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        expect(slow?.status, NotificationPostStatus.failed);

        plugin.showGate = null;
        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.accepted);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    /// Runs [start] against a plugin whose call hangs and returns whether it
    /// finished once only the timeout could end it.
    bool endsByTimeout(
      _FakePlugin plugin,
      Future<void> Function(LocalNotificationService service) start,
    ) {
      var finished = false;
      fakeAsync((async) {
        final service = serviceWith(plugin, bus: true);
        start(service).then((_) => finished = true);
        async.flushMicrotasks();
        expect(finished, isFalse);
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        debugDefaultTargetPlatformOverride = null;
      });
      return finished;
    }

    /// A first `show` that hangs after [prime] ran, and whether the bus is
    /// then latched failed: the next post is `unsupported` without a new show.
    void latchesAfter(
      _FakePlugin plugin,
      Future<void> Function(LocalNotificationService service) prime,
    ) {
      fakeAsync((async) {
        final service = serviceWith(plugin, bus: true);
        prime(service);
        async.flushMicrotasks();

        plugin.showGate = Completer<void>();
        NotificationPostResult? result;
        service.post(note).then((r) => result = r);
        async.flushMicrotasks();
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        expect(result?.status, NotificationPostStatus.failed);

        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.unsupported);
        expect(plugin.showCalls, 1);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    test('launch details that fail locally do not prove the bus alive', () {
      latchesAfter(
        _FakePlugin()..launchDetailsError = UnimplementedError(),
        (s) => s.launchTarget(),
      );
    });

    test('a listing that fails locally does not prove the bus alive', () {
      latchesAfter(
        _FakePlugin()..activeError = UnimplementedError(),
        (s) => s.withdrawAnswerable(),
      );
    });

    test('launch details that return do not prove the bus alive', () {
      latchesAfter(_FakePlugin(), (s) => s.launchTarget());
    });

    test('a listing that returns does not prove the bus alive', () {
      latchesAfter(_FakePlugin(), (s) => s.withdrawAnswerable());
    });

    test('a cancel does not prove the bus alive', () {
      final plugin = _FakePlugin();
      plugin.active.add(
        ActiveNotification(
          id: 1,
          payload: notificationPayload(_request(_approval)),
        ),
      );
      latchesAfter(plugin, (s) => s.withdrawAnswerable());
      expect(plugin.cancelled, [1]);
    });

    test('a show that fails locally does not prove the bus alive', () {
      fakeAsync((async) {
        final plugin = _FakePlugin()..showError = Exception('local');
        final service = serviceWith(plugin, bus: true);
        NotificationPostResult? first;
        service.post(note).then((r) => first = r);
        async.flushMicrotasks();
        expect(first?.status, NotificationPostStatus.failed);

        plugin
          ..showError = null
          ..showGate = Completer<void>();
        NotificationPostResult? hung;
        service.post(note).then((r) => hung = r);
        async.flushMicrotasks();
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        expect(hung?.status, NotificationPostStatus.failed);

        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.unsupported);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test(
      'a show that fails with DBusClosedException does not prove the bus alive',
      () {
        fakeAsync((async) {
          final plugin = _FakePlugin()..showError = DBusClosedException();
          final service = serviceWith(plugin, bus: true);
          NotificationPostResult? first;
          service.post(note).then((r) => first = r);
          async.flushMicrotasks();
          expect(first?.status, NotificationPostStatus.failed);

          plugin
            ..showError = null
            ..showGate = Completer<void>();
          service.post(note);
          async.flushMicrotasks();
          async.elapse(kLinuxCallTimeout);
          async.flushMicrotasks();

          NotificationPostResult? next;
          service.post(note).then((r) => next = r);
          async.flushMicrotasks();
          expect(next?.status, NotificationPostStatus.unsupported);
          debugDefaultTargetPlatformOverride = null;
        });
      },
    );

    test('a bus error reply to a show proves the bus alive', () {
      fakeAsync((async) {
        final plugin = _FakePlugin()..showError = DBusServiceUnknownException();
        final service = serviceWith(plugin, bus: true);
        service.post(note);
        async.flushMicrotasks();

        plugin
          ..showError = null
          ..showGate = Completer<void>();
        NotificationPostResult? hung;
        service.post(note).then((r) => hung = r);
        async.flushMicrotasks();
        async.elapse(kLinuxCallTimeout);
        async.flushMicrotasks();
        expect(hung?.status, NotificationPostStatus.failed);

        NotificationPostResult? next;
        service.post(note).then((r) => next = r);
        async.flushMicrotasks();
        plugin.showGate!.complete();
        async.flushMicrotasks();
        expect(next?.status, NotificationPostStatus.accepted);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    test('a hanging getActiveNotifications ends withdrawAnswerable', () {
      final plugin = _FakePlugin()..activeGate = Completer<void>();
      expect(endsByTimeout(plugin, (s) => s.withdrawAnswerable()), isTrue);
    });

    test('a hanging cancel ends withdrawAnswerable', () {
      final plugin = _FakePlugin()..cancelGate = Completer<void>();
      plugin.active.add(
        ActiveNotification(
          id: 1,
          payload: notificationPayload(_request(_approval)),
        ),
      );
      expect(endsByTimeout(plugin, (s) => s.withdrawAnswerable()), isTrue);
      expect(plugin.cancelled, isEmpty);
    });

    test('a hanging getNotificationAppLaunchDetails ends launchTarget', () {
      final plugin = _FakePlugin()..launchGate = Completer<void>();
      expect(endsByTimeout(plugin, (s) => s.launchTarget()), isTrue);
    });
  });

  group('linuxSessionBusAvailable', () {
    bool check(Map<String, String> env, Set<String> files, {int uid = 1000}) =>
        linuxSessionBusAvailable(
          environment: env,
          exists: files.contains,
          uid: () => uid,
        );

    test('an address with no usable transport is no bus', () {
      for (final address in [
        'disabled:',
        'unix:guid=1',
        'unix:path=',
        '',
        'x',
      ]) {
        expect(
          check({'DBUS_SESSION_BUS_ADDRESS': address}, {'/run/user/1000/bus'}),
          isFalse,
          reason: address,
        );
      }
    });

    test('an address that does not parse into a transport is no bus', () {
      for (final address in [
        'bogus',
        'tcp:host=x,port=y',
        'tcp:host=x',
        'tcp:host=x,port=1,family=ipv5',
        'tcp:port=1',
        'unix:path=/x,bad',
        'unix:path=/a,path=/b',
        'tcp:host=x,port=70000',
        'tcp:host=x,port=-1',
        'unix:path=%zz',
        'unix:path=%2',
        'unix:dir=/tmp',
        'unix:path=,abstract=x',
        'disabled:;unix:path=/x',
      ]) {
        expect(
          check({'DBUS_SESSION_BUS_ADDRESS': address}, {}),
          isFalse,
          reason: address,
        );
      }
    });

    test('an address the dbus package can open is a bus', () {
      for (final address in [
        'unix:path=/x',
        'unix:abstract=/tmp/dbus-x',
        'unix:abstract=x',
        'tcp:host=localhost,port=1',
        'tcp:host=x,port=1234',
        'tcp:host=x,port=%312345',
        'tcp:host=x,port=65535',
        'unix:path=%2Frun%2Fbus',
      ]) {
        expect(
          check({'DBUS_SESSION_BUS_ADDRESS': address}, {}),
          isTrue,
          reason: address,
        );
      }
    });

    test('only a unix socket counts as the bus socket', () async {
      final dir = Directory.systemTemp.createTempSync('hermes_bus_probe_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/file')..writeAsStringSync('x');
      final folder = Directory('${dir.path}/folder')..createSync();
      final socketPath = '${dir.path}/bus';
      final server = await ServerSocket.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(server.close);
      Link('${dir.path}/link').createSync(socketPath);

      expect(isUnixSocket(file.path), isFalse);
      expect(isUnixSocket(folder.path), isFalse);
      expect(isUnixSocket('${dir.path}/missing'), isFalse);
      expect(isUnixSocket(socketPath), isTrue);
      expect(isUnixSocket('${dir.path}/link'), isTrue);
    });

    test('is false with nothing set and no socket', () {
      expect(check({}, {}), isFalse);
    });

    test('falls back to XDG_USER_DIR/bus', () {
      expect(check({'XDG_USER_DIR': '/u'}, {'/u/bus'}), isTrue);
      expect(check({'XDG_USER_DIR': '/u'}, {'/run/user/1000/bus'}), isFalse);
    });

    test('falls back to /run/user/<uid>/bus, ignoring XDG_RUNTIME_DIR', () {
      expect(check({}, {'/run/user/42/bus'}, uid: 42), isTrue);
      expect(check({}, {'/run/user/1000/bus'}, uid: 42), isFalse);
      expect(check({'XDG_RUNTIME_DIR': '/r'}, {'/r/bus'}), isFalse);
    });
  });

  group('registerCategoriesNatively', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('hermes_app/notification_categories');

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('hands the categories over one call at a time', () async {
      final log = <String>[];
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final n = ++calls;
            log.add('start $n');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            log.add('end $n');
            return null;
          });
      final categories = staticRequestCategories();

      await Future.wait([
        registerCategoriesNatively(categories),
        registerCategoriesNatively(categories),
      ]);

      expect(log, ['start 1', 'end 1', 'start 2', 'end 2']);
    });

    test('tells the Runner to forget the question categories', () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            return null;
          });

      await forgetQuestionCategories();

      expect(methods, ['forget']);
    });
  });

  group('a question that never reached Hermes', () {
    test('carries the question in its payload and opens a new chat', () {
      final payload = notificationPayload(
        const AttentionNotification(
          threadId: 'ask:1',
          title: 'Hermes',
          body: "Couldn't send your question",
          profile: 'work',
          prompt: 'What is C++?',
        ),
      );

      final target = targetFromPayload(payload)!;

      expect(target.prompt, 'What is C++?');
      expect(target.profile, 'work');
      expect(target.isJob, isFalse);
      expect(payload, contains('ask:1'));
    });

    test('is a plain chat tap without a question', () {
      final target = targetFromPayload(
        notificationPayload(
          const AttentionNotification(threadId: 's1', title: 't', body: 'b'),
        ),
      )!;

      expect(target.prompt, isNull);
      expect(target.threadId, 's1');
    });
  });

  group('a draft the user may get back', () {
    String payload(Map<String, Object?> fields) => jsonEncode(fields);

    test('carries the profile, the text and the account hash', () {
      final target = targetFromPayload(
        payload({'t': 's1', 'p': 'work', 'u': 'Try again', 'a': 'abc123'}),
      )!;

      expect(target.threadId, 's1');
      expect(target.profile, 'work');
      expect(target.draft, 'Try again');
      expect(target.accountHash, 'abc123');
    });

    test('is a plain chat tap without a text or without an account', () {
      expect(targetFromPayload(payload({'t': 's1', 'a': 'x'}))!.draft, isNull);
      expect(targetFromPayload(payload({'t': 's1', 'u': 'hi'}))!.draft, isNull);
    });

    test('keeps at most the length of a preview', () {
      final fits = 'a' * kPreviewLength;
      expect(
        targetFromPayload(payload({'t': 's1', 'u': fits, 'a': 'x'}))!.draft,
        fits,
      );
      expect(
        targetFromPayload(payload({'t': 's1', 'u': '${fits}a', 'a': 'x'}))!
            .draft,
        isNull,
      );
    });

    test('counts a joined emoji as one character', () {
      const family = '👨‍👩‍👧‍👦';
      expect(
        targetFromPayload(
          payload({'t': 's1', 'u': family * kPreviewLength, 'a': 'x'}),
        )!.draft,
        family * kPreviewLength,
      );
    });

    test('the account hash tells accounts apart and is not the key', () {
      expect(accountHashFor('one'), accountHashFor('one'));
      expect(accountHashFor('one'), isNot(accountHashFor('two')));
      expect(accountHashFor('one'), isNot(contains('one')));
    });
  });

  group('a message from Hermes', () {
    AttentionNotification note({String threadId = 'hermes-app-1'}) =>
        AttentionNotification(
          threadId: threadId,
          title: 'Report',
          body: 'b',
          profile: 'work',
          isMessage: true,
        );

    test('opens its chat under its profile', () {
      final payload = notificationPayload(note());

      final target = targetFromPayload(payload)!;

      expect(target.isMessage, isTrue);
      expect(target.threadId, 'hermes-app-1');
      expect(target.profile, 'work');
    });

    test('the summary has no chat', () {
      final payload = notificationPayload(note(threadId: ''));

      final target = targetFromPayload(payload)!;

      expect(target.isMessageSummary, isTrue);
      expect(jsonDecode(payload), {'m': 1, 'p': 'work'});
    });

    test('a notification under the message category alone is not one', () {
      final target = targetFromPayload(
        notificationPayload(
          const AttentionNotification(
            threadId: 's1',
            title: 't',
            body: 'b',
            category: messageCategory,
          ),
        ),
      )!;

      expect(target.isMessage, isFalse);
    });

    test('a reply is not a message', () {
      final target = targetFromPayload(
        notificationPayload(
          const AttentionNotification(
            threadId: 's1',
            title: 't',
            body: 'b',
            category: replyReadyCategory,
          ),
        ),
      )!;

      expect(target.isMessage, isFalse);
    });
  });
}
