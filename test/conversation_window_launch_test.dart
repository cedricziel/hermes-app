import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/windows/conversation_window_app.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';

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

  test('quick panel arguments round-trip and are no conversation', () {
    const launch = QuickPanelLaunch(
      baseUrl: 'https://hermes.test',
      authRequired: false,
    );
    final encoded = launch.encode();

    final decoded = QuickPanelLaunch.decode(encoded)!;
    expect(decoded.baseUrl, 'https://hermes.test');
    expect(decoded.authRequired, isFalse);
    expect(ConversationWindowLaunch.decode(encoded), isNull);
  });

  test('conversation arguments are no quick panel', () {
    const args = ConversationWindowArgs(
      threadId: 's1',
      profile: null,
      title: 'A',
      baseUrl: 'https://hermes.test',
      authRequired: true,
    );

    expect(
      QuickPanelLaunch.decode(ConversationWindowLaunch(args).encode()),
      isNull,
    );
    expect(QuickPanelLaunch.decode('not json'), isNull);
  });
}
