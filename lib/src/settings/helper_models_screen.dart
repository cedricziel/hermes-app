import 'package:flutter/material.dart';

import '../models/auxiliary_models.dart';
import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import '../models/moa_setup.dart';
import '../models/widgets/model_picker.dart';
import '../widgets/content_column.dart';
import '../widgets/state_message.dart';
import 'widgets/helper_model_list.dart';

/// The helper models of [profile]: which model each of Hermes' side jobs
/// runs on. A slot is saved when its picker closes.
class HelperModelsScreen extends StatefulWidget {
  const HelperModelsScreen({
    super.key,
    required this.repository,
    required this.profile,
  });

  final HermesModelsRepository repository;

  /// Null leaves the profile to the dashboard.
  final String? profile;

  @override
  State<HelperModelsScreen> createState() => _HelperModelsScreenState();
}

class _HelperModelsScreenState extends State<HelperModelsScreen> {
  AuxiliaryModels? _models;
  MoaSetup? _moa;
  ModelOptions _options = const ModelOptions();
  bool _failed = false;
  final Set<String> _saving = {};

  HermesModelsRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    final options = _repository
        .load(profile: widget.profile)
        .then<ModelOptions?>((o) => o, onError: (_) => null);
    final moa = _repository
        .loadMoa(profile: widget.profile)
        .then<MoaSetup?>((m) => m, onError: (_) => null);
    try {
      final models = await _repository.loadAuxiliary(profile: widget.profile);
      final loaded = await options;
      final loadedMoa = await moa;
      if (!mounted) return;
      setState(() {
        _models = models;
        _moa = loadedMoa;
        if (loaded != null) _options = loaded;
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(AuxiliarySlot slot) async {
    var pick = slot.choice;
    await showModelPicker(
      context,
      title: slot.label,
      options: _options,
      selected: slot.choice,
      onChanged: (choice) => pick = choice,
      onUseDefault: () => pick = null,
    );
    if (mounted && pick != slot.choice) await _save(slot, pick);
  }

  /// A preset may not hold Hermes' virtual `moa` provider, nor an empty slot.
  Future<void> _openMoa(MoaSlot slot) async {
    var pick = slot.choice;
    await showModelPicker(
      context,
      title: slot.label,
      options: ModelOptions(
        current: _options.current,
        providers: [
          for (final p in _options.providers)
            if (p.id != 'moa') p,
        ],
      ),
      selected: slot.choice,
      onChanged: (choice) => pick = choice,
    );
    final moa = _moa;
    if (!mounted || moa == null || pick == slot.choice) return;
    final next = moa.withSlot(slot.key, pick);
    final keys = {for (final s in moa.slots) s.key};
    setState(() => _saving.addAll(keys));
    try {
      await _repository.saveMoa(next, profile: widget.profile);
      if (mounted) setState(() => _moa = next);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change ${slot.label}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.removeAll(keys));
    }
  }

  Future<void> _save(
    AuxiliarySlot slot,
    ModelChoice? choice, {
    bool confirmed = false,
  }) async {
    setState(() => _saving.add(slot.task));
    String? warning;
    try {
      warning = await _repository.assignAuxiliary(
        slot.task,
        choice,
        profile: widget.profile,
        confirmExpensive: confirmed,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _saving.remove(slot.task));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change ${slot.label}')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving.remove(slot.task);
      if (warning == null) {
        _models = _models?.withSlot(
          AuxiliarySlot(task: slot.task, choice: choice),
        );
      }
    });
    if (warning != null && await _confirm(warning) && mounted) {
      await _save(slot, choice, confirmed: true);
    }
  }

  Future<bool> _confirm(String warning) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use this model?'),
          content: Text(warning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use it'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final models = _models;
    return Scaffold(
      appBar: AppBar(title: const Text('Helper models')),
      body: ContentColumn(
        child: _failed
            ? StateMessage(
                title: 'Could not load the helper models',
                action: FilledButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              )
            : models == null
            ? const Center(child: CircularProgressIndicator())
            : HelperModelList(
                models: models,
                saving: _saving,
                onTap: _open,
                moa: _moa,
                onTapMoa: _openMoa,
              ),
      ),
    );
  }
}
