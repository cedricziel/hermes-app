import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';

import '../support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late ChatThread thread;
  late List<String> reported;
  late int busy;

  ThreadHousekeeping housekeeping({required bool withBusy}) =>
      ThreadHousekeeping(
        repository: HermesChatRepository(server.client().raw),
        threads: () => [thread],
        profile: () => null,
        changed: () {},
        report: reported.add,
        reportBusy: withBusy ? () => busy++ : null,
        removed: (_) {},
        history: (_, {cancelled}) async => const [],
      );

  setUp(() {
    server = FakeHermesServer()
      ..on('DELETE', '/api/sessions/s1', {'detail': 'busy'}, status: 409)
      ..on('PATCH', '/api/sessions/s1', {'detail': 'busy'}, status: 409);
    thread = ChatThread(
      id: 's1',
      title: 'Plan',
      updatedAt: DateTime(2026, 1, 1),
      remote: true,
    );
    reported = [];
    busy = 0;
  });

  group('a 409 from Hermes', () {
    test('says Hermes is busy, once, for a delete', () async {
      await housekeeping(withBusy: true).delete(thread);

      expect(busy, 1);
      expect(reported, isEmpty);
      expect(server.requestsTo('DELETE', '/api/sessions/s1'), hasLength(1));
    });

    test('says Hermes is busy for a pin, which goes back', () async {
      await housekeeping(withBusy: true).setPinned(thread, true);

      expect(busy, 1);
      expect(reported, isEmpty);
      expect(thread.pinned, isFalse);
    });

    test('says Hermes is busy for a rename, which goes back', () async {
      await housekeeping(withBusy: true).rename(thread, 'New');

      expect(busy, 1);
      expect(reported, isEmpty);
      expect(thread.title, 'Plan');
    });

    test('says Hermes is busy for an archive, which keeps the chat', () async {
      await housekeeping(withBusy: true).archive(thread);

      expect(busy, 1);
      expect(reported, isEmpty);
    });

    test('reports the plain failure where no screen words the busy '
        'notice', () async {
      await housekeeping(withBusy: false).delete(thread);

      expect(reported, ['Could not delete this chat']);
    });
  });
}
