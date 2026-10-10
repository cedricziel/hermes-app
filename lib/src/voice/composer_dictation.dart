import 'dart:async';

import 'package:flutter/widgets.dart';

import '../chat/gateway/gateway_connection.dart';
import '../chat/hermes_chat_repository.dart';
import '../telemetry/breadcrumbs.dart';
import 'dictation_controller.dart';
import 'dictation_draft.dart';
import 'dictation_settings.dart';
import 'on_device_speech.dart';
import 'voice_recorder.dart';
import 'voice_support.dart';

/// Dictation into one composer [field], as the chat screen does it: follows
/// the Dictation setting and what the profile's server allows, shows the
/// words recognized so far in the field, puts the transcript at the cursor
/// and gives the draft back when nothing came of it.
class ComposerDictation {
  ComposerDictation({
    required HermesChatRepository repository,
    required MixedSocketConnect connect,
    required VoiceRecorder recorder,
    required this._field,
    this._settings,
    this._onDevice,
    this._breadcrumbs = Breadcrumbs.none,
  }) : _repository = repository {
    controller = DictationController(
      repository: repository,
      connect: connect,
      recorder: recorder,
      onTranscript: _insert,
      breadcrumbs: _breadcrumbs,
      onDevice: _onDevice,
    )..addListener(_follow);
    _settings?.addListener(refresh);
    _installs = _onDevice?.installed.listen((_) {
      if (_engine == DictationEngine.device) unawaited(refresh());
    });
  }

  final HermesChatRepository _repository;
  final TextEditingController _field;
  final DictationSettings? _settings;
  final OnDeviceSpeech? _onDevice;
  final Breadcrumbs _breadcrumbs;
  late final DictationController controller;
  StreamSubscription<void>? _installs;
  String? _profile;
  var _disposed = false;
  var _downloadFailed = false;

  /// The draft as the running dictation found it; null when none runs.
  DictationDraft? _draft;

  /// The text this dictation last put in the field.
  String? _shown;

  /// Points dictation at [profile]'s voice support.
  Future<void> configure(String? profile) {
    _profile = profile;
    return refresh();
  }

  /// The chosen engine; Hermes without an on-device recognizer.
  DictationEngine get _engine => _onDevice == null
      ? DictationEngine.hermes
      : _settings?.engine ?? DictationEngine.hermes;

  /// Asks what voice input the profile allows. Until the saved engine is
  /// known, asking the server could break the on-device promise; the
  /// settings call back once loaded.
  Future<void> refresh() async {
    if (_disposed || _settings?.loaded == false) return;
    final profile = _profile;
    final engine = _engine;
    bool current() => !_disposed && _profile == profile && _engine == engine;
    if (engine == DictationEngine.device) {
      // Speech stays on the device, so the server's voice config is not read.
      final locale = OnDeviceSpeech.deviceLocale();
      final model = await _onDevice!.status(locale);
      if (!current()) return;
      if (model == OnDeviceModel.missing) unawaited(_download(locale));
      if (effectiveDictationEngine(engine, model) == engine) {
        controller.configure(
          profile: profile,
          support: VoiceSupport.none,
          engine: engine,
          model: model,
        );
        return;
      }
    }
    final support = await _repository.voiceSupport(profile: profile);
    if (!current()) return;
    controller.configure(profile: profile, support: support);
  }

  /// Fetches the device's speech model once; after a failure only the
  /// Dictation setting tries again.
  Future<void> _download(String locale) async {
    if (_downloadFailed) return;
    var installed = true;
    try {
      await _onDevice!.install(locale);
    } on OnDeviceSpeechException {
      installed = false;
      _downloadFailed = true;
    }
    _breadcrumbs('voice.model.install', {
      'outcome': installed ? 'installed' : 'failed',
    });
  }

  void _insert(String transcript) =>
      _field.value = DictationDraft(_field.value).showing(transcript);

  /// Anything else that writes the field meanwhile wins: the dictation is
  /// dropped and that text stays.
  void _follow() {
    final current = _field.value;
    if (controller.busy) {
      if (_shown case final shown? when shown != current.text) {
        _draft = null;
        _shown = null;
        unawaited(controller.cancel());
        return;
      }
      final draft = _draft ??= DictationDraft(current);
      final shown = draft.showing(controller.liveTranscript);
      if (shown.text != current.text) _field.value = shown;
      _shown = _field.text;
    } else {
      _shown = null;
      if (_draft case final draft?) {
        _draft = null;
        _field.value = draft.original;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _settings?.removeListener(refresh);
    unawaited(_installs?.cancel());
    controller
      ..removeListener(_follow)
      ..dispose();
  }
}
