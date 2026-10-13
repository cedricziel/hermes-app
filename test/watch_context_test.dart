import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';

void main() {
  test('protected storage read failure does not overwrite ownership', () async {
    var writes = 0;
    final store = WatchContextStore(
      read: () async => throw StateError('locked'),
      write: (_) async {
        writes++;
      },
    );
    await expectLater(
      store.resolve(owner: null, ungatedServer: 'https://server', revision: 1),
      throwsStateError,
    );
    expect(writes, 0);
  });

  const owner = VerifiedSessionOwner(
    server: 'https://server',
    user: 'u',
    organization: 'o',
    provider: 'p',
  );
  test('unknown owner cancels an earlier pending resolution', () async {
    final firstRead = Completer<String?>();
    var reads = 0;
    final store = WatchContextStore(
      read: () => reads++ == 0 ? firstRead.future : Future.value(null),
      write: (_) async {},
      randomId: () => 'previous-owner',
    );
    final pending = store.resolve(
      owner: owner,
      ungatedServer: null,
      revision: 1,
    );
    await Future<void>.delayed(Duration.zero);
    final unknown = store.resolve(
      owner: null,
      ungatedServer: null,
      revision: 2,
    );
    firstRead.complete(null);
    expect(await pending, isNull);
    await unknown;
    expect(store.current, isNull);
  });

  test(
    'failed owner resolution clears the previously active context',
    () async {
      String? saved;
      var unavailable = false;
      final store = WatchContextStore(
        read: () async {
          if (unavailable) throw StateError('locked');
          return saved;
        },
        write: (value) async => saved = value,
        randomId: () => 'owner-a',
      );
      await store.resolve(owner: owner, ungatedServer: null, revision: 1);
      unavailable = true;
      await expectLater(
        store.resolve(owner: null, ungatedServer: null, revision: 2),
        throwsStateError,
      );
      expect(store.current, isNull);
    },
  );

  test('failed departure cannot reuse the departed context', () async {
    String? saved;
    var unavailable = false;
    var sequence = 0;
    final store = WatchContextStore(
      read: () async => saved,
      write: (value) async {
        if (unavailable) throw StateError('locked');
        saved = value;
      },
      randomId: () => 'context-${sequence++}',
    );
    final original = await store.resolve(
      owner: owner,
      ungatedServer: null,
      revision: 1,
    );
    unavailable = true;
    await expectLater(
      store.resolve(
        owner: null,
        ungatedServer: null,
        revision: 2,
        departed: true,
      ),
      throwsStateError,
    );
    unavailable = false;
    final returned = await store.resolve(
      owner: owner,
      ungatedServer: null,
      revision: 3,
    );
    expect(returned?.id, isNot(original?.id));
  });

  test(
    'verified owner survives restart and refresh, departure rotates context',
    () async {
      String? saved;
      var id = 0;
      WatchContextStore store() => WatchContextStore(
        read: () async => saved,
        write: (v) async => saved = v,
        randomId: () => 'context-${id++}',
      );
      final first = await store().resolve(
        owner: owner,
        ungatedServer: null,
        revision: 4,
      );
      final refreshed = await store().resolve(
        owner: owner,
        ungatedServer: null,
        revision: 4,
      );
      expect(refreshed?.id, first?.id);
      await store().resolve(
        owner: null,
        ungatedServer: null,
        revision: 5,
        departed: true,
      );
      final returned = await store().resolve(
        owner: owner,
        ungatedServer: null,
        revision: 6,
      );
      expect(returned?.id, isNot(first?.id));
      expect(returned?.revision, 7);
    },
  );
  test(
    'unknown gated owner fails closed and ungated server owns separate context',
    () async {
      String? saved;
      final store = WatchContextStore(
        read: () async => saved,
        write: (v) async => saved = v,
      );
      expect(
        await store.resolve(owner: null, ungatedServer: null, revision: 1),
        isNull,
      );
      expect(
        await store.resolve(
          owner: null,
          ungatedServer: 'https://server',
          revision: 2,
        ),
        isNotNull,
      );
    },
  );

  test('v2 thread IDs preserve delimiter characters and null profile', () {
    final decoded = WatchThreadId.decode(
      WatchThreadId('opaque', 'a/b%?', 's/雪').encode(),
    );
    expect(
      WatchThreadId('opaque', 'a/b%?', 's/雪').encode(),
      'v2/WyJvcGFxdWUiLCJhL2IlPyIsInMv6ZuqIl0',
    );
    expect(decoded?.contextId, 'opaque');
    expect(decoded?.profile, 'a/b%?');
    expect(decoded?.sessionId, 's/雪');
    expect(
      WatchThreadId.decode(WatchThreadId('opaque', null, 's').encode())
          ?.profile,
      isNull,
    );
  });
  test('legacy and malformed IDs cannot authorize thread access', () {
    expect(WatchThreadId.decode('default/s1'), isNull);
    expect(WatchThreadId.decode('v2/garbage'), isNull);
    expect(WatchThreadId.decode('v2/W10'), isNull);
  });
}
