import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects what the app sends a screen reader through the accessibility
/// channel (announcements, focus events) until the test ends.
class RecordedAccessibility {
  RecordedAccessibility(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map) messages.add(Map<String, Object?>.from(message));
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
  }

  final messages = <Map<String, Object?>>[];

  /// How many focus events were sent.
  int get focusEvents => messages.where((m) => m['type'] == 'focus').length;

  /// The text of every announcement, in order.
  List<String> get announcements => [
    for (final m in messages)
      if (m['type'] == 'announce') (m['data']! as Map)['message']! as String,
  ];

  /// Everything sent, as one string, for a search for what must not be there.
  String get text => messages.join(' ');
}
