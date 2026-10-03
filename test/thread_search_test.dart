import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/thread_search.dart';

ThreadSearchHit _hit(String id) => ThreadSearchHit(
  id: id,
  title: id,
  snippet: const [],
  updatedAt: DateTime(2026),
);

void main() {
  test('searches once the user stops typing', () {
    fakeAsync((async) {
      final queries = <String>[];
      final search = ThreadSearch((q) async {
        queries.add(q);
        return [_hit(q)];
      });

      search.update('b');
      async.elapse(const Duration(milliseconds: 100));
      search.update('ba');
      async.elapse(const Duration(milliseconds: 100));
      search.update('backup');
      expect(search.status, ThreadSearchStatus.loading);
      async.elapse(ThreadSearch.defaultDebounce);

      expect(queries, ['backup']);
      expect(search.status, ThreadSearchStatus.done);
      expect(search.hits.single.id, 'backup');
    });
  });

  test('drops the answer to a query the user has moved past', () {
    fakeAsync((async) {
      final answers = <String, Completer<List<ThreadSearchHit>>>{};
      final search = ThreadSearch(
        (q) => (answers[q] = Completer<List<ThreadSearchHit>>()).future,
      );

      search.update('old');
      async.elapse(ThreadSearch.defaultDebounce);
      search.update('new');
      async.elapse(ThreadSearch.defaultDebounce);
      answers['new']!.complete([_hit('new')]);
      async.flushMicrotasks();
      answers['old']!.complete([_hit('old')]);
      async.flushMicrotasks();

      expect(search.hits.single.id, 'new');
    });
  });

  test('reports a failed search', () {
    fakeAsync((async) {
      final search = ThreadSearch((_) async => throw Exception('down'));

      search.update('backup');
      async.elapse(ThreadSearch.defaultDebounce);

      expect(search.status, ThreadSearchStatus.failed);
      expect(search.hits, isEmpty);
    });
  });

  test('a blank query and clear go back to idle without searching', () {
    fakeAsync((async) {
      var calls = 0;
      final search = ThreadSearch((q) async {
        calls++;
        return [_hit(q)];
      });

      search.update('backup');
      search.update('  ');
      async.elapse(ThreadSearch.defaultDebounce);
      expect(search.status, ThreadSearchStatus.idle);

      search.update('backup');
      async.elapse(ThreadSearch.defaultDebounce);
      search.clear();

      expect(calls, 1);
      expect(search.query, '');
      expect(search.status, ThreadSearchStatus.idle);
      expect(search.hits, isEmpty);
    });
  });
}
