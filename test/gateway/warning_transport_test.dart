import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  test('warnings replay across reconnect without duplicate delivery', () {
    fakeAsync((clock) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true;
      gateway.resumeResult = {
        'session_id': 'rt-1',
        'stored_session_id': 'stored-1',
        'running': true,
      };
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        sleep: (_) async {},
      );
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(text: 'Observe warnings')
          .listen(seen.add);
      clock.flushMicrotasks();
      gateway.event('message.start', 'rt-1');
      gateway.event('notification.show', 'rt-1', {
        'text': 'First',
        'key': 'credit',
        'kind': 'sticky',
        'level': 'warn',
      });
      clock.flushMicrotasks();
      gateway.drop();
      gateway.event('notification.show', 'rt-1', {
        'text': 'Replacement',
        'key': 'credit',
        'kind': 'sticky',
        'level': 'warn',
      });
      gateway.event('notification.clear', 'rt-1', {'key': 'credit'});
      clock.flushMicrotasks();
      expect(seen.whereType<NoticeShown>().map((e) => e.notice.text), [
        'First',
        'Replacement',
      ]);
      expect(seen.whereType<NoticeCleared>(), hasLength(1));
      expect(gateway.methods.where((m) => m == 'prompt.submit'), hasLength(1));
      unawaited(subscription.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });

  for (final invalidation in ['epoch', 'truncated', 'unsupported']) {
    test(
      'untrusted $invalidation replay discards warning scope before new frames',
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
          final transport = HermesGatewayTransport(
            connect: gateway.connect,
            sleep: (_) async {},
          );
          final seen = <ChatEvent>[];
          final subscription = transport
              .send(text: 'Observe warnings')
              .listen(seen.add);
          clock.flushMicrotasks();
          gateway.event('message.start', 'rt-1');
          gateway.event('notice', 'rt-1', {'message': 'Old notice'});
          clock.flushMicrotasks();
          gateway.drop();
          if (invalidation == 'epoch') gateway.epoch = 'epoch-2';
          if (invalidation == 'truncated') gateway.truncateReplay = true;
          if (invalidation == 'unsupported') {
            gateway.unknownMethods.add('session.events.since');
          }
          gateway.beforeResumeAnswer = (g) =>
              g.event('notice', 'rt-1', {'message': 'New notice'});
          clock.flushMicrotasks();
          final discard = seen.indexWhere(
            (event) => event is WarningScopeDiscarded,
          );
          final replacement = seen.indexWhere(
            (event) =>
                event is NoticeShown && event.notice.text == 'New notice',
          );
          expect(discard, greaterThanOrEqualTo(0));
          expect(replacement, greaterThan(discard));
          expect(seen.whereType<WarningScopeDiscarded>(), hasLength(1));
          unawaited(subscription.cancel());
          unawaited(transport.close());
          clock.flushMicrotasks();
        });
      },
    );
  }

  test('same epoch replay preserves warning scope', () {
    fakeAsync((clock) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true;
      gateway.resumeResult = {
        'session_id': 'rt-1',
        'stored_session_id': 'stored-1',
        'running': true,
      };
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        sleep: (_) async {},
      );
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(text: 'Observe warnings')
          .listen(seen.add);
      clock.flushMicrotasks();
      gateway.event('message.start', 'rt-1');
      gateway.event('notice', 'rt-1', {'message': 'Sticky notice'});
      clock.flushMicrotasks();
      gateway.drop();
      clock.flushMicrotasks();
      expect(seen.whereType<WarningScopeDiscarded>(), isEmpty);
      unawaited(subscription.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });

  test('only warnings from the attached session reach its reply', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) {
      g.event('notification.show', 'other-runtime', {
        'text': 'Wrong owner',
        'level': 'warn',
        'kind': 'sticky',
      });
      g.event('notice', sid, {'message': 'Capabilities refreshed'});
      g.event('message.complete', sid, {'text': 'Done', 'status': 'complete'});
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    final events = await transport.send(text: 'Inspect').toList();
    expect(
      events.whereType<NoticeShown>().single.notice.text,
      'Capabilities refreshed',
    );
    await transport.close();
  });
}
