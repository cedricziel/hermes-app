import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

/// A sender that must not ask twice reads whether the server has the prompt.
void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });

  tearDown(() => transport.close());

  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'timed out waiting');
  }

  bool submitted() =>
      gateway.requests.any((r) => r['method'] == 'prompt.submit');

  test('is false before anything was sent', () {
    expect(transport.promptAccepted, isFalse);
  });

  test('turns true when prompt.submit is answered, before any frame', () async {
    final release = Completer<void>();
    gateway.turn = (g, sid) => unawaited(
      release.future.then(
        (_) => g.event('message.complete', sid, {
          'text': 'Hi',
          'status': 'complete',
        }),
      ),
    );
    final events = <ChatEvent>[];
    final done = transport.send(text: 'hi').forEach(events.add);

    await until(submitted);
    await until(() => transport.promptAccepted);
    expect(events.where((e) => e is! ThreadBound), isEmpty);

    release.complete();
    await done.timeout(const Duration(seconds: 5));
    expect(transport.promptAccepted, isTrue);
  });

  test('stays false when the server rejects the prompt', () async {
    gateway.handlers['prompt.submit'] = (_) =>
        throw const FakeRpcError(4009, 'session busy');

    await expectLater(
      transport.send(text: 'hi').toList().timeout(const Duration(seconds: 5)),
      throwsA(anything),
    );

    expect(transport.promptAccepted, isFalse);
  });

  test('starts again from false with the next send', () async {
    gateway.turn = (g, sid) =>
        g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
    await transport
        .send(text: 'one')
        .toList()
        .timeout(const Duration(seconds: 5));
    expect(transport.promptAccepted, isTrue);
    gateway.handlers['prompt.submit'] = (_) =>
        throw const FakeRpcError(4009, 'session busy');

    final second = transport.send(text: 'two');

    expect(transport.promptAccepted, isFalse);
    await expectLater(
      second.toList().timeout(const Duration(seconds: 5)),
      throwsA(anything),
    );
  });
}
