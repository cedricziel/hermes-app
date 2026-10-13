import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/chat_models.dart' show AttachmentKind;
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  test('optional control timeout does not postpone the turn silence probe', () {
    fakeAsync((clock) {
      final gateway = FakeGateway()..activeSessions = {};
      gateway.silent.add('session.control.read');
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });
      final transport = HermesGatewayTransport(connect: gateway.connect);
      final first = transport.send(text: 'Inspect').listen((_) {});
      clock.flushMicrotasks();
      final follow = transport
          .followUps('stored-1')
          .listen((_) {}, onError: (Object _) {});
      clock.flushMicrotasks();
      gateway.event('message.start', 'rt-1');
      clock.flushMicrotasks();

      clock.elapse(const Duration(seconds: 44));
      clock.flushMicrotasks();
      expect(gateway.methods, isNot(contains('session.active_list')));
      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(
        gateway.methods.where((method) => method == 'session.active_list'),
        hasLength(1),
      );

      unawaited(first.cancel());
      unawaited(follow.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });

  test('reclaim during attachment prevents a new prompt submission', () async {
    final gateway = FakeGateway();
    gateway.handlers['session.resume'] = (_) {
      gateway.event('session.reclaimed', '', {
        'session_id': 'rt-1',
        'stored_session_id': 'stored-1',
        'reason': 'Another client took over',
      });
      return {'session_id': 'rt-1', 'stored_session_id': 'stored-1'};
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);

    final events = await transport
        .send(threadId: 'stored-1', text: 'Keep this local')
        .toList();

    expect(events.whereType<SessionReclaimed>(), hasLength(1));
    expect(gateway.methods, isNot(contains('prompt.submit')));
  });

  test(
    'reclaim during image upload retires the runtime without cleanup RPCs',
    () async {
      final gateway = FakeGateway();
      gateway.handlers['image.attach_bytes'] = (params) {
        gateway.event('session.reclaimed', '', {
          'session_id': params['session_id'],
          'stored_session_id': 'stored-1',
          'reason': 'Another client took over',
        });
        return {'attached': true, 'path': '/tmp/uploaded-image.png'};
      };
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);

      final events = await transport
          .send(
            text: 'Keep this local',
            attachments: [
              OutgoingAttachment(
                name: 'photo.png',
                kind: AttachmentKind.image,
                mimeType: 'image/png',
                read: () async => Uint8List.fromList([1, 2, 3]),
              ),
            ],
          )
          .toList();

      expect(events.whereType<SessionReclaimed>(), hasLength(1));
      expect(gateway.methods, isNot(contains('prompt.submit')));
      expect(gateway.methods, isNot(contains('image.detach')));
    },
  );

  test('reclaim after the first image prevents a second upload', () async {
    final gateway = FakeGateway();
    gateway.handlers['image.attach_bytes'] = (params) {
      gateway.event('session.reclaimed', '', {
        'session_id': params['session_id'],
        'stored_session_id': 'stored-1',
        'reason': 'Another client took over',
      });
      return {'attached': true, 'path': '/tmp/first-image.png'};
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);

    final events = await transport
        .send(
          text: 'Keep these local',
          attachments: [
            OutgoingAttachment(
              name: 'first.png',
              kind: AttachmentKind.image,
              read: () async => Uint8List.fromList([1, 2, 3]),
            ),
            OutgoingAttachment(
              name: 'second.png',
              kind: AttachmentKind.image,
              read: () async => Uint8List.fromList([4, 5, 6]),
            ),
          ],
        )
        .toList();

    expect(events.whereType<SessionReclaimed>(), hasLength(1));
    expect(
      gateway.methods.where((method) => method == 'image.attach_bytes'),
      hasLength(1),
    );
    expect(gateway.methods, isNot(contains('prompt.submit')));
    expect(gateway.methods, isNot(contains('image.detach')));
  });

  test(
    'an upload error after reclaim preserves takeover without partial cleanup',
    () async {
      final gateway = FakeGateway();
      gateway.handlers['image.attach_bytes'] = (_) => {
        'attached': true,
        'path': '/tmp/first-image.png',
      };
      gateway.handlers['file.attach'] = (params) {
        gateway.event('session.reclaimed', '', {
          'session_id': params['session_id'],
          'stored_session_id': 'stored-1',
          'reason': 'Another client took over',
        });
        throw const FakeRpcError(-32000);
      };
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);

      final events = await transport
          .send(
            text: 'Keep these local',
            attachments: [
              OutgoingAttachment(
                name: 'first.png',
                kind: AttachmentKind.image,
                read: () async => Uint8List.fromList([1, 2, 3]),
              ),
              OutgoingAttachment(
                name: 'report.pdf',
                kind: AttachmentKind.file,
                read: () async => Uint8List.fromList([4, 5, 6]),
              ),
            ],
          )
          .toList();

      expect(events.whereType<SessionReclaimed>(), hasLength(1));
      expect(gateway.methods, isNot(contains('prompt.submit')));
      expect(gateway.methods, isNot(contains('image.detach')));
    },
  );

  test(
    'reconnect replays newer controls without restoring an older read snapshot',
    () {
      fakeAsync((clock) {
        final gateway = FakeGateway()
          ..stampSeq = true
          ..sendReady = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'stored_session_id': 'stored-1',
          'running': true,
        };
        Map<String, Object?> snapshot(String revision) => {
          'control': {
            'goal': null,
            'loop': null,
            'heartbeat': null,
            'revision': revision,
            'updated_at': 1,
          },
        };
        gateway.handlers['session.control.read'] = (_) => snapshot('baseline');
        final transport = HermesGatewayTransport(
          connect: gateway.connect,
          sleep: (_) async {},
        );
        final seen = <ChatEvent>[];
        final subscription = transport.send(text: 'Inspect').listen(seen.add);
        clock.flushMicrotasks();
        gateway.event('session.control.update', 'rt-1', snapshot('live'));
        clock.flushMicrotasks();
        gateway.drop();
        gateway.event('session.control.update', 'rt-1', snapshot('replayed'));
        clock.flushMicrotasks();
        expect(
          seen.whereType<SessionControlUpdated>().map(
            (e) => e.control.revision,
          ),
          ['baseline', 'live', 'replayed'],
        );
        unawaited(subscription.cancel());
        unawaited(transport.close());
        clock.flushMicrotasks();
      });
    },
  );
  test(
    'attachment restores control using the owning runtime and profile',
    () async {
      final gateway = FakeGateway()
        ..turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Done',
          'status': 'complete',
        });
      gateway.handlers['session.control.read'] = (_) => {
        'control': {
          'goal': null,
          'loop': null,
          'heartbeat': null,
          'revision': '',
          'updated_at': 0,
        },
      };
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);
      await transport.send(text: 'Inspect', profile: 'work').toList();
      expect(
        gateway.requests.where((r) => r['method'] == 'session.control.read'),
        hasLength(1),
      );
      expect(
        gateway.requests.singleWhere(
          (r) => r['method'] == 'session.control.read',
        )['params'],
        {'session_id': 'rt-1', 'profile': 'work'},
      );
    },
  );

  test('unsupported control reads leave ordinary chat usable', () async {
    final gateway = FakeGateway()
      ..turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });
    gateway.handlers['session.control.read'] = (_) =>
        throw const FakeRpcError(-32601);
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final events = await transport.send(text: 'Inspect').toList();
    expect(events.whereType<ReplyCompleted>(), hasLength(1));
  });

  test(
    'broadcast reclaim closes the owning stream without replaying the prompt',
    () async {
      final gateway = FakeGateway()
        ..turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Done',
          'status': 'complete',
        });
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('session.reclaimed', '', {
          'session_id': sid,
          'stored_session_id': 'stored-1',
          'reason': 'Another client reopened the session',
        });
        g.event('message.delta', sid, {'text': 'Stale output'});
        g.event('message.complete', sid, {
          'text': 'Stale output',
          'status': 'complete',
        });
      };
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);
      final events = await transport.send(text: 'Inspect').toList();
      expect(events.whereType<SessionReclaimed>(), hasLength(1));
      expect(events.whereType<ReplyDelta>(), isEmpty);
      expect(gateway.methods.where((m) => m == 'prompt.submit'), hasLength(1));
    },
  );

  test(
    'a live update during control read wins over its stale response',
    () async {
      final gateway = FakeGateway()
        ..turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Done',
          'status': 'complete',
        });
      gateway.handlers['session.control.read'] = (params) {
        gateway.event(
          'session.control.update',
          params['session_id'] as String,
          {
            'control': {
              'goal': null,
              'loop': null,
              'heartbeat': null,
              'revision': 'new',
              'updated_at': 2,
            },
          },
        );
        return {
          'control': {
            'goal': null,
            'loop': null,
            'heartbeat': null,
            'revision': 'old',
            'updated_at': 1,
          },
        };
      };
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);
      final events = await transport.send(text: 'Inspect').toList();
      expect(
        events.whereType<SessionControlUpdated>().map(
          (e) => e.control.revision,
        ),
        ['new'],
      );
      expect(gateway.methods, contains('session.control.read'));
    },
  );
}
