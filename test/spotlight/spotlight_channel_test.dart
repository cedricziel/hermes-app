import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/spotlight/spotlight_index.dart';

const _channel = 'hermes_app/spotlight';

/// What the Runner sends the engine that shows the app.
Future<void> _runnerCalls(String method) {
  final done = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) => done.complete(),
      );
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the index of a background engine', () {
    test('hears nothing from the Runner', () async {
      final index = ChannelSpotlightIndex(indexOnly: true);
      addTearDown(index.dispose);
      var heard = 0;
      final subscription = index.becameAvailable.listen((_) => heard++);
      addTearDown(subscription.cancel);

      await _runnerCalls('becameAvailable');
      await pumpEventQueue();

      expect(heard, 0);
    });

    test('is told apart from the engine that shows the app', () async {
      final index = ChannelSpotlightIndex();
      addTearDown(index.dispose);
      var heard = 0;
      final subscription = index.becameAvailable.listen((_) => heard++);
      addTearDown(subscription.cancel);

      await _runnerCalls('becameAvailable');
      await pumpEventQueue();

      expect(heard, 1);
    });
  });

  group('Spotlight.swift', () {
    // The Runner has no test target, so the rule that a background engine
    // never takes the taps is pinned in the source: its channel is a local one
    // with a handler that refuses `take`, and it never replaces `channel`.
    final source = File('ios/Runner/Spotlight.swift').readAsStringSync();

    String body(String signature) {
      final start = source.indexOf(signature);
      expect(start, isNonNegative, reason: '$signature is gone');
      var depth = 0;
      for (var i = source.indexOf('{', start); i < source.length; i++) {
        if (source[i] == '{') depth++;
        if (source[i] == '}' && --depth == 0) {
          return source.substring(start, i + 1);
        }
      }
      fail('$signature is not closed');
    }

    test('installIndexing leaves the app engine\'s channel and observers', () {
      final indexing = body('func installIndexing(');

      expect(indexing, contains('takesTaps: false'));
      expect(indexing, isNot(contains('self.channel =')));
      expect(indexing, isNot(contains('NotificationCenter')));
      expect(indexing, isNot(contains('observing')));
    });

    test('install takes the taps, and take answers only to it', () {
      expect(body('func install('), contains('takesTaps: true'));
      expect(body('private func handle('), contains('guard takesTaps else'));
    });
  });
}
