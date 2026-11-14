import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../auth/auth_controller.dart';
import '../messaging/messaging_screen.dart';
import '../chat/gateway_connection_transport.dart';
import '../macos/mac_toolbar.dart';
import '../mcp/mcp_servers_screen.dart';
import '../memory/memory_destination.dart';
import '../chat/chat_transport.dart';
import '../memory/memory_proposal_session.dart';
import '../memory/memory_proposals_repository.dart';
import '../memory/memory_repository.dart';
import '../plugins/installed_plugin.dart';
import '../plugins/plugins_screen.dart';
import '../settings/helper_models_screen.dart';
import '../skills/skills_screen.dart';
import '../theme/app_icons.dart';
import '../tools/hermes_tools_repository.dart';
import '../tools/tools_availability.dart';
import '../tools/tools_models.dart';
import '../tools/tools_screen.dart';
import '../widgets/state_message.dart';
import 'chat_profiles.dart';
import 'widgets/mac_profiles_view.dart';
import 'widgets/new_profile_dialog.dart';

/// The Profiles page of a Mac window: every profile on the server, and what
/// the selected one's home holds, each part opening the screen that manages
/// it for that profile.
///
/// Counts are read when a profile is selected and left out when a read
/// fails. Messaging platforms and plugins count the ones switched on.
class MacProfilesPage extends StatefulWidget {
  const MacProfilesPage({
    super.key,
    required this.profiles,
    this.changeSource,
    this.transport,
  });

  final ChatProfiles profiles;
  final GatewayConnectionTransport? changeSource;

  /// Runs the commands that count the changes waiting in a profile; the
  /// count is left out without one.
  final ChatTransport? transport;

  @override
  State<MacProfilesPage> createState() => _MacProfilesPageState();
}

class _MacProfilesPageState extends State<MacProfilesPage> {
  String? _selected;

  /// The counts read so far, by profile, shown at once when a profile is
  /// selected again while they are read anew.
  final _counts = <String, Map<ProfileSection, int>>{};

  /// The staged memory changes waiting, by profile.
  final _waiting = <String, int>{};

  /// How many tools are on of how many, by profile, read when a profile is
  /// selected and only while the server offers Tools.
  final _tools = <String, ({int on, int total})>{};
  ToolsAvailability? _availability;
  final _toolsReading = <String>{};
  int _generation = 0;

  ChatProfiles get _profiles => widget.profiles;

  @override
  void initState() {
    super.initState();
    _profiles.addListener(_changed);
    _availability = _maybeRead<ToolsAvailability>()
      ?..addListener(_toolsOfferChanged);
    _changed();
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    _profiles.removeListener(_changed);
    _availability?.removeListener(_toolsOfferChanged);
    super.dispose();
  }

  /// The server's answer about Tools came or changed: show or hide the row,
  /// and read the count the row waits for.
  void _toolsOfferChanged() {
    if (!mounted) return;
    final name = _selected;
    if (name != null && (_availability?.offered ?? false)) {
      unawaited(_loadTools(name, _generation));
    }
    setState(() {});
  }

  /// Counts the selected profile's tools. A failed read leaves no count.
  Future<void> _loadTools(String name, int generation) async {
    final repositories = HermesRepositories.maybeOf(context);
    if (repositories == null || !(_availability?.offered ?? false)) return;
    // One read per profile at a time: a selection, an offer change and a
    // return from the screen can come together.
    if (!_toolsReading.add(name)) return;
    final ToolsResult<ToolsetList> result;
    try {
      result = await repositories.tools.forProfile(name).list();
    } finally {
      _toolsReading.remove(name);
    }
    if (!mounted || generation != _generation) return;
    if (result case ToolsOk<ToolsetList>(:final value)) {
      setState(
        () => _tools[name] = (
          on: value.toolsets.where((t) => t.enabled).length,
          total: value.toolsets.length,
        ),
      );
    }
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
      _loadTools(name, generation),
      _loadWaiting(name, generation, repositories),
      count(
        ProfileSection.memory,
        () => MemoryRepository(
          repositories.api.raw,
          telemetry: repositories.telemetry,
        ).count(name),
      ),
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
      count(
        ProfileSection.messaging,
        () async => (await repositories.messaging.forProfile(name).load())
            .where((p) => p.enabled)
            .length,
      ),
      count(
        ProfileSection.plugins,
        () async => (await repositories.pluginManager.forProfile(name).load())
            .where((p) => p.status == PluginStatus.enabled)
            .length,
      ),
    ]);
  }

  Future<void> _loadWaiting(
    String name,
    int generation,
    HermesRepositories repositories,
  ) async {
    final transport = widget.transport;
    if (transport == null) return;
    final snapshot = await MemoryProposalsRepository(
      MemoryProposalSession(transport),
      telemetry: repositories.telemetry,
    ).load(name);
    if (!mounted || generation != _generation) return;
    setState(() {
      switch (snapshot.waiting) {
        case final waiting?:
          _waiting[name] = waiting;
        case null:
          _waiting.remove(name);
      }
    });
  }

  Future<void> _open(ProfileSection section) async {
    final name = _selected;
    final repositories = HermesRepositories.maybeOf(context);
    if (name == null || repositories == null) return;
    final page = switch (section) {
      ProfileSection.memory => null,
      ProfileSection.skills => SkillsScreen(
        repository: repositories.skills,
        chatProfile: name,
      ),
      ProfileSection.messaging => MessagingScreen(
        repository: repositories.messaging.forProfile(name),
        changeSource: widget.changeSource,
      ),
      ProfileSection.plugins => PluginsScreen(
        repository: repositories.pluginManager.forProfile(name),
      ),
      ProfileSection.mcp => McpServersScreen(
        repository: repositories.mcp,
        profiles: repositories.profiles,
        profile: name,
      ),
      ProfileSection.tools => ToolsScreen(
        repository: repositories.tools.forProfile(name),
        availability: _availability,
        onProfileGone: () => unawaited(_profiles.load()),
      ),
      ProfileSection.helperModels => HelperModelsScreen(
        repository: repositories.models,
        profile: name,
      ),
    };
    if (page == null) {
      await openMemory(
        context,
        from: MemoryEntryPoint.profilesPage,
        profile: name,
        transport: widget.transport,
      );
      if (mounted) unawaited(_loadCounts(name));
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    // Switches made on the Tools screen change the count.
    if (mounted && section == ProfileSection.tools) {
      unawaited(_loadTools(name, _generation));
    }
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
                onPressed: () => createProfile(context, _profiles.create),
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
                    memoryWaiting: _waiting[_selected],
                    toolsOffered: _availability?.offered ?? false,
                    toolsCount: _tools[_selected],
                    onOpen: _open,
                  ),
          ),
        ],
      ),
    );
  }
}
