import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/voice/voice_playback.dart';
import 'package:hermes_app/src/voice/voice_audio_focus.dart';

import '../support/fake_voice_player.dart';

void main() {
  late FakeVoicePlayer player;
  late VoicePlayback playback;
  late int fetches;
  Future<File> fetch() async {
    fetches++;
    return File('/cache/voice.ogg');
  }

  setUp(() {
    player = FakeVoicePlayer();
    fetches = 0;
    playback = VoicePlayback(createPlayer: () => player);
  });
  tearDown(() => playback.dispose());

  test(
    'loads on demand, pauses, resumes and seeks without fetching again',
    () async {
      expect(fetches, 0);
      expect(player.loaded, isEmpty);
      await playback.toggle('a', fetch);
      expect(playback.playing, isTrue);
      expect(player.loaded, ['/cache/voice.ogg']);
      await playback.seek(const Duration(seconds: 12));
      expect(playback.position, const Duration(seconds: 12));
      await playback.toggle('a', fetch);
      expect(playback.playing, isFalse);
      await playback.toggle('a', fetch);
      expect(playback.playing, isTrue);
      expect(fetches, 1);
      expect(playback.duration, const Duration(seconds: 48));
    },
  );

  test('switching messages pauses the first and replaces its source', () async {
    await playback.toggle('a', fetch);
    await playback.toggle('b', () async => File('/cache/second.mp3'));
    expect(player.pauses, 2);
    expect(player.loaded, ['/cache/voice.ogg', '/cache/second.mp3']);
    expect(playback.active, 'b');
    expect(playback.position, Duration.zero);
    expect(player.plays, 2);
  });

  test('a completed clip replays from the start', () async {
    await playback.toggle('a', fetch);
    player.finish();
    expect(playback.playing, isFalse);
    await playback.toggle('a', fetch);
    expect(player.seeks.last, Duration.zero);
    expect(player.plays, 2);
    expect(fetches, 1);
  });

  test('a failed download can be retried', () async {
    await playback.toggle(
      'a',
      () async => throw const MediaFetchException(MediaFailure.failed),
    );
    expect(playback.active, 'a');
    expect(playback.error, contains('download'));
    expect(playback.canRetry, isTrue);
    expect(playback.loading, isFalse);
    await playback.toggle('a', fetch);
    expect(playback.error, isNull);
    expect(playback.playing, isTrue);
  });

  for (final reason in [
    MediaFailure.missing,
    MediaFailure.refused,
    MediaFailure.tooLarge,
  ]) {
    test('a $reason response shows an unavailable clip', () async {
      await playback.toggle('a', () async => throw MediaFetchException(reason));
      expect(playback.error, isNotNull);
      expect(playback.canRetry, isFalse);
      expect(player.plays, 0);
    });
  }

  test(
    'decoder errors are recoverable, including late native errors',
    () async {
      player.failLoad = true;
      await playback.toggle('a', fetch);
      expect(playback.error, contains('play'));
      player.failLoad = false;
      await playback.toggle('a', fetch);
      expect(playback.playing, isTrue);
      player.fail();
      expect(playback.playing, isFalse);
      expect(playback.error, isNotNull);
      await playback.toggle('a', fetch);
      expect(playback.playing, isTrue);
      expect(playback.error, isNull);
    },
  );

  test('repeated taps while downloading start just one load', () async {
    final gate = Completer<File>();
    final first = playback.toggle('a', () => gate.future);
    await playback.toggle('a', fetch);
    await playback.toggle('b', fetch);
    expect(playback.loading, isTrue);
    gate.complete(File('/cache/voice.ogg'));
    await first;
    expect(player.plays, 1);
    expect(fetches, 0);
  });

  test(
    'suspending a pending download never starts playback afterwards',
    () async {
      final gate = Completer<File>();
      final first = playback.toggle('a', () => gate.future);
      await Future<void>.delayed(Duration.zero);
      await playback.pause();
      gate.complete(File('/cache/voice.ogg'));
      await first;
      expect(player.loaded, isEmpty);
      expect(player.plays, 0);
      await playback.toggle('a', fetch);
      expect(playback.playing, isTrue);
    },
  );

  test(
    'disposing while a file downloads releases the player and ignores it',
    () async {
      final gate = Completer<File>();
      final first = playback.toggle('a', () => gate.future);
      await Future<void>.delayed(Duration.zero);
      playback.dispose();
      gate.complete(File('/cache/voice.ogg'));
      await first;
      expect(player.disposed, isTrue);
      expect(player.loaded, isEmpty);
      expect(player.plays, 0);
      // Avoid disposing twice in tearDown.
      playback = VoicePlayback(createPlayer: FakeVoicePlayer.new);
    },
  );
  test(
    'a native call pauses playback and blocks play/seek until it ends',
    () async {
      final call = Object();
      await playback.toggle('a', fetch);
      await VoiceAudioFocus.shared.acquire(call);
      try {
        expect(playback.blocked, isTrue);
        expect(player.playing, isFalse);
        await playback.toggle('a', fetch);
        await playback.seek(const Duration(seconds: 5));
        expect(player.plays, 1);
        expect(player.seeks, isEmpty);
      } finally {
        VoiceAudioFocus.shared.release(call);
      }
      await playback.toggle('a', fetch);
      expect(player.plays, 2);
    },
  );
  test('a pending download cannot acquire audio after a call starts', () async {
    final call = Object();
    final download = Completer<File>();
    final playing = playback.toggle('a', () => download.future);
    await Future<void>.delayed(Duration.zero);
    await VoiceAudioFocus.shared.acquire(call);
    try {
      download.complete(File('/cache/voice.ogg'));
      await playing;
      expect(player.plays, 0);
      expect(player.loaded, isEmpty);
    } finally {
      VoiceAudioFocus.shared.release(call);
    }
  });
}
