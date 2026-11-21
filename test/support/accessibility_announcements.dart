import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One screen reader announcement: its [message] and its [textDirection] as
/// the platform message encodes it (the index of the `TextDirection`: 0 is right to left, 1 left to right).
typedef Announcement = ({String message, int? textDirection});

/// Collects what the app announces to a screen reader (`SemanticsService`)
/// until the test ends. Other accessibility events (tooltips, taps, long
/// presses) are ignored.
List<Announcement> captureAnnouncements(WidgetTester tester) {
  final said = <Announcement>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map && data['message'] is String) {
          said.add((
            message: data['message'] as String,
            textDirection: data['textDirection'] as int?,
          ));
        }
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return said;
}
