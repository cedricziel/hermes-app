import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/voice_player.dart';

void main() {
  // `AudioSession.setActive(false)` takes its options from the configuration,
  // and the platform check inside it cannot be faked on the test host, so the
  // configuration is what is pinned here.
  test('deactivating a voice playback notifies the apps it interrupted', () {
    final json = voicePlaybackSession.toJson();

    expect(
      voicePlaybackSession.avAudioSessionSetActiveOptions,
      AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    );
    expect(json['avAudioSessionSetActiveOptions'], 1);
  });

  test('Android takes the focus transiently, ducking others', () {
    expect(
      voicePlaybackSession.androidAudioFocusGainType,
      AndroidAudioFocusGainType.gainTransientMayDuck,
    );
  });

  test('the session stays the speech recipe otherwise', () {
    final speech = const AudioSessionConfiguration.speech();

    expect(
      voicePlaybackSession.avAudioSessionCategory,
      speech.avAudioSessionCategory,
    );
    expect(voicePlaybackSession.avAudioSessionMode, speech.avAudioSessionMode);
    expect(
      voicePlaybackSession.avAudioSessionCategoryOptions,
      speech.avAudioSessionCategoryOptions,
    );
  });
}
