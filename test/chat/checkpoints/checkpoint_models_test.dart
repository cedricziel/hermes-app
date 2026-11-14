import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';

void main() {
  group('parseCheckpointList', () {
    final hash = 'a' * 40;

    test('maps reasons to categories and drops the text', () {
      final list = parseCheckpointList({
        'enabled': true,
        'checkpoints': [
          {
            'hash': hash,
            'timestamp': '2026-09-29T10:00:00+00:00',
            'message': 'before terminal: rm -rf build',
          },
          {'hash': 'b' * 40, 'message': 'before patch'},
          {
            'hash': 'c' * 40,
            'message': 'pre-rollback snapshot (restoring to 1a2b3c4d5e6f)',
          },
          {'hash': 'd' * 40, 'message': 'something new'},
        ],
      }) as CheckpointsOn;
      expect(list.checkpoints.map((c) => c.reason), [
        CheckpointReason.beforeTerminal,
        CheckpointReason.beforeEdit,
        CheckpointReason.beforeRestore,
        CheckpointReason.other,
      ]);
      expect(list.checkpoints[2].restoredFrom, '1a2b3c4d');
      expect(list.checkpoints[0].timestamp, DateTime.utc(2026, 9, 29, 10));
      expect(list.checkpoints[1].timestamp, isNull);
    });

    test('skips rows without a usable hash and keeps the rest', () {
      final list = parseCheckpointList({
        'enabled': true,
        'checkpoints': [
          {'message': 'before patch'},
          {'hash': '', 'message': 'before patch'},
          {'hash': 'zzzz1234', 'message': 'before patch'},
          // A short all-digit hash would be read as an index.
          {'hash': '1234567', 'message': 'before patch'},
          'junk',
          {'hash': hash, 'timestamp': 'not a time'},
        ],
      }) as CheckpointsOn;
      expect(list.checkpoints.map((c) => c.hash), [hash]);
      expect(list.checkpoints.single.timestamp, isNull);
    });

    test('off, empty and malformed answers', () {
      expect(
        parseCheckpointList({'enabled': false, 'checkpoints': []}),
        isA<CheckpointsOff>(),
      );
      expect(
        (parseCheckpointList({'enabled': true}) as CheckpointsOn).checkpoints,
        isEmpty,
      );
      expect(parseCheckpointList({'checkpoints': []}), isNull);
    });
  });

  group('parseStat', () {
    test('reads counts, binary files, spaces and the summary line', () {
      final files = parseStat(
        ' lib/a.dart          |  4 ++--\n'
        ' my notes/b c.txt    | 10 +++++-----\n'
        ' assets/logo.png     | Bin 0 -> 12 bytes\n'
        ' 3 files changed, 8 insertions(+), 6 deletions(-)\n',
      );
      expect(files.map((f) => f.path), [
        'lib/a.dart',
        'my notes/b c.txt',
        'assets/logo.png',
      ]);
      expect(files.map((f) => f.changes), [4, 10, null]);
      expect(files[2].binary, isTrue);
      expect(files.every((f) => f.restorable), isTrue);
    });

    test('a rename shows the new path and is not restorable alone', () {
      final files = parseStat(
        ' lib/{old => new}/x.dart | 2 +-\n a.txt => b.txt | 0\n',
      );
      expect(files.map((f) => f.path), ['lib/new/x.dart', 'b.txt']);
      expect(files.every((f) => f.renamed && !f.restorable), isTrue);
    });

    test('decodes quoted names and refuses the ones it cannot read', () {
      final files = parseStat(
        ' "a\\tb.txt" | 1 +\n'
        ' "caf\\303\\251.txt" | 1 +\n'
        ' "bad\\9.txt" | 1 +\n',
      );
      expect(files[0].path, 'a\tb.txt');
      // A tab in a name is a control character: not offered alone.
      expect(files[0].restorable, isFalse);
      expect(files[1].path, 'café.txt');
      expect(files[1].restorable, isTrue);
      expect(files[2].restorable, isFalse);
    });

    test('names git or the shell could read as more than one file', () {
      final files = parseStat(
        ' [a].txt | 1 +\n'
        ' dir/*.txt | 1 +\n'
        ' -rf | 1 +\n'
        ' q?.txt | 1 +\n'
        ' a:b | 1 +\n'
        ' back\\slash | 1 +\n'
        ' .../deep/shortened.txt | 1 +\n'
        ' ok.txt | 1 +\n',
      );
      expect(files.map((f) => f.restorable), [
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
    });
  });

  group('parseDiff', () {
    const a =
        'diff --git a/a.txt b/a.txt\nindex 1..2 100644\n--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-x\n+y\n';
    const spaced =
        'diff --git a/my dir/b c.txt b/my dir/b c.txt\n--- a/my dir/b c.txt\n+++ b/my dir/b c.txt\n@@ -1 +1,2 @@\n-x\n+y\n+z\n';
    const renamed =
        'diff --git a/old.txt b/new.txt\nsimilarity index 90%\nrename from old.txt\nrename to new.txt\n';
    const quoted = 'diff --git "a/a\\tb" "b/a\\tb"\n@@ -1 +1 @@\n-x\n+y\n';

    test('splits by file, including spaces, renames and quoted names', () {
      final sections = parseDiff('$a$spaced$renamed$quoted');
      expect(sections.keys, ['a.txt', 'my dir/b c.txt', 'new.txt', 'a\tb']);
      expect(sections['a.txt'], contains('+y'));
      expect(sections['a.txt'], isNot(contains('b c.txt')));
    });

    test('empty text has no sections', () {
      expect(parseDiff(''), isEmpty);
    });
  });

  group('parseCheckpointChanges', () {
    test('counts added and removed lines per file from its section', () {
      final result = parseCheckpointChanges({
        'stat': ' a.txt | 2 +-\n my dir/b c.txt | 3 ++-\n',
        'diff':
            'diff --git a/a.txt b/a.txt\n@@ -1 +1 @@\n-x\n+y\n'
            'diff --git a/my dir/b c.txt b/my dir/b c.txt\n@@ -1 +1,2 @@\n-x\n+y\n+z\n',
      }) as Changes;
      expect(result.truncated, isFalse);
      expect(result.files.map((f) => (f.added, f.removed)), [(1, 1), (2, 1)]);
    });

    test('a diff cut at 4,000 characters keeps every listed file', () {
      final head = 'diff --git a/f0.txt b/f0.txt\n@@ -1 +1 @@\n-x\n+y\n';
      final diff = head + ('+' * (kCheckpointDiffLimit - head.length));
      expect(diff.length, kCheckpointDiffLimit);
      final result = parseCheckpointChanges({
        'stat': [for (var i = 0; i < 10; i++) ' f$i.txt | 2 +-'].join('\n'),
        'diff': diff,
      }) as Changes;
      expect(result.truncated, isTrue);
      expect(result.files, hasLength(10));
      expect(result.files.first.diff, isNotNull);
      expect(result.files.skip(1).every((f) => f.diff == null), isTrue);
      expect(result.files.skip(1).every((f) => f.restorable), isTrue);
    });

    test('a listed file without a section has no diff, not an empty one', () {
      final result = parseCheckpointChanges({
        'stat': ' a.txt | 2 +-\n b.txt | 1 +\n',
        'diff': 'diff --git a/a.txt b/a.txt\n@@ -1 +1 @@\n-x\n+y\n',
      }) as Changes;
      expect(result.truncated, isFalse);
      expect(result.files[1].diff, isNull);
      expect(result.files[1].added, isNull);
    });

    test('empty stat and diff are unreadable, never "no changes"', () {
      expect(
        parseCheckpointChanges({'stat': '', 'diff': ''}),
        isA<ChangesUnreadable>(),
      );
      expect(parseCheckpointChanges({}), isA<ChangesUnreadable>());
    });

    test('a diff with no stat still lists its files', () {
      final result = parseCheckpointChanges({
        'stat': '',
        'diff': 'diff --git a/a.txt b/a.txt\n@@ -1 +1 @@\n-x\n+y\n',
      }) as Changes;
      expect(result.files.single.path, 'a.txt');
    });
  });

  group('parseBreakdown', () {
    test('sorts by tokens, keeps unknown values unknown', () {
      final result = parseBreakdown({
        'categories': [
          {'id': 'system_prompt', 'label': '/home/u/secret.md', 'tokens': 10},
          {'id': 'conversation', 'tokens': 500},
          {'id': 'brand_new', 'tokens': 10},
          {'id': 'rules', 'tokens': -4},
          {'id': 'skills'},
        ],
        'context_percent': 140,
        'context_used': 'many',
        'context_estimated': true,
        'context_source': 'provider_usage',
        'model': 'some-model',
        'context_files': [
          {'label': 'AGENTS.md', 'path': '/home/u/AGENTS.md'},
        ],
      });
      expect(result.categories.map((c) => c.kind), [
        ContextCategoryKind.conversation,
        ContextCategoryKind.systemPrompt,
        ContextCategoryKind.other,
      ]);
      expect(result.percent, 100);
      expect(result.used, isNull);
      expect(result.max, isNull);
      expect(result.estimated, isTrue);
      expect(result.source, ContextSource.providerUsage);
      expect(result.model, 'some-model');
    });

    test('empty before the agent is built', () {
      final result = parseBreakdown({
        'categories': [],
        'estimated_total': 0,
        'context_max': 200000,
      });
      expect(result.categories, isEmpty);
      expect(result.max, 200000);
      expect(result.percent, isNull);
      expect(result.source, ContextSource.unknown);
    });
  });

  group('parseCompression', () {
    test('every outcome', () {
      CompressionResult read(Map<String, Object?> result) =>
          parseCompression(result);
      expect(
        read({
          'status': 'compressed',
          'before_messages': 42,
          'after_messages': 9,
          'before_tokens': 120000,
          'summary': {'fallback_used': true, 'headline': 'Compressed'},
        }),
        isA<Compressed>()
            .having((r) => r.beforeMessages, 'before', 42)
            .having((r) => r.afterMessages, 'after', 9)
            .having((r) => r.afterTokens, 'afterTokens', isNull)
            .having((r) => r.fallbackUsed, 'fallback', isTrue),
      );
      expect(
        read({
          'status': 'compressed',
          'summary': {'noop': true},
        }),
        isA<NothingToCompress>(),
      );
      expect(
        read({
          'status': 'compressed',
          'summary': {'refused_would_grow': true},
        }),
        isA<WouldNotShrink>(),
      );
      expect(
        read({
          'status': 'aborted',
          'summary': {'aborted': true},
        }),
        isA<CompressionAborted>(),
      );
      expect(
        read({'compressed': false, 'lock_held': true, 'message': 'x'}),
        isA<CompressLockHeld>(),
      );
      expect(read({'status': 'pending'}), isA<CompressPending>());
      expect(read({'status': 'weird'}), isA<CompressFailed>());
      expect(read({}), isA<CompressFailed>());
    });

    test('a before < after result is shown as returned', () {
      final result = parseCompression({
        'status': 'compressed',
        'before_messages': 5,
        'after_messages': 8,
      }) as Compressed;
      expect((result.beforeMessages, result.afterMessages), (5, 8));
    });

    test('counts out of range are unknown', () {
      final result = parseCompression({
        'status': 'compressed',
        'before_messages': 99999999999,
        'after_messages': -1,
      }) as Compressed;
      expect(result.beforeMessages, isNull);
      expect(result.afterMessages, isNull);
    });
  });

  group('isAcceptableFocus', () {
    test('accepts topics', () {
      for (final focus in [
        '',
        '  ',
        'the database schema',
        'keep details about auth',
        'the word here in the middle',
        'up to the schema',
      ]) {
        expect(isAcceptableFocus(focus), isTrue, reason: focus);
      }
    });

    test('refuses what the server would read as a command', () {
      for (final focus in [
        '--preview the schema',
        'the schema --dry-run',
        'a -k 3',
        'Here 3',
        'HERE',
        'here',
        'up to here',
        'Up To Here 4',
        '  --aggressive',
      ]) {
        expect(isAcceptableFocus(focus), isFalse, reason: focus);
      }
    });
  });
}
