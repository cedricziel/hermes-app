import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../auth/auth_controller.dart';
import '../messaging/messaging_screen.dart';
import '../macos/mac_toolbar.dart';
import '../mcp/mcp_servers_screen.dart';
import '../plugins/plugins_screen.dart';
import '../settings/helper_models_screen.dart';
import '../skills/skills_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/state_message.dart';
import 'chat_profiles.dart';
import 'widgets/mac_profiles_view.dart';
import 'widgets/new_profile_dialog.dart';

/// The Profiles page of a Mac window: every profile on the server, and what
/// the selected one's home holds, each part opening the screen that manages
/// it for that profile.
///
/// Counts are read when a profile is selected and left out when a read
/// fails. Messaging and plugins are managed for the profile the dashboard is
/// scoped to, so their counts only show for the chat's profile.
class MacProfilesPage extends StatefulWidget {
  const MacProfilesPage({super.key, required this.profiles});

  final ChatProfiles profiles;

  @override
  State<MacProfilesPage> createState() => _MacProfilesPageState();
}

class _MacProfilesPageState extends State<MacProfilesPage> {
  String? _selected;

  /// The counts read so far, by profile, shown at once when a profile is
  /// selected again while they are read anew.
  final _counts = <String, Map<ProfileSection, int>>{};
  int _generation = 0;

  ChatProfiles get _profiles => widget.profiles;

  @override
  void initState() {
    super.initState();
    _profiles.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _profiles.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final names = [for (final p in _profiles.profiles) p.name];
    final selected = _selected;
    if (selected == null || !names.contains(selected)) {
      final next = _profiles.current ?? names.firstOrNull;
      if (next != null) return _select(next);
    }
    if (mounted) setState(() {});
  }

  void _select(String name) {
    setState(() => _selected = name);
    _loadCounts(name);
  }

  Future<void> _loadCounts(String name) async {
    final generation = ++_generation;
    final repositories = HermesRepositories.maybeOf(context);
    final profile = _profiles.profiles.where((p) => p.name == name).firstOrNull;
    final current = name == _profiles.current;
    void put(ProfileSection section, int count) {
      if (!mounted || generation != _generation) return;
      setState(() => _counts[name] = {...?_counts[name], section: count});
    }

    Future<void> count(
      ProfileSection section,
      Future<int> Function() read,
    ) async {
      try {
        put(section, await read());
      } on Object {
        // No count is shown for what could not be read.
      }
    }

    if (profile != null) put(ProfileSection.skills, profile.skillCount);
    if (repositories == null) return;
    await Future.wait([
      count(
        ProfileSection.mcp,
        () async => (await repositories.mcp.loadServers(profile: name)).length,
      ),
      count(
        ProfileSection.helperModels,
        () async =>
            (await repositories.models.loadAuxiliary(profile: name))
                .slots
                .length,
      ),
      if (current) ...[
        count(
          ProfileSection.messaging,
          () async => (await repositories.messaging.load()).length,
        ),
        count(
          ProfileSection.plugins,
          () async => (await repositories.pluginManager.load()).length,
        ),
      ],
    ]);
  }

  void _open(ProfileSection section) {
    final name = _selected;
    final repositories = HermesRepositories.maybeOf(context);
    if (name == null || repositories == null) return;
    final page = switch (section) {
      ProfileSection.skills => SkillsScreen(
        repository: repositories.skills,
        chatProfile: name,
      ),
      ProfileSection.messaging => MessagingScreen(
        repository: repositories.messaging,
      ),
      ProfileSection.plugins => PluginsScreen(
        repository: repositories.pluginManager,
      ),
      ProfileSection.mcp => McpServersScreen(
        repository: repositories.mcp,
        profiles: repositories.profiles,
        profile: name,
      ),
      ProfileSection.helperModels => HelperModelsScreen(
        repository: repositories.models,
        profile: name,
      ),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles.profiles;
    final baseUrl = context.select<AuthController, String?>((a) => a.baseUrl);
    final host = baseUrl == null ? null : Uri.tryParse(baseUrl)?.authority;
    final count = profiles.length == 1
        ? '1 profile'
        : '${profiles.length} profiles';
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MacToolbar(
            title: 'Profiles',
            subtitle: host == null ? count : '$count on $host',
            border: true,
            actions: [
              MacToolbarButton(
                key: const Key('profiles-new'),
                label: 'New Profile',
                icon: AppIcons.add,
                onPressed: () => createProfile(context, _profiles),
              ),
            ],
          ),
          Expanded(
            child: _profiles.failed && profiles.isEmpty
                ? StateMessage(
                    title: 'Could not load profiles',
                    action: FilledButton(
                      onPressed: _profiles.load,
                      child: const Text('Retry'),
                    ),
                  )
                : MacProfilesView(
                    profiles: profiles,
                    selected: _selected,
                    onSelect: _select,
                    counts: _counts[_selected] ?? const {},
                    onOpen: _open,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Asks for a new profile's name and creates it, saying why when the
/// dashboard refuses.
Future<void> createProfile(BuildContext context, ChatProfiles profiles) async {
  final created = await showNewProfileDialog(context);
  if (created == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await profiles.create(created.name, description: created.description);
  } on Object catch (error) {
    final detail = switch (error) {
      DioException(response: Response(data: {'detail': final String d})) =>
        ': $d',
      _ => '',
    };
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not create the profile$detail')),
    );
  }
}
