import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/calls/call_tts_lease.dart';

import '../../support/fake_hermes_server.dart';
import 'call_harness.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', '/api/audio/tts-lease', {'ok': true});
  });

  CallTtsLease lease({String? profile = 'work'}) =>
      CallTtsLease(HermesChatRepository(server.client().raw), profile: profile);

  Map<String, Object?> body(RequestOptions r) =>
      (r.data is String ? jsonDecode(r.data as String) : r.data)
          as Map<String, Object?>;

  List<Map<String, Object?>> posted() => [
    for (final r in server.requestsTo('POST', '/api/audio/tts-lease')) body(r),
  ];

  test('holds and releases one opaque lease of the call', () async {
    final held = lease();
    await held.hold();
    await held.release();
    final sent = posted();
    expect(sent, hasLength(2));
    expect(sent[0]['active'], isTrue);
    expect(sent[1]['active'], isFalse);
    expect(sent[0]['lease'], held.id);
    expect(sent[1]['lease'], held.id);
    expect(held.id, matches(RegExp(r'^app:conversation:[0-9a-f-]{36}$')));
    final profiles = server
        .requestsTo('POST', '/api/audio/tts-lease')
        .map((r) => r.queryParameters['profile']);
    expect(profiles, ['work', 'work']);
  });

  test('every call has its own id, and none carries the server', () {
    final a = lease(), b = lease();
    expect(a.id, isNot(b.id));
    expect(a.id, isNot(contains('hermes.test')));
    expect(a.id, isNot(contains('work')));
  });

  test('a server that refuses throws, for the call to ignore', () async {
    server.on('POST', '/api/audio/tts-lease', {'detail': 'x'}, status: 404);
    await expectLater(lease().hold(), throwsA(anything));
  });

  test('a call holds it for its length and drops it on End', () async {
    final h = CallHarness();
    addTearDown(h.dispose);
    final held = lease();
    await h.rebuild(holdLease: held.hold, releaseLease: held.release);
    await h.activate();
    await pumpEventQueue();
    expect(posted().map((e) => e['active']), [true]);
    await h.call.end();
    expect(posted().map((e) => e['active']), [true, false]);
  });

  test('a call with Speak replies off never touches the server', () async {
    final h = CallHarness();
    addTearDown(h.dispose);
    final held = lease();
    await h.rebuild(holdLease: held.hold, releaseLease: held.release);
    h.call.setSpeakReplies(false);
    await h.activate();
    await h.call.end();
    expect(posted(), isEmpty);
  });
}
