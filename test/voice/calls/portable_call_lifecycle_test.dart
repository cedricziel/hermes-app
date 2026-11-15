import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show SoLoud;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_bridge.dart';
import 'package:hermes_app/src/voice/calls/portable_call_audio.dart';
import 'package:hermes_app/src/voice/calls/portable_call_bridge.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:stream_channel/stream_channel.dart';

import 'call_harness.dart';
import 'fakes.dart';
import 'portable_fakes.dart';

/// A [VoiceCall] on the real [PortableCallBridge], with fakes for what it
/// opens: the recorder, the player and the audio session.
class _Portable {
  _Portable(this.platform) {
    rig = Rig(session: platform == TargetPlatform.android);
    agent = FakeCallAgent()..log = rig.log;
    socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    call = VoiceCall(
      bridge: rig.bridge,
      agent: agent,
      consented: true,
      platform: platform,
      prepare: () async {},
      connect: ([_ = const {}]) async => socket.local,
      events: (name, [attributes = const {}]) => logged.add((name, attributes)),
      transcribe: (_) async => transcripts.removeAt(0),
    );
  }

  final TargetPlatform platform;
  late final Rig rig;
  late final FakeCallAgent agent;
  late final StreamChannelController<Object?> socket;
  late final VoiceCall call;
  final transcripts = <String>[];
  final logged = <(String, Map<String, Object>)>[];

  FakeRecorder get recorder => rig.recorder;

  Future<void> started() async {
    await call.start();
    await pumpEventQueue();
    expect(recorder.open, isTrue, reason: 'the call opened the microphone');
  }

  /// One spoken turn: a loud half second, then quiet.
  Future<void> say(String text) async {
    transcripts.add(text);
    recorder.add(pcm());
    for (var i = 0; i < 9; i++) {
      recorder.add(pcm(amplitude: 0));
    }
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    if (!call.ended) await call.end();
    call.dispose();
  }
}

/// A `.clear(` on anything named like the preferences: `prefs.clear(`,
/// `_prefs.clear(`, `preferences.clear(`, `SharedPreferencesAsync().clear(`,
/// `SharedPreferences.getInstance().clear(` and the like.
final _clearsPrefs = RegExp(
  r'(prefs|preferences|sharedpreferences\w*)(\.\w+)?(\(\))?[?!]?\.clear\(',
  caseSensitive: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const desktop = [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ];
  late _Portable p;
  void make(TargetPlatform platform) {
    p = _Portable(platform);
    addTearDown(() => p.dispose());
  }

  group('nothing of the audio engine runs before a call starts', () {
    for (final platform in [TargetPlatform.android, ...desktop]) {
      test(
        'making the bridge on $platform starts neither engine nor audio',
        () {
          final bridge = createCallBridge(platform: platform);
          expect(bridge, isA<PortableCallBridge>());
          expect(SoLoud.instance.isInitialized, isFalse);
        },
      );
    }

    test('iOS gets CallKit\'s bridge and no engine', () {
      expect(
        createCallBridge(platform: TargetPlatform.iOS),
        isA<AppleCallBridge>(),
      );
      expect(SoLoud.instance.isInitialized, isFalse);
    });

    test('only the portable audio file reaches for flutter_soloud', () {
      final users = [
        for (final entity in Directory('lib').listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              entity.readAsStringSync().contains('package:flutter_soloud'))
            entity.path,
      ];
      expect(users, ['lib/src/voice/calls/portable_call_audio.dart']);
    });

    test('the scan knows what clearing preferences looks like', () {
      for (final code in [
        'prefs.clear();',
        '_prefs.clear()',
        'preferences.clear();',
        'await SharedPreferencesAsync().clear();',
        'SharedPreferences.getInstance().clear()',
        'widget.prefs?.clear();',
      ]) {
        expect(code, matches(_clearsPrefs), reason: code);
      }
      for (final code in ['items.clear();', 'controller.clear()']) {
        expect(code, isNot(matches(_clearsPrefs)), reason: code);
      }
    });

    test('nothing wholesale clears the saved preferences', () {
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        expect(
          entity.readAsStringSync(),
          isNot(matches(_clearsPrefs)),
          reason: '${entity.path} would reset the calls switch',
        );
      }
    });
  });

  group('End', () {
    for (final platform in [TargetPlatform.android, ...desktop]) {
      test(
        'closes the microphone and releases the audio on $platform',
        () async {
          make(platform);
          await p.started();
          await p.call.end();
          expect(p.call.ended, isTrue);
          expect(p.call.microphoneUnconfirmed, isFalse);
          expect(p.recorder.open, isFalse);
          expect(p.rig.player.disposes, 1);
          expect(p.recorder.disposes, 1);
          // The capture closes first, the audio session last.
          final log = p.rig.log;
          expect(
            log.indexOf('recorder.stop'),
            lessThan(log.indexOf('player.dispose')),
          );
          if (platform == TargetPlatform.android) {
            expect(p.rig.audioSession!.deactivations, 1);
            expect(
              log.indexOf('player.dispose'),
              lessThan(log.indexOf('session.deactivate')),
            );
          }
        },
      );
    }

    test(
      'Android gives the audio focus back, once, and takes it once',
      () async {
        make(TargetPlatform.android);
        await p.started();
        expect(p.rig.audioSession!.activations, 1);
        await p.call.end();
        await p.call.end();
        expect(p.rig.audioSession!.deactivations, 1);
      },
    );

    test('nothing reopens the microphone after it', () async {
      make(TargetPlatform.android);
      await p.started();
      final starts = p.recorder.starts;
      await p.call.end();
      p.rig.audioSession!.routesController.add(null);
      await p.rig.bridge.resumeCapture();
      await p.rig.bridge.mute(false);
      await pumpEventQueue();
      expect(p.recorder.starts, starts);
      expect(p.recorder.open, isFalse);
    });

    test('a recorder that cannot be stopped is said, not hidden', () async {
      make(TargetPlatform.linux);
      await p.started();
      p.recorder.stopGate = Completer<void>();
      await p.call.end();
      expect(p.call.microphoneUnconfirmed, isTrue);
    });
  });

  group('whoever owns the call lets go of it', () {
    // Sign-out, an account change and a profile switch all end the call from
    // the chat (`VoiceCall.end`); what it must leave behind is the same.
    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      test('end() from outside leaves no microphone on $platform', () async {
        make(platform);
        await p.started();
        await p.say('Hello');
        await p.call.end();
        expect(p.recorder.open, isFalse);
        expect(p.call.endReason, 'app');
        if (platform == TargetPlatform.android) {
          expect(p.rig.audioSession!.deactivations, 1);
        }
      });
    }

    test(
      'a permanent loss of audio focus ends it and frees the focus',
      () async {
        make(TargetPlatform.android);
        await p.started();
        p.rig.audioSession!.interruptionsController.add(
          AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await pumpEventQueue();
        expect(p.call.ended, isTrue);
        expect(p.call.endReason, 'focus_lost');
        expect(p.recorder.open, isFalse);
        expect(p.rig.audioSession!.deactivations, 1);
      },
    );

    test('ducking keeps the call and the microphone', () async {
      make(TargetPlatform.android);
      await p.started();
      p.rig.audioSession!.interruptionsController.add(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      await pumpEventQueue();
      expect(p.call.ended, isFalse);
      expect(p.recorder.open, isTrue);
    });
  });

  group('the window is hidden or minimised', () {
    for (final platform in [TargetPlatform.android, ...desktop]) {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        test(
          '$state ends a call on $platform and closes the microphone',
          () async {
            make(platform);
            await p.started();
            p.call.lifecycleChanged(state);
            await pumpEventQueue();
            expect(p.call.ended, isTrue);
            expect(p.call.endReason, 'background');
            expect(p.recorder.open, isFalse);
            expect(p.rig.player.disposes, 1);
          },
        );
      }
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        test('$state does not end it on $platform', () async {
          make(platform);
          await p.started();
          p.call.lifecycleChanged(state);
          await pumpEventQueue();
          expect(p.call.ended, isFalse);
          expect(p.recorder.open, isTrue);
        });
      }
    }
  });

  group('privacy', () {
    const heard = 'my passphrase is swordfish';
    const reply = 'your account number is 998877';
    const device = "Alice's Pixel Buds Pro";

    test(
      'no audio, words or device name reach the logs or the console',
      () async {
        final printed = <String>[];
        final previousDebug = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add('$message');
        addTearDown(() => debugPrint = previousDebug);
        await runZoned(
          () async {
            make(TargetPlatform.android);
            await p.started();
            await p.say(heard);
            p.agent.text!(reply);
            p.socket.foreign.sink
              ..add(
                jsonEncode({
                  'type': 'start',
                  'sample_rate': 24000,
                  'channels': 1,
                }),
              )
              ..add([7, 7, 7, 7]);
            await pumpEventQueue();
            // A device comes and goes; the platform may name it.
            await p.rig.bridge.speaker(true);
            p.rig.audioSession!.routesController.add(null);
            await pumpEventQueue();
            // A bridge that did name a device still has it logged nowhere.
            p.rig.events.add({
              'type': 'route',
              'name': device,
              'speaker': false,
            });
            await p.call.end();
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => printed.add(line),
          ),
        );
        final everything = jsonEncode([
          for (final (name, attributes) in p.logged) [name, attributes],
          printed,
        ]);
        for (final secret in [
          'swordfish',
          'passphrase',
          '998877',
          'account number',
          'Pixel',
          'Alice',
          '[7',
        ]) {
          expect(everything, isNot(contains(secret)), reason: secret);
        }
        expect(p.logged.map((e) => e.$1), contains('voice_call.ended'));
      },
    );

    test('a route named after a device is shown, never logged', () async {
      final h = CallHarness();
      addTearDown(h.dispose);
      await h.rebuild(platform: TargetPlatform.android);
      await h.activate();
      h.bridge.emit('route', {'name': device, 'speaker': false});
      await pumpEventQueue();
      expect(h.call.route, device);
      await h.call.end();
      expect(h.logged, isNotEmpty);
      expect(
        jsonEncode([
          for (final (name, attributes) in h.logged) [name, attributes],
        ]),
        isNot(contains('Pixel')),
      );
    });

    test(
      'the bridge sends only fixed words besides the audio itself',
      () async {
        make(TargetPlatform.android);
        await p.started();
        await p.rig.bridge.speaker(true);
        await p.rig.bridge.pauseCapture();
        await p.rig.bridge.resumeCapture();
        p.rig.audioSession!.routesController.add(null);
        await pumpEventQueue();
        await p.call.end();
        const fixed = {
          'activated',
          'pcm',
          'muted',
          'route',
          'audioReset',
          'capturePaused',
          'deactivated',
          'error',
        };
        const words = {
          'Speaker',
          'Phone',
          'request',
          'playback',
          'audio_start',
        };
        for (final event in p.rig.events) {
          expect(fixed, contains(event['type']));
          for (final entry in event.entries) {
            final value = entry.value;
            if (value is String && entry.key != 'type') {
              expect(words, contains(value));
            }
          }
        }
      },
    );

    test('the portable audio code has no logging of its own', () {
      for (final path in [
        'lib/src/voice/calls/portable_call_bridge.dart',
        'lib/src/voice/calls/portable_call_audio.dart',
        'lib/src/voice/calls/echo_guard.dart',
        'lib/src/voice/calls/portable_call_settings.dart',
      ]) {
        final source = File(path).readAsStringSync();
        for (final call in ['print(', 'debugPrint', 'Breadcrumbs', 'log(']) {
          expect(source, isNot(contains(call)), reason: '$path uses $call');
        }
      }
    });
  });
}
