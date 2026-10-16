import 'package:flutter/material.dart';

import '../api/hermes_repositories.dart';
import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../theme/app_icons.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'hermes_profiles_repository.dart';
import 'widgets/new_profile_dialog.dart';
import 'widgets/profile_tile.dart';

/// Lists Hermes profiles and lets the user select the local chat recipient.
///
/// The chat lists sessions of [chatProfile], or the dashboard's own profile
/// when it is null. Selection moves the chat through [onSwitched] and leaves
/// the CLI default unchanged.
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
  int _selectionGeneration = 0;

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
    final generation = ++_selectionGeneration;
    final name = profile.name;
    if (name == _shownInChat) return;
    List<HermesProfile> available;
    try {
      available = await _repository.list();
    } on Object {
      if (mounted && generation == _selectionGeneration) {
        _say('Could not switch profile');
      }
      return;
    }
    if (!mounted || generation != _selectionGeneration) return;
    if (!available.any((profile) => profile.name == name)) {
      _say('Could not switch profile');
      return;
    }
    setState(() => _chatProfile = name);
    widget.onSwitched?.call(name);
  }

  Future<void> _create() => createProfile(context, (name, {description}) async {
    await _repository.create(name, description: description);
    if (mounted) await _load();
  });

  @override
  Widget build(BuildContext context) {
    final count = _overview?.profiles.length;
    return SettingsScaffold(
      title: 'Profiles',
      subtitle: switch (count) {
        null => null,
        1 => '1 profile',
        _ => '$count profiles',
      },
      actions: [
        SettingsBarAction(
          key: const Key('profiles-new'),
          label: 'New Profile',
          icon: AppIcons.add,
          onPressed: _create,
        ),
      ],
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _overview == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
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
    return GroupedListView(
      children: [
        GroupedSection(
          dividerIndent: GroupedMetrics.of(context).indentAfterTile,
          footer: shown == overview.active
              ? null
              : 'The chat shows $shown. The CLI default is ${overview.active}.',
          children: [
            for (final profile in overview.profiles)
              ProfileTile(
                key: ValueKey('profile-${profile.name}'),
                profile: profile,
                active: profile.name == overview.active,
                onTap: () => _choose(profile),
                onChangeModel: switch (_models) {
                  final models? => () => _changeModel(models, profile),
                  null => null,
                },
              ),
          ],
        ),
      ],
    );
  }
}
