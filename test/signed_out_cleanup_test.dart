import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/core/signed_out_cleanup.dart';

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
}
