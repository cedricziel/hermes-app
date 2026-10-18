import 'dart:math' as math;
import 'dart:typed_data';

/// Bounded utterance segmentation of the call's echo-cancelled 16 kHz mono
/// PCM. Speech onset needs 100 ms; a 900 ms pause ends the utterance. Keeps
/// 200 ms before onset, so initial consonants are not cut off.
class VoiceActivity {
  static const sampleRate = 16000;
  final _preRoll = <Uint8List>[];
  final _speech = BytesBuilder(copy: false);
  int _preSamples = 0;
  int _samples = 0;
  int _voiced = 0;
  int _quiet = 0;
  double _floor = 0.003;
  bool _started = false;

  ({bool started, Uint8List? utterance}) add(Uint8List bytes) {
    if (bytes.length.isOdd || bytes.isEmpty) {
      return (started: false, utterance: null);
    }
    final view = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    var squares = 0.0;
    for (var i = 0; i < bytes.length; i += 2) {
      final sample = view.getInt16(i, Endian.little) / 32768;
      squares += sample * sample;
    }
    final level = math.sqrt(squares / count);
    final voiced = level > math.max(0.015, _floor * 3);
    if (!_started && !voiced) {
      _floor = (_floor * 0.98 + level * 0.02).clamp(0.001, 0.03);
    }
    if (!_started) {
      _preRoll.add(bytes);
      _preSamples += count;
      _voiced = voiced ? _voiced + count : 0;
      while (_preSamples > sampleRate ~/ 5 + _voiced && _preRoll.length > 1) {
        _preSamples -= _preRoll.removeAt(0).length ~/ 2;
      }
      if (_voiced < sampleRate ~/ 10) return (started: false, utterance: null);
      _started = true;
      for (final frame in _preRoll) {
        _speech.add(frame);
      }
      _samples = _preSamples;
      _preRoll.clear();
      _preSamples = 0;
      _quiet = 0;
      return (started: true, utterance: null);
    }
    _speech.add(bytes);
    _samples += count;
    _quiet = voiced ? 0 : _quiet + count;
    if (_quiet < sampleRate * 9 ~/ 10 && _samples < sampleRate * 60) {
      return (started: false, utterance: null);
    }
    final utterance = _speech.takeBytes();
    reset();
    return (started: false, utterance: utterance);
  }

  void reset() {
    _preRoll.clear();
    _speech.clear();
    _preSamples = _samples = _voiced = _quiet = 0;
    _started = false;
  }
}
