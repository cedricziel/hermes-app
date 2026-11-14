import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/workspaces/workspace_models.dart';
import 'package:hermes_app/src/workspaces/workspace_paths.dart';

WorkspaceProject _project(
  String id,
  List<String> folders, {
  bool archived = false,
}) => WorkspaceProject(
  id: id,
  name: id,
  archived: archived,
  folders: [for (final f in folders) WorkspaceFolder(path: f)],
);

void main() {
  group('isServerPath', () {
    test('accepts a path led by / or ~ and nothing else', () {
      expect(isServerPath('/srv/app'), isTrue);
      expect(isServerPath('~'), isTrue);
      expect(isServerPath('~/code'), isTrue);
      expect(isServerPath('code/app'), isFalse);
      expect(isServerPath('./app'), isFalse);
      expect(isServerPath(''), isFalse);
      expect(isServerPath(' /srv'), isFalse);
    });
  });

  group('WorkspaceProjects.projectFor', () {
    final demo = _project('demo', ['/home/me/code/demo']);
    final nested = _project('nested', ['/home/me/code/demo/packages/app']);

    test('an equal folder matches', () {
      expect(
        WorkspaceProjects.projectFor('/home/me/code/demo', [demo])?.id,
        'demo',
      );
    });

    test('an ancestor folder matches', () {
      expect(
        WorkspaceProjects.projectFor('/home/me/code/demo/lib/src', [demo])?.id,
        'demo',
      );
    });

    test('the longest folder wins, whatever the order', () {
      for (final projects in [
        [demo, nested],
        [nested, demo],
      ]) {
        expect(
          WorkspaceProjects.projectFor(
            '/home/me/code/demo/packages/app/lib',
            projects,
          )?.id,
          'nested',
        );
      }
    });

    test('separators and a trailing slash are normalised', () {
      expect(
        WorkspaceProjects.projectFor('/home/me//code/demo/', [demo])?.id,
        'demo',
      );
      expect(
        WorkspaceProjects.projectFor('/home/me/code/demo/x', [
          _project('t', ['/home/me/code/demo/']),
        ])?.id,
        't',
      );
    });

    test('compares whole segments, not text prefixes', () {
      expect(
        WorkspaceProjects.projectFor('/home/me/code/demo-two', [demo]),
        isNull,
      );
    });

    test('an archived project is ignored', () {
      final old = _project('old', ['/home/me/code/demo'], archived: true);
      expect(WorkspaceProjects.projectFor('/home/me/code/demo', [old]), isNull);
      expect(
        WorkspaceProjects.projectFor('/home/me/code/demo', [old, demo])?.id,
        'demo',
      );
    });

    test('no project, and a path that is not absolute, give none', () {
      expect(WorkspaceProjects.projectFor('/tmp/x', [demo]), isNull);
      expect(WorkspaceProjects.projectFor('~/code/demo', [demo]), isNull);
      expect(WorkspaceProjects.projectFor('/tmp/x', const []), isNull);
    });
  });

  group('folder comparison for the mismatch notice', () {
    test('trailing separators do not count', () {
      expect(sameServerFolder('/srv/app/', '/srv/app'), isTrue);
      expect(sameServerFolder('/srv/app//', '/srv/app'), isTrue);
      expect(sameServerFolder('/', '/'), isTrue);
      expect(sameServerFolder('/srv/app', '/srv/app2'), isFalse);
    });

    test('a leading ~ is read as the home folder', () {
      expect(
        sameServerFolder('~/code', '/home/me/code', home: '/home/me'),
        isTrue,
      );
      expect(sameServerFolder('~', '/home/me/', home: '/home/me'), isTrue);
      expect(
        sameServerFolder('~/code', '/home/me/other', home: '/home/me'),
        isFalse,
      );
    });

    test('a mismatch is only claimed when both paths can be compared', () {
      expect(folderMismatch('/srv/app', '/srv'), isTrue);
      expect(folderMismatch('/srv/app/', '/srv/app'), isFalse);
      // A remote profile's ~ is not the dashboard host's.
      expect(folderMismatch('~/code', '/srv'), isFalse);
      expect(folderMismatch('/srv', '~/code'), isFalse);
      expect(
        folderMismatch('~/code', '/home/me/code', home: '/home/me'),
        isFalse,
      );
    });
  });
}
