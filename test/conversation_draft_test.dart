import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';

const _args = ConversationWindowArgs(
  threadId: 's1',
  profile: 'work',
  title: 'Trip plan',
  baseUrl: 'https://hermes.test',
  authRequired: true,
);

void main() {
  test('a window is started with the draft handed to it', () {
    const draft = ConversationDraft(
      text: 'And then?',
      files: [
        SharedFile(path: '/tmp/a.png', name: 'a.png', isImage: true),
        SharedFile(path: '/tmp/b.pdf', name: 'b.pdf', mimeType: 'x/pdf'),
      ],
    );

    final launch = ConversationWindowLaunch.decode(
      ConversationWindowLaunch(_args, draft: draft).encode(),
    )!;

    expect(launch.args.threadId, 's1');
    expect(launch.draft?.text, 'And then?');
    expect(launch.draft?.files, draft.files);
  });

  test('a window without a draft starts empty', () {
    final launch = ConversationWindowLaunch.decode(
      const ConversationWindowLaunch(_args).encode(),
    )!;

    expect(launch.draft, isNull);
  });

  test('the saved arguments carry no draft', () {
    expect(_args.toJson().keys, isNot(contains('draft')));
  });
}
