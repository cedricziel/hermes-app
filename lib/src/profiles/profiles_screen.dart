import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'hermes_profiles_repository.dart';

/// Lists the Hermes profiles on the connected dashboard and lets the user
/// pick the active one (the sticky default `hermes profile use` sets).
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key, this.repository});

  final HermesProfilesRepository? repository;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late final HermesProfilesRepository _repository;
  ProfilesOverview? _overview;
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

  Future<void> _choose(HermesProfile profile) async {
    if (profile.name == _overview?.active) return;
    try {
      await _repository.setActive(profile.name);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not switch profile')));
      return;
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: _body(),
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
    return ListView(
      children: [
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
