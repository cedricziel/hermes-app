import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'hermes_profiles_repository.dart';
import '../widgets/content_column.dart';

/// Lists the Hermes profiles on the connected dashboard and lets the user
/// pick the active one (the sticky default `hermes profile use` sets).
///
/// The chat lists the sessions of one profile, [chatProfile] (null: whichever
/// the dashboard is scoped to). Picking a profile here moves the chat to it
/// through [onSwitched]; the CLI default can change behind the chat's back
/// (`hermes profile use`), so the screen says when the two differ.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({
    super.key,
    this.repository,
    this.chatProfile,
    this.onSwitched,
  });

  final HermesProfilesRepository? repository;
  final String? chatProfile;
  final ValueChanged<String>? onSwitched;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late final HermesProfilesRepository _repository;
  ProfilesOverview? _overview;
  late String? _chatProfile = widget.chatProfile;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        HermesProfilesRepository(context.read<AuthController>().api!.raw);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not switch profile')),
        );
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
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile.label),
            subtitle: _subtitle(profile),
            trailing: profile.name == overview.active
                ? const Chip(label: Text('Active'))
                : null,
            onTap: () => _choose(profile),
          ),
      ],
    );
  }

  Widget? _subtitle(HermesProfile profile) {
    final parts = [
      if (profile.description.isNotEmpty) profile.description,
      if (profile.model != null) profile.model!,
      '${profile.skillCount} skills',
    ];
    return Text(parts.join(' · '));
  }
}
