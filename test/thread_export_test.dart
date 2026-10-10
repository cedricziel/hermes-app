import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_export.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';

import 'support/fake_hermes_server.dart';

ChatMessage _turn(String id, ChatRole role, String text) => ChatMessage(
  id: id,
  role: role,
  content: text,
  createdAt: DateTime(2026, 1, 1),
);

ChatThread _thread({
  String title = 'Plan the offline mode',
  bool remote = true,
  List<ChatMessage>? messages,
}) => ChatThread(
  id: 's1',
  title: title,
  updatedAt: DateTime(2026, 1, 1),
  remote: remote,
  messages: messages,
);

ThreadHousekeeping _housekeeping(
  Future<List<ChatMessage>> Function(ChatThread, {bool Function()? cancelled})
  history,
) => ThreadHousekeeping(
  repository: HermesChatRepository(FakeHermesServer().client().raw),
  threads: () => const [],
  profile: () => null,
  changed: () {},
  report: (_) {},
  removed: (_) {},
  history: history,
);

Future<String> _exported(DragOutFile file) async =>
    utf8.decode(await file.read());

void main() {
  group('threadMarkdown', () {
    test('is the title as a heading, a blank line and the transcript', () {
      final messages = [
        _turn('1', ChatRole.user, 'hi'),
        _turn('2', ChatRole.assistant, 'hello'),
      ];

      expect(
        threadMarkdown('Plan', messages),
        '# Plan\n\n${threadTranscript(messages)}',
      );
      expect(
        threadMarkdown('Plan', messages),
        '# Plan\n\n## You\n\nhi\n\n## Hermes\n\nhello',
      );
    });

    test('an empty thread is the heading alone', () {
      expect(threadMarkdown('Plan', const []), '# Plan');
      expect(
        threadMarkdown('Plan', [_turn('1', ChatRole.assistant, '  ')]),
        '# Plan',
        reason: 'turns with nothing to say are skipped like Copy Transcript',
      );
    });

    test('a title with nothing in it is called Chat', () {
      expect(threadMarkdown('  ', const []), '# Chat');
    });

    test('the heading is one line', () {
      expect(
        threadMarkdown('Plan\n\nthe   offline\tmode', const []),
        '# Plan the offline mode',
      );
    });

    test('a trailing hash is not a closing sequence', () {
      expect(threadMarkdown('Issue #', const []), r'# Issue \#');
      expect(threadMarkdown('Issue ##', const []), r'# Issue \##');
      expect(threadMarkdown('#', const []), r'# \#');
      expect(threadMarkdown('Issue#12', const []), '# Issue#12');
    });
  });

  group('threadExportFileName', () {
    test('is the title with .md', () {
      expect(
        threadExportFileName('Plan the offline mode'),
        'Plan the offline mode.md',
      );
    });

    test('an empty title gives Chat.md', () {
      expect(threadExportFileName(''), 'Chat.md');
      expect(threadExportFileName('  '), 'Chat.md');
    });

    test('a hostile title has no separators or colon', () {
      final name = threadExportFileName('../../x/y: z');

      expect(name, isNot(anyOf(contains('/'), contains('\\'), contains(':'))));
      expect(name, isNot(startsWith('.')));
      expect(name, endsWith('.md'));
    });

    test('a title of dots alone is called Chat.md', () {
      expect(threadExportFileName('...'), 'Chat.md');
      expect(threadExportFileName('..md'), 'Chat.md');
      expect(threadExportFileName(' . '), 'Chat.md');
      expect(threadExportFileName('.hidden'), 'hidden.md');
    });

    test('a dot in the title is not an extension', () {
      expect(threadExportFileName('Release 1.2 notes'), 'Release 1.2 notes.md');
    });

    test('a title that already ends in .md is not doubled', () {
      expect(threadExportFileName('notes.md'), 'notes.md');
    });
  });

  group('threadDragItem', () {
    test('an unsaved chat is not draggable', () {
      expect(threadDragItem(_thread(remote: false), null), isNull);
    });

    test('reads every page of history only when the receiver asks', () async {
      final loaded = [_turn('3', ChatRole.user, 'newest')];
      final all = [
        _turn('1', ChatRole.user, 'first'),
        _turn('2', ChatRole.assistant, 'second'),
        ...loaded,
      ];
      var reads = 0;
      final thread = _thread(messages: loaded);
      final item = threadDragItem(
        thread,
        _housekeeping((_, {cancelled}) async {
          reads++;
          return all;
        }),
      )!;

      expect(item.name, 'Plan the offline mode.md');
      expect(reads, 0);
      expect(await _exported(item), threadMarkdown(thread.title, all));
      expect(reads, 1);
      expect(
        await _exported(item),
        contains('first'),
        reason: 'the unloaded pages are in the file',
      );
    });

    test('without housekeeping it exports the loaded messages', () async {
      final thread = _thread(messages: [_turn('1', ChatRole.user, 'hi')]);

      expect(
        await _exported(threadDragItem(thread, null)!),
        '# Plan the offline mode\n\n## You\n\nhi',
      );
    });

    test('is named for the history step when it fails', () {
      final item = threadDragItem(
        _thread(),
        _housekeeping((_, {cancelled}) async => throw StateError('500')),
      )!;

      expect(item.failure, DragOutFailure.history);
      expect(_exported(item), throwsStateError);
    });

    test('cancelling tells the history read to stop', () async {
      var stopped = false;
      final item = threadDragItem(
        _thread(),
        _housekeeping((_, {cancelled}) async {
          stopped = cancelled!();
          return const [];
        }),
      )!;

      item.cancel!();
      await item.read();

      expect(stopped, isTrue);
    });

    test('a read that was not cancelled is not told to stop', () async {
      var stopped = true;
      final item = threadDragItem(
        _thread(),
        _housekeeping((_, {cancelled}) async {
          stopped = cancelled!();
          return const [];
        }),
      )!;

      await item.read();

      expect(stopped, isFalse);
    });

    test('the file is UTF-8', () async {
      final thread = _thread(
        title: 'Größe 日本',
        messages: [_turn('1', ChatRole.user, 'héllo 🙂')],
      );

      expect(
        await _exported(threadDragItem(thread, null)!),
        '# Größe 日本\n\n## You\n\nhéllo 🙂',
      );
    });
  });
}
