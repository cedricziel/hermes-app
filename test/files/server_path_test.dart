import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/server_path.dart';

ServerPath p(String text) => ServerPath.tryParse(text)!;

void main() {
  group('parsing', () {
    test('reads the three styles', () {
      expect(p('/srv/app').style, ServerPathStyle.posix);
      expect(p(r'C:\Users\me').style, ServerPathStyle.windowsDrive);
      expect(p(r'\\files\share\a').style, ServerPathStyle.unc);
    });

    test('refuses what is not an absolute path', () {
      for (final bad in [
        '',
        'relative/path',
        './x',
        'C:',
        r'C:folder',
        r'\\server',
        r'\\server\',
        r'\\\share',
        '/a\u0000b',
        '/srv/../etc',
        '/srv/./app',
        r'C:\a\..\b',
        'file:///srv/app',
      ]) {
        expect(ServerPath.tryParse(bad), isNull, reason: bad);
      }
    });

    test('keeps the server\'s text exactly', () {
      for (final text in ['/srv//app/', r'C:/Users\me', '/a b/é/ü.txt']) {
        expect(p(text).value, text);
      }
    });

    test('toString does not print the path', () {
      expect('${p('/srv/secret-project')}', isNot(contains('secret')));
    });
  });

  group('segments, name and parent', () {
    test('posix', () {
      final path = p('/srv/project/reports');
      expect(path.segments, ['srv', 'project', 'reports']);
      expect(path.name, 'reports');
      expect(path.parent!.value, '/srv/project');
      expect(path.parent!.parent!.parent!.value, '/');
      expect(path.parent!.parent!.parent!.isRoot, isTrue);
      expect(p('/').parent, isNull);
      expect(p('/').name, '');
      expect(p('/').segments, isEmpty);
    });

    test('a trailing or doubled separator does not add a segment', () {
      expect(p('/srv//app/').segments, ['srv', 'app']);
      expect(p('/srv//app/x').parent!.value, '/srv//app');
    });

    test('windows drive, with either separator', () {
      final path = p(r'C:\Users\me\Docs');
      expect(path.segments, ['Users', 'me', 'Docs']);
      expect(path.parent!.value, r'C:\Users\me');
      expect(p(r'C:\Users').parent!.value, r'C:\');
      expect(p(r'C:\').parent, isNull);
      expect(p('c:/a/b').segments, ['a', 'b']);
    });

    test('unc accepts a forward slash as a separator', () {
      expect(p(r'\\srv\share/x').isWithin(p(r'\\srv\share')), isTrue);
      expect(p(r'\\srv\share/x').segments, ['x']);
      expect(p(r'\\srv/share\x').isWithin(p(r'\\srv\share')), isTrue);
      expect(p(r'\\srv\share/x').parent!.value, r'\\srv\share');
      expect(ServerPath.tryParse(r'\\srv/'), isNull);
    });

    test('unc refuses dot parts and device paths', () {
      for (final text in [
        r'\\srv\share/..',
        r'\\srv\share\.\a',
        r'\\srv\share/a/../b',
        r'\\srv\..\a',
        r'\\srv\.\a',
        r'\\..\share\a',
        r'\\.\share\a',
        r'\\?\C:\a',
        r'\\.\C:\a',
        r'\\?\UNC\srv\share',
        r'\\srv\?',
      ]) {
        expect(ServerPath.tryParse(text), isNull, reason: text);
      }
    });

    test('unc keeps the server and share in the root', () {
      final path = p(r'\\files\share\a\b');
      expect(path.segments, ['a', 'b']);
      expect(path.parent!.parent!.value, r'\\files\share');
      expect(p(r'\\files\share').isRoot, isTrue);
      expect(p(r'\\files\share').parent, isNull);
    });

    test('a posix name may hold a backslash', () {
      expect(p(r'/srv/a\b').segments, ['srv', r'a\b']);
    });
  });

  group('isWithin', () {
    test('by whole components, not by prefix', () {
      final root = p('/srv/app');
      expect(p('/srv/app').isWithin(root), isTrue);
      expect(p('/srv/app/src/main.dart').isWithin(root), isTrue);
      expect(p('/srv/app-secrets/key').isWithin(root), isFalse);
      expect(p('/srv').isWithin(root), isFalse);
      expect(p('/srv/application').isWithin(root), isFalse);
    });

    test('trailing separators do not matter', () {
      expect(p('/srv/app/x').isWithin(p('/srv/app/')), isTrue);
      expect(p('/srv/app/').isWithin(p('/srv/app')), isTrue);
    });

    test('everything is within the root', () {
      expect(p('/etc/passwd').isWithin(p('/')), isTrue);
    });

    test('drive letters ignore case, other components do not', () {
      expect(p(r'c:\Work\a').isWithin(p(r'C:\Work')), isTrue);
      expect(p(r'C:\work\a').isWithin(p(r'C:\Work')), isFalse);
      expect(p(r'D:\Work\a').isWithin(p(r'C:\Work')), isFalse);
    });

    test('unc server and share ignore case; styles never mix', () {
      expect(p(r'\\FILES\Share\a').isWithin(p(r'\\files\share')), isTrue);
      expect(p(r'\\files\other\a').isWithin(p(r'\\files\share')), isFalse);
      expect(p('/a').isWithin(p(r'C:\a')), isFalse);
      expect(p(r'C:\a').isWithin(p('/')), isFalse);
    });
  });

  test('equality is by the exact text', () {
    expect(p('/a'), p('/a'));
    expect(p('/a'), isNot(p('/a/')));
    expect({p('/a'), p('/a')}, hasLength(1));
  });
}
