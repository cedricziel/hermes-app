import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects what the app announces to a screen reader (`SemanticsService`)
/// until the test ends.
List<String> captureAnnouncements(WidgetTester tester) {
  final said = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      final data = (message as Map)['data'];
      if (data is Map) said.add(data['message'] as String);
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
