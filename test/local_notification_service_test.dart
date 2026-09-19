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
  });
}
