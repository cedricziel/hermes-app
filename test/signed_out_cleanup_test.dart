import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_message_record.dart';
import 'package:hermes_app/src/core/signed_out_cleanup.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late StreamController<void> signedOut;

  setUp(() => signedOut = StreamController<void>.broadcast(sync: true));
  tearDown(() => signedOut.close());

  test('cleans up each time the session ends', () async {
    var cleaned = 0;
    final cleanup = SignedOutCleanup(signedOut.stream, () async => cleaned++);
    addTearDown(cleanup.dispose);

    signedOut
      ..add(null)
      ..add(null);
    await pumpEventQueue();

    expect(cleaned, 2);
  });

  test('stops listening once disposed', () async {
    var cleaned = 0;
    final cleanup = SignedOutCleanup(signedOut.stream, () async => cleaned++);

    await cleanup.dispose();
    signedOut.add(null);
    await pumpEventQueue();

    expect(cleaned, 0);
    expect(signedOut.hasListener, isFalse);
  });

  test('a cleanup that fails does not end the listening', () async {
    var calls = 0;
    final cleanup = SignedOutCleanup(signedOut.stream, () async {
      calls++;
      throw StateError('disk full');
    });
    addTearDown(cleanup.dispose);

    signedOut
      ..add(null)
      ..add(null);
    await pumpEventQueue();

    expect(calls, 2);
  });

  test('forgets which messages from Hermes were seen', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final record = AgentMessageRecord();
    await record.write('acct', {'default': 5});
    final cleanup = SignedOutCleanup(signedOut.stream, record.clear);
    addTearDown(cleanup.dispose);

    signedOut.add(null);
    await pumpEventQueue();

    expect(await record.read('acct'), isNull);
  });
}
