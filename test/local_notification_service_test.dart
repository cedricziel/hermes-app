import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';

class _Posted {
  _Posted(this.id, this.title, this.body, this.payload);

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final posted = <_Posted>[];
  var initializeCalls = 0;
  Exception? initializeError;
  Exception? showError;
  NotificationAppLaunchDetails? launchDetails;
  Exception? launchDetailsError;
  DidReceiveNotificationResponseCallback? onResponse;

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
    posted.add(_Posted(id, title, body, payload));
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    if (launchDetailsError case final error?) throw error;
    return launchDetails;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationResponse _response(String? payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
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

    setUp(() {
      plugin = _FakePlugin();
      service = LocalNotificationService(plugin);
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
}
