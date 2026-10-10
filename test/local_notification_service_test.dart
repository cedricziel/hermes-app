import 'dart:convert';

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

class _Posted {
  _Posted(this.id, this.title, this.body, this.payload, this.details);

  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final NotificationDetails? details;
}

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final posted = <_Posted>[];
  var initializeCalls = 0;
  Exception? initializeError;
  Exception? showError;
  NotificationAppLaunchDetails? launchDetails;
  Exception? launchDetailsError;
  DidReceiveNotificationResponseCallback? onResponse;
  DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse;
  InitializationSettings? settings;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalls++;
    if (initializeError case final error?) throw error;
    onResponse = onDidReceiveNotificationResponse;
    onBackgroundResponse = onDidReceiveBackgroundNotificationResponse;
    this.settings = settings;
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
    if (showError case final error?) throw error;
    posted.add(_Posted(id, title, body, payload, notificationDetails));
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    if (launchDetailsError case final error?) throw error;
    return launchDetails;
  }

  final active = <ActiveNotification>[];
  final cancelled = <int>[];

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => active;

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

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

      test('withdraws nothing on Android, whose notifications have no '
          'buttons', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await service.show(_request(_approval));
        plugin.active.add(
          ActiveNotification(
            id: plugin.posted.single.id,
            payload: plugin.posted.single.payload,
          ),
        );

        await service.withdrawAnswerable();

        expect(plugin.cancelled, isEmpty);
      });

      test('stays generic on Android', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await service.show(_request(_approval));

        expect(plugin.posted.single.body, kApprovalBody);
      });

      test('stays generic on Android without a known choice', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

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

        expect(plugin.posted.single.body, kApprovalBody);
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
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
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
}
