import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../telemetry/breadcrumbs.dart';
import '../widgets/grouped_dialog.dart';
import 'dictation_settings.dart';
import 'on_device_speech.dart';
import 'widgets/dictation_settings_view.dart';

Future<void> showDictationDialog(BuildContext context) {
  final settings = context.read<DictationSettings>();
  final speech = context.read<OnDeviceSpeech>();
  Breadcrumbs breadcrumbs;
  try {
    breadcrumbs = context.read<Breadcrumbs>();
  } on ProviderNotFoundException {
    breadcrumbs = Breadcrumbs.none;
  }
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: _DictationDialog(speech: speech, breadcrumbs: breadcrumbs),
    ),
  );
}

class _DictationDialog extends StatefulWidget {
  const _DictationDialog({required this.speech, required this.breadcrumbs});

  final OnDeviceSpeech speech;
  final Breadcrumbs breadcrumbs;

  @override
  State<_DictationDialog> createState() => _DictationDialogState();
}

class _DictationDialogState extends State<_DictationDialog> {
  final _locale = OnDeviceSpeech.deviceLocale();

  /// Null until the platform answered.
  OnDeviceModel? _model;
  double? _progress;
  var _failed = false;
  StreamSubscription<double>? _progressEvents;

  @override
  void initState() {
    super.initState();
    _progressEvents = widget.speech.installProgress.listen(
      (fraction) => setState(() => _progress = fraction),
    );
    unawaited(_readModel());
  }

  @override
  void dispose() {
    unawaited(_progressEvents?.cancel());
    super.dispose();
  }

  Future<void> _readModel() async {
    final model = await widget.speech.status(_locale);
    if (!mounted) return;
    setState(() => _model = model);
    // A download from an earlier visit goes on, so wait for it here too; a
    // missing model for the chosen engine, or one picked before this answer
    // came, downloads now.
    final chosen = context.read<DictationSettings>().engine;
    if (model == OnDeviceModel.downloading ||
        (model == OnDeviceModel.missing && chosen == DictationEngine.device)) {
      unawaited(_install());
    }
  }

  void _pick(DictationEngine engine) {
    if (engine == DictationEngine.device) {
      if (_model == OnDeviceModel.unsupported) return;
      if (_model == OnDeviceModel.missing) unawaited(_install());
    }
    unawaited(context.read<DictationSettings>().setEngine(engine));
  }

  Future<void> _install() async {
    setState(() {
      _model = OnDeviceModel.downloading;
      _failed = false;
    });
    var installed = true;
    try {
      await widget.speech.install(_locale);
    } on OnDeviceSpeechException {
      installed = false;
    }
    widget.breadcrumbs('voice.model.install', {
      'outcome': installed ? 'installed' : 'failed',
    });
    if (!mounted) return;
    setState(() {
      _failed = !installed;
      _model = installed ? OnDeviceModel.installed : OnDeviceModel.missing;
      _progress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final chosen = context.watch<DictationSettings>().engine;
    return GroupedDialog(
      title: 'Dictation',
      children: [
        DictationSettingsView(
          engine: effectiveDictationEngine(chosen, model),
          model: model ?? OnDeviceModel.missing,
          progress: _progress,
          downloadFailed: _failed,
          onEngine: _pick,
          onRetryDownload: _install,
        ),
      ],
    );
  }
}
