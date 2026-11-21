import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/portable_call_audio.dart';

class _Platform implements AndroidCallPlatform {
  final log = <String>[];
  Exception? firstReleaseError;
  Completer<void>? releaseGate;
  Completer<void>? configureGate;
  bool grant = true;
  int _setActiveCalls = 0;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    log.add('configure');
    await configureGate?.future;
  }

  @override
  Future<bool> setActive(bool active) async {
    log.add('setActive:$active');
    if (!active && _setActiveCalls++ == 0) {
      await releaseGate?.future;
      if (firstReleaseError != null) throw firstReleaseError!;
    }
    return active ? grant : true;
  }

  @override
  Stream<AudioInterruptionEvent> get interruptions => const Stream.empty();
  @override
  Stream<void> get becomingNoisy => const Stream.empty();
  @override
  Stream<void> get devicesChanged => const Stream.empty();
  @override
  Future<void> setMode(AndroidAudioHardwareMode mode) async => log.add(
    mode == AndroidAudioHardwareMode.inCommunication
        ? 'mode:inCommunication'
        : 'mode:other',
  );
  @override
  Future<void> setSpeakerphoneOn(bool on) async => log.add('speaker:$on');
}

void main() {
  test('gives back an earlier focus request before making its own', () async {
    final platform = _Platform();
    await AndroidCallAudioSession(platform: platform).activate();
    expect(platform.log, [
      'setActive:false',
      'configure',
      'setActive:true',
      'mode:inCommunication',
    ]);
  });

  test('a failing or silent release does not fail the start', () async {
    final failing = _Platform()..firstReleaseError = Exception('boom');
    await AndroidCallAudioSession(platform: failing).activate();
    expect(failing.log, contains('setActive:true'));

    final silent = _Platform()..releaseGate = Completer<void>();
    await AndroidCallAudioSession(
      platform: silent,
      releaseTimeout: const Duration(milliseconds: 20),
    ).activate();
    expect(silent.log, contains('setActive:true'));
  });

  test(
    'a deactivate during the release gives focus back, requests none',
    () async {
      final platform = _Platform()..releaseGate = Completer<void>();
      final session = AndroidCallAudioSession(platform: platform);
      final activating = session.activate();
      await Future<void>.delayed(Duration.zero);
      final deactivating = session.deactivate();
      platform.releaseGate!.complete();
      await Future.wait([activating, deactivating]);
      expect(platform.log, isNot(contains('setActive:true')));
      expect(platform.log, isNot(contains('configure')));
      expect(platform.log.last, 'setActive:false');
    },
  );

  test(
    'a deactivate during configure gives focus back and takes none',
    () async {
      final platform = _Platform()..configureGate = Completer<void>();
      final session = AndroidCallAudioSession(platform: platform);
      final activating = session.activate();
      await Future<void>.delayed(Duration.zero);
      final deactivating = session.deactivate();
      platform.configureGate!.complete();
      await Future.wait([activating, deactivating]);
      expect(platform.log, isNot(contains('setActive:true')));
      expect(platform.log.last, 'setActive:false');
    },
  );

  test('an activate after deactivate does nothing', () async {
    final platform = _Platform();
    final session = AndroidCallAudioSession(platform: platform);
    await session.deactivate();
    await session.activate();
    expect(platform.log, isEmpty);
  });

  test('refused focus fails the start and gives it back', () async {
    final platform = _Platform()..grant = false;
    await expectLater(
      AndroidCallAudioSession(platform: platform).activate(),
      throwsStateError,
    );
    expect(platform.log.last, 'setActive:false');
  });
}
