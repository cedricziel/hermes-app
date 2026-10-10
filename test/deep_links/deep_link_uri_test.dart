import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_parser.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/deep_links/deep_link_uri.dart';

void main() {
  final targets = <DeepLinkTarget>[
    const OpenChat(threadId: 'abc'),
    const OpenChat(profile: 'work', threadId: 'abc', prompt: 'Yes, book it'),
    const OpenChat(profile: 'my bot&co', threadId: 'a/b%20c'),
    const NewChat(),
    const NewChat(profile: 'work', dictate: true, prompt: 'Plan a trip & 🚀'),
    const NewChat(prompt: 'a=b?c#d'),
    const NewChat(prompt: 'C++'),
    const OpenRequests(),
    const OpenKanban(),
    const OpenSchedules(),
    const OpenSchedules(profile: 'work', jobId: 'j 1'),
  ];

  for (final target in targets) {
    test('round trips $target', () {
      expect(parseDeepLink(deepLinkUri(target)), target);
      expect(parseDeepLink(Uri.parse(deepLinkUri(target).toString())), target);
    });
  }

  test('leaves out parameters that are not set', () {
    expect(
      deepLinkUri(const OpenChat(threadId: 'abc')).toString(),
      'hermes://chat?id=abc',
    );
    expect(deepLinkUri(const NewChat()).toString(), 'hermes://new');
    expect(deepLinkUri(const OpenRequests()).toString(), 'hermes://requests');
    expect(deepLinkUri(const OpenKanban()).toString(), 'hermes://kanban');
    expect(deepLinkUri(const OpenSchedules()).toString(), 'hermes://schedules');
  });

  test('writes dictate as 1 and only when set', () {
    expect(deepLinkUri(const NewChat(dictate: true)).queryParameters, {
      'dictate': '1',
    });
    expect(deepLinkUri(const NewChat()).queryParameters, isEmpty);
  });

  test('writes a space as %20 and a plus as %2B', () {
    expect(
      deepLinkUri(const NewChat(prompt: 'a b+c')).toString(),
      'hermes://new?prompt=a%20b%2Bc',
    );
  });

  test('writes a plus as %2B, which Swift and Dart both read as a plus', () {
    expect(
      deepLinkUri(const NewChat(prompt: 'C++')).toString(),
      'hermes://new?prompt=C%2B%2B',
    );
  });

  test('percent-encodes values', () {
    final text = deepLinkUri(const NewChat(prompt: 'a & b')).toString();
    expect(text, isNot(contains(' ')));
    expect(text, isNot(contains('& b')));
  });
}
