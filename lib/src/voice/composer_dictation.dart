import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// An optional activity signal suspends voice work and restores typed text;
/// its owner must authorize any return to activity.
class ComposerDictation {
  ComposerDictation({
    required HermesChatRepository repository,
    required MixedSocketConnect connect,
    required VoiceRecorder recorder,
    required this._field,
    required this._profile,
    this._settings,
    this._onDevice,
    ValueListenable<bool>? activity,
    this._breadcrumbs = Breadcrumbs.none,
  }) : _repository = repository,
       _activity = activity {
    controller = DictationController(
      repository: repository,
      connect: connect,
      recorder: recorder,
      onTranscript: _insert,
      breadcrumbs: _breadcrumbs,
      onDevice: _onDevice,
      activity: activity,
    )..addListener(_follow);
    _settings?.addListener(refresh);
    _activity?.addListener(_activityChanged);
    _installs = _onDevice?.installed.listen((_) {
      if (_engine == DictationEngine.device) unawaited(refresh());
    });
  }

  final HermesChatRepository _repository;
  final TextEditingController _field;

  /// The profile the composer sends to, read each time voice support is.
  final String? Function() _profile;
  final DictationSettings? _settings;
  final OnDeviceSpeech? _onDevice;
  final Breadcrumbs _breadcrumbs;
  final ValueListenable<bool>? _activity;
  late final DictationController controller;
  StreamSubscription<void>? _installs;

  /// The profile whose voice support was last asked for.
  ({String? profile})? _asked;
  var _disposed = false;
  var _downloadFailed = false;
  var _refreshEpoch = 0;
  var _cancelledBusyRun = false;

  bool get _active => !_disposed && (_activity?.value ?? true);

  void _activityChanged() {
    _refreshEpoch++;
    _asked = null;
    if (_active) {
      unawaited(refresh());
    } else {
      _cancelledBusyRun = controller.busy;
      _restoreDraft();
    }
  }

  /// The draft as the running dictation found it; null when none runs.
  DictationDraft? _draft;

  /// The text this dictation last put in the field.
  String? _shown;

  /// Asks again when the composer's profile changed since the last time.
  void followProfile() {
    if (_active && _asked?.profile != _profile()) unawaited(refresh());
  }

  /// The chosen engine; Hermes without an on-device recognizer.
  DictationEngine get _engine => _onDevice == null
      ? DictationEngine.hermes
      : _settings?.engine ?? DictationEngine.hermes;

  /// Asks what voice input the profile allows. Until the saved engine is
  /// known, asking the server could break the on-device promise; the
  /// settings call back once loaded.
  Future<void> refresh() async {
    if (!_active || _settings?.loaded == false) return;
    final epoch = ++_refreshEpoch;
    final profile = _profile();
    _asked = (profile: profile);
    final engine = _engine;
    bool current() =>
        _active &&
        epoch == _refreshEpoch &&
        _profile() == profile &&
        _engine == engine;
    if (engine == DictationEngine.device) {
      // Speech stays on the device, so the server's voice config is not read.
      final locale = OnDeviceSpeech.deviceLocale();
      final model = await _onDevice!.status(locale);
      if (!current()) return;
      if (model == OnDeviceModel.missing) unawaited(_download(locale, epoch));
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
  Future<void> _download(String locale, int epoch) async {
    if (!_active || epoch != _refreshEpoch || _downloadFailed) return;
    var installed = true;
    try {
      await _onDevice!.install(locale);
    } on OnDeviceSpeechException {
      installed = false;
      if (!_active || epoch != _refreshEpoch) return;
      _downloadFailed = true;
    }
    if (!_active || epoch != _refreshEpoch) return;
    _breadcrumbs('voice.model.install', {
      'outcome': installed ? 'installed' : 'failed',
    });
  }

  void _insert(String transcript) {
    if (_active) {
      _field.value = DictationDraft(_field.value).showing(transcript);
    }
  }

  void _restoreDraft() {
    final draft = _draft;
    final shown = _shown;
    _draft = null;
    _shown = null;
    if (draft != null && (shown == null || shown == _field.text)) {
      _field.value = draft.original;
    }
  }

  /// Anything else that writes the field meanwhile wins: the dictation is
  /// dropped and that text stays.
  void _follow() {
    if (!_active) {
      _restoreDraft();
      return;
    }
    final current = _field.value;
    if (controller.busy) {
      if (_cancelledBusyRun) return;
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
      _cancelledBusyRun = false;
      _shown = null;
      if (_draft case final draft?) {
        _draft = null;
        _field.value = draft.original;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _refreshEpoch++;
    _activity?.removeListener(_activityChanged);
    _settings?.removeListener(refresh);
    unawaited(_installs?.cancel());
    controller
      ..removeListener(_follow)
      ..dispose();
  }
}
