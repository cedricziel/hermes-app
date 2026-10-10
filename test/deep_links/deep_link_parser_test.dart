import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_parser.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';

DeepLinkTarget? parse(String url) => parseDeepLink(Uri.parse(url));

void main() {
  group('chat', () {
    test('opens a chat of a profile', () {
      final target = parse('hermes://chat?profile=work&id=abc');
      expect(target, isA<OpenChat>());
      target as OpenChat;
      expect(target.profile, 'work');
      expect(target.threadId, 'abc');
      expect(target.prompt, isNull);
    });

    test('profile is optional', () {
      final target = parse('hermes://chat?id=abc') as OpenChat;
      expect(target.profile, isNull);
      expect(target.threadId, 'abc');
    });

    test('takes a prompt', () {
      final target = parse('hermes://chat?id=abc&prompt=Yes%2C%20book%20it');
      expect((target as OpenChat).prompt, 'Yes, book it');
    });

    test('is malformed without an id', () {
      expect(parse('hermes://chat?profile=work'), isNull);
      expect(parse('hermes://chat?id='), isNull);
      expect(parse('hermes://chat'), isNull);
    });

    test('decodes profile and id once', () {
      final target = parse(
        'hermes://chat?profile=my%20bot%26co&id=a%2Fb%2520c',
      ) as OpenChat;
      expect(target.profile, 'my bot&co');
      expect(target.threadId, 'a/b%20c');
    });

    test('ignores unknown query keys', () {
      final target = parse('hermes://chat?id=abc&source=widget') as OpenChat;
      expect(target.threadId, 'abc');
    });
  });

  group('new', () {
    test('needs no parameters', () {
      final target = parse('hermes://new') as NewChat;
      expect(target.profile, isNull);
      expect(target.dictate, isFalse);
      expect(target.prompt, isNull);
    });

    test('takes profile, dictate and prompt', () {
      final target =
          parse('hermes://new?profile=work&dictate=1&prompt=Hello') as NewChat;
      expect(target.profile, 'work');
      expect(target.dictate, isTrue);
      expect(target.prompt, 'Hello');
    });

    test('decodes spaces, ampersands and emoji in the prompt', () {
      final target = parse(
        'hermes://new?prompt=Plan%20a%20trip%20%26%20book%20%F0%9F%9A%80',
      ) as NewChat;
      expect(target.prompt, 'Plan a trip & book 🚀');
    });

    test('dictate is true only for 1 or true', () {
      bool dictate(String value) =>
          (parse('hermes://new?dictate=$value') as NewChat).dictate;
      expect(dictate('1'), isTrue);
      expect(dictate('true'), isTrue);
      expect(dictate('0'), isFalse);
      expect(dictate('yes'), isFalse);
      expect(dictate(''), isFalse);
    });

    test('empty values count as absent', () {
      final target = parse('hermes://new?profile=&prompt=') as NewChat;
      expect(target.profile, isNull);
      expect(target.prompt, isNull);
    });

    test('trims the prompt and drops a blank one', () {
      expect(
        (parse('hermes://new?prompt=%20%20hi%20%0A') as NewChat).prompt,
        'hi',
      );
      expect((parse('hermes://new?prompt=%20%20') as NewChat).prompt, isNull);
    });

    test('cuts the prompt at 4000 characters', () {
      final long = 'a' * 5000;
      final target = parse('hermes://new?prompt=$long') as NewChat;
      expect(target.prompt, hasLength(4000));
    });

    test('cuts the prompt of a chat link too', () {
      final long = 'b' * 4500;
      final target = parse('hermes://chat?id=x&prompt=$long') as OpenChat;
      expect(target.prompt, hasLength(4000));
    });
  });

  group('other targets', () {
    test('requests', () {
      expect(parse('hermes://requests'), isA<OpenRequests>());
    });

    test('kanban', () {
      expect(parse('hermes://kanban'), isA<OpenKanban>());
    });

    test('schedules without parameters', () {
      final target = parse('hermes://schedules') as OpenSchedules;
      expect(target.profile, isNull);
      expect(target.jobId, isNull);
    });

    test('schedules with a job', () {
      final target = parse('hermes://schedules?profile=work&job=j1');
      target as OpenSchedules;
      expect(target.profile, 'work');
      expect(target.jobId, 'j1');
    });
  });

  group('ignored', () {
    test('unknown host', () {
      expect(parse('hermes://memory'), isNull);
    });

    test('another scheme', () {
      expect(parse('hermes-activity://chat?id=abc'), isNull);
      expect(parse('https://chat?id=abc'), isNull);
    });

    test('path-style link', () {
      expect(parse('hermes:chat?id=abc'), isNull);
      expect(parse('hermes:///chat?id=abc'), isNull);
    });

    test('scheme is case-insensitive as URIs are', () {
      expect(parse('HERMES://kanban'), isA<OpenKanban>());
    });
  });
}
