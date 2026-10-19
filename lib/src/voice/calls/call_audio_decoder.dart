// The catalog also compiles chat screens for the web. Keep libmpv's native
// property API out of that compilation; calls themselves require native audio.
export 'call_audio_decoder_stub.dart'
    if (dart.library.io) 'call_audio_decoder_native.dart';
