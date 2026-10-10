import 'dart:async';

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

import 'live_transcriber.dart';

/// Whether the device can recognize a language without any server.
enum OnDeviceModel {
  /// The language, or the device's hardware, has no on-device recognition.
  unsupported,

  /// The language's model can be downloaded.
  missing,

  downloading,
  installed,
}

/// A recognizer failure, as one of the plugin's fixed codes (`unsupported`,
/// `modelMissing`, `failed`), never text the recognizer produced.
class OnDeviceSpeechException implements Exception {
  const OnDeviceSpeechException(this.code);

  final String code;

  @override
  String toString() => 'OnDeviceSpeechException($code)';
}

/// The operating system's on-device speech recognizer (`packages/hermes_speech`,
/// iOS and macOS only); elsewhere every language is [OnDeviceModel.unsupported].
///
/// An event channel has a single native listener, so the app keeps one
/// instance and this fans the events out to sessions and install progress.
class OnDeviceSpeech {
  OnDeviceSpeech();

  static const methods = MethodChannel('hermes_app/speech');
  static const events = EventChannel('hermes_app/speech/events');

  /// The language the device's settings prefer, with its region (`de-DE`):
  /// without one the recognizer may pick another country's variant.
  static String deviceLocale() =>
      PlatformDispatcher.instance.locale.toLanguageTag();

  final _sessions = <int, OnDeviceSession>{};
  final _progress = StreamController<double>.broadcast();
  final _installed = StreamController<void>.broadcast();
  final _installing = <String, Future<void>>{};
  StreamSubscription<Object?>? _events;

  /// How far a model download is, from 0 to 1, for whoever installs it.
  Stream<double> get installProgress {
    _listen();
    return _progress.stream;
  }

  Future<OnDeviceModel> status(String locale) async {
    final String? answer;
    try {
      answer = await _invoke<String>('status', {'locale': locale});
    } on OnDeviceSpeechException {
      return OnDeviceModel.unsupported;
    }
    return OnDeviceModel.values.asNameMap()[answer] ??
        OnDeviceModel.unsupported;
  }

  /// Fires each time a model finished installing, so dictation can check
  /// again.
  Stream<void> get installed => _installed.stream;

  /// Downloads [locale]'s model; completes once it is installed. A second
  /// call while one runs joins it.
  Future<void> install(String locale) => _installing[locale] ??= () async {
    try {
      _listen();
      await _invoke('install', {'locale': locale});
      _installed.add(null);
    } finally {
      unawaited(_installing.remove(locale));
    }
  }();

  /// Opens a session that recognizes 16-bit mono PCM at [sampleRate].
  Future<OnDeviceSession> start({
    required String locale,
    required int sampleRate,
  }) async {
    _listen();
    final id = await _invoke<int>('start', {
      'locale': locale,
      'sampleRate': sampleRate,
    });
    if (id == null) throw const OnDeviceSpeechException('failed');
    return _sessions[id] = OnDeviceSession._(this, id);
  }

  /// Everything heard in [audio], a whole recording (AAC, WAV and the other
  /// formats the platform decodes); empty when it heard no speech.
  Future<String> transcribeFile(
    Uint8List audio, {
    required String locale,
  }) async {
    final text = await _invoke<String>('transcribeFile', {
      'audio': audio,
      'locale': locale,
    });
    return text?.trim() ?? '';
  }

  void _listen() {
    _events ??= events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (_) {},
    );
  }

  void _onEvent(Object? event) {
    if (event is! Map) return;
    if (event['type'] == 'progress') {
      if (event['fraction'] case final num fraction) {
        _progress.add(fraction.toDouble());
      }
      return;
    }
    _sessions[event['id']]?._onEvent(event);
  }

  /// Stops listening; sessions still open hear no more events.
  Future<void> dispose() async {
    await _events?.cancel();
    _events = null;
    await _progress.close();
    await _installed.close();
  }

  static Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw OnDeviceSpeechException(e.code);
    } on MissingPluginException {
      throw const OnDeviceSpeechException('unsupported');
    }
  }
}

/// One recording being recognized on the device.
class OnDeviceSession implements LiveTranscriber {
  OnDeviceSession._(this._speech, this._id);

  final OnDeviceSpeech _speech;
  final int _id;
  final _partials = StreamController<String>.broadcast();
  var _ended = false;

  /// Why recognition failed, as a fixed code; null while it has not.
  String? get errorCode => _errorCode;
  String? _errorCode;

  @override
  Stream<String> get partials => _partials.stream;

  @override
  void add(Uint8List pcm) {
    if (_ended) return;
    unawaited(
      OnDeviceSpeech._invoke<void>('append', {
        'id': _id,
        'pcm': pcm,
      }).catchError((Object e) => _fail(_codeOf(e))),
    );
  }

  @override
  Future<String?> finish() async {
    if (_ended) return null;
    try {
      final text = await OnDeviceSpeech._invoke<String>('finish', {'id': _id});
      if (_ended) return null;
      _end();
      return text?.trim() ?? '';
    } on OnDeviceSpeechException catch (e) {
      _fail(e.code);
      return null;
    }
  }

  @override
  void cancel() {
    if (_ended) return;
    _end();
    unawaited(
      OnDeviceSpeech._invoke<void>('cancel', {
        'id': _id,
      }).catchError((Object _) {}),
    );
  }

  void _onEvent(Map<Object?, Object?> event) {
    switch (event['type']) {
      case 'partial':
        if (event['text'] case final String text when !_ended) {
          _partials.add(text);
        }
      case 'error':
        _fail(switch (event['code']) {
          final String code => code,
          _ => 'failed',
        });
    }
  }

  void _fail(String code) {
    if (_ended) return;
    _errorCode = code;
    _end();
  }

  void _end() {
    _ended = true;
    _speech._sessions.remove(_id);
    unawaited(_partials.close());
  }

  static String _codeOf(Object error) =>
      error is OnDeviceSpeechException ? error.code : 'failed';
}
