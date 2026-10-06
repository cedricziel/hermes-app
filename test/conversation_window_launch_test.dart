import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/windows/conversation_window_app.dart';

void main() {
  test('a conversation window engine is recognised on macOS', () {
    expect(
      conversationWindowLaunch(['multi_window', 'w1', '{}'], macOS: true),
      (windowId: 'w1', arguments: '{}'),
    );
  });

  test('the same arguments elsewhere start the app as usual', () {
    expect(
      conversationWindowLaunch(['multi_window', 'w1', '{}'], macOS: false),
      isNull,
    );
  });

  test('other arguments start the app as usual', () {
    expect(conversationWindowLaunch(const [], macOS: true), isNull);
    expect(conversationWindowLaunch(['--flag'], macOS: true), isNull);
  });
}
