Synthetic 440 Hz mono tones, generated with FFmpeg; no recorded speech.
Each fixture is 0.4 seconds at 24 kHz. The two OGG files exercise both Opus
and Vorbis, since the container extension alone does not identify the codec.

Generation (use `libopus`, `libvorbis`, `libmp3lame`, `aac`, `pcm_s16le`, or
`flac` and the corresponding filename):

```sh
ffmpeg -f lavfi -i sine=frequency=440:duration=0.4 -ar 24000 -ac 1 -c:a libopus opus.ogg
```

Run the real native decoder smoke tests on Linux with `libmpv2` installed
(`sudo apt install libmpv2` on Debian/Ubuntu):

```sh
flutter test test/voice/native_voice_player_test.dart --dart-define=HERMES_NATIVE_AUDIO_TEST=true
```

Set `HERMES_LIBMPV` to a full shared-library path when it is outside the
system library search path. Tests use silent output and verify decoding,
duration, and playback completion for every fixture. Native iOS audio routing
and device interruptions still need an iPhone/simulator check.
