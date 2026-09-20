import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/notifications/local_notification_service.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';

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
}
