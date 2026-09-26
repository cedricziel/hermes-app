import 'package:flutter/material.dart';

import '../api/hermes_repositories.dart';
import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../widgets/content_column.dart';
import 'hermes_profiles_repository.dart';
import 'widgets/profile_tile.dart';

/// Lists the Hermes profiles on the connected dashboard and lets the user
/// pick the active one (the sticky default `hermes profile use` sets).
///
/// The chat lists the sessions of one profile, [chatProfile] (null: whichever
/// the dashboard is scoped to). Picking a profile here moves the chat to it
/// through [onSwitched]; the CLI default can change behind the chat's back
/// (`hermes profile use`), so the screen says when the two differ.
///
/// Each profile's default model, the one chats started afterwards use, can be
/// changed through [models] without switching to that profile.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({
    super.key,
    this.repository,
    this.models,
    this.chatProfile,
    this.onSwitched,
  });

  final HermesProfilesRepository? repository;
  final HermesModelsRepository? models;
  final String? chatProfile;
  final ValueChanged<String>? onSwitched;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late final HermesProfilesRepository _repository;
  late final HermesModelsRepository? _models;
  ProfilesOverview? _overview;
  late String? _chatProfile = widget.chatProfile;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HermesRepositories.of(context).profiles;
    _models = widget.models ?? HermesRepositories.maybeOf(context)?.models;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final overview = await _repository.load();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _changeModel(
    HermesModelsRepository models,
    HermesProfile profile,
  ) async {
    final options = await models
        .load(profile: profile.name)
        .then<ModelOptions?>((o) => o, onError: (Object _) => null);
    if (!mounted) return;
    if (options == null || options.providers.isEmpty) {
      _say('Could not load models');
      return;
    }
    final current = options.current;
    ModelChoice? picked;
    await showModelPicker(
      context,
      options: options,
      selected: current,
      withEffort: false,
      title: 'Default model',
      note:
          'New chats in ${profile.label} start with this model. '
          'Open chats keep theirs.',
      onChanged: (choice) => picked = choice,
    );
    final choice = picked;
    if (!mounted || choice == null) return;
    if (current != null && choice.sameModel(current)) return;
    try {
      await _repository.setModel(profile.name, choice);
    } on Object {
      if (mounted) _say('Could not change the default model');
      return;
    }
    if (!mounted) return;
    _say('New chats in ${profile.label} use ${choice.modelId}');
    await _load();
  }

  String? get _shownInChat => _chatProfile ?? _overview?.current;

  Future<void> _choose(HermesProfile profile) async {
    final name = profile.name;
    final isActive = name == _overview?.active;
    if (isActive && name == _shownInChat) return;
    if (!isActive) {
      try {
        await _repository.setActive(name);
      } on Object {
        if (!mounted) return;
        _say('Could not switch profile');
        return;
      }
    }
    if (!mounted) return;
    if (name != _shownInChat) {
      _chatProfile = name;
      widget.onSwitched?.call(name);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: ContentColumn(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final overview = _overview;
    if (_failed || overview == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load profiles'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final shown = _shownInChat;
    return ListView(
      children: [
        if (shown != overview.active)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              'The chat shows $shown. The CLI default is ${overview.active}.',
            ),
          ),
        for (final profile in overview.profiles)
          ProfileTile(
            profile: profile,
            active: profile.name == overview.active,
            onTap: () => _choose(profile),
            onChangeModel: switch (_models) {
              final models? => () => _changeModel(models, profile),
              null => null,
            },
          ),
      ],
    );
  }
}
