import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/thread_sections.dart';
import 'package:hermes_app/src/workspaces/folder_labels.dart';

ChatThread _thread(String id, String? folder) => ChatThread(
  id: id,
  title: id,
  updatedAt: DateTime.utc(2026, 1, 1),
  folderPath: folder,
);

void main() {
  group('folderLabelFor', () {
    test('is the last segment, the same rule the section headers use', () {
      expect(folderLabelFor('/home/me/code/demo'), 'demo');
      expect(folderLabelFor('/home/me/code/demo/'), 'demo');
      expect(folderLabelFor(r'C:\code\app'), 'app');
      expect(folderLabelFor('/'), '/');
    });

    test('names the whole path when another folder ends the same way', () {
      const among = ['/a/app', '/b/app', '/c/other'];

      expect(folderLabelFor('/a/app', among: among), '/a/app');
      expect(folderLabelFor('/b/app', among: among), '/b/app');
      expect(folderLabelFor('/c/other', among: among), 'other');
    });

    test('a folder is not its own twin', () {
      expect(folderLabelFor('/a/app', among: ['/a/app']), 'app');
    });

    test('labels a chat\'s own path, which may lie below its git root', () {
      // The header names where the chat runs, the list names its git root;
      // each is disambiguated against the same folders.
      const folders = ['/work/app', '/home/me/app'];

      expect(folderLabelFor('/work/app/api', among: folders), 'api');
      expect(folderLabelFor('/work/app', among: folders), '/work/app');
    });
  });

  test('folderLabels labels a set at once, keyed by path', () {
    expect(folderLabels(['/a/app', '/b/app', '/c/x', '/c/x']), {
      '/a/app': '/a/app',
      '/b/app': '/b/app',
      '/c/x': 'x',
    });
  });

  test('the chat list\'s section headers use the same labels', () {
    final sections = groupThreadsByFolder([
      _thread('1', '/a/app'),
      _thread('2', '/b/app'),
      _thread('3', '/c/solo'),
    ]);

    expect(sections.map((s) => s.label), ['/a/app', '/b/app', 'solo']);
  });

  test('a moved chat regroups, and a move answer without a git root groups '
      'under its folder', () {
    final chat = _thread('1', '/a/app');
    final other = _thread('2', '/b/app');
    expect(groupThreadsByFolder([chat, other]).map((s) => s.id), [
      'folder:/a/app',
      'folder:/b/app',
    ]);

    // What a move does with an answer whose `git_repo_root` is null: the
    // list folder is the answer's folder, trailing separator dropped.
    chat.folderPath = sessionFolderPath({
      'git_repo_root': null,
      'cwd': '/b/app/api/',
    });
    final sections = groupThreadsByFolder([chat, other]);

    expect(sections.map((s) => (s.id, s.label)), [
      ('folder:/b/app/api', 'api'),
      ('folder:/b/app', 'app'),
    ]);
  });
}
