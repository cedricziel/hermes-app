import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../api/hermes_repositories.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/busy_bar.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart';
import '../widgets/state_message.dart';
import 'discover_tab.dart';
import 'hermes_skills_hub_repository.dart';
import 'hermes_skills_repository.dart';
import 'hub_skill_screen.dart';
import 'skill_detail_screen.dart';
import 'skill_editor_screen.dart';
import 'skill_job.dart';
import 'skill_job_sheet.dart';
import 'skills_controller.dart';
import 'skills_hub_controller.dart';
import 'widgets/installed_skills_list.dart';

/// The skills installed on a profile: switch them on and off, read and edit
/// them, and create new ones. With a hub it has a second tab to find and
/// install more.
///
/// It starts on [chatProfile] and can look at another profile without moving
/// the chat. It pops with a drafted chat message when the user asks the agent
/// to delete a skill, which the chat puts in its composer.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({
    super.key,
    this.repository,
    this.hubRepository,
    this.profiles,
    this.chatProfile,
  });

  final HermesSkillsRepository? repository;
  final HermesSkillsHubRepository? hubRepository;
  final HermesProfilesRepository? profiles;
  final String? chatProfile;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen>
    with SingleTickerProviderStateMixin {
  late final SkillsController _controller;
  SkillsHubController? _hub;
  late final TabController _tabs;
  bool _hubLoaded = false;

  @override
  void initState() {
    super.initState();
    final repositories = widget.repository == null
        ? HermesRepositories.of(context)
        : null;
    _controller = SkillsController(
      repository: widget.repository ?? repositories!.skills,
      profiles: widget.profiles ?? repositories?.profiles,
      chatProfile: widget.chatProfile,
      events: _events(),
    );
    final hubRepository = widget.hubRepository ?? repositories?.skillsHub;
    if (hubRepository != null) {
      _hub = SkillsHubController(
        repository: hubRepository,
        skills: _controller,
        events: _events(),
      )..addListener(_reportFinishedJob);
    }
    _tabs = TabController(length: _hub == null ? 1 : 2, vsync: this)
      ..addListener(_onTab);
    _controller
      ..load()
      ..loadProfiles();
  }

  /// The hub loads the first time its tab is opened, not with the page.
  void _onTab() {
    if (_tabs.index == 1 && !_hubLoaded) {
      _hubLoaded = true;
      _hub?.load();
    }
  }

  /// A job the user sent to the background says how it ended, once.
  void _reportFinishedJob() {
    final hub = _hub;
    final job = hub?.job;
    if (hub == null || job == null || job.running || hub.sheetOpen) return;
    hub.dismissJob();
    if (!mounted) return;
    final text = switch (job.state) {
      JobState.succeeded => 'Done: ${job.title}',
      JobState.failed => 'Failed: ${job.title}',
      _ => 'Could not confirm: ${job.title}',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  AppEventLogger _events() =>
      HermesRepositories.maybeOf(context)?.telemetry.events ??
      noopAppEventLogger;

  @override
  void dispose() {
    _hub?.dispose();
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(HermesSkill skill) async {
    final draft = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SkillDetailScreen(
          controller: _controller,
          hub: _hub,
          name: skill.name,
        ),
      ),
    );
    if (draft != null && mounted) Navigator.of(context).pop(draft);
  }

  Future<void> _openHub(HubSkill skill) async {
    final installed = _controller.skill(skill.name);
    if (_hub!.isInstalled(skill) && installed != null) {
      await _open(installed);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HubSkillScreen(hub: _hub!, skill: skill),
      ),
    );
  }

  Future<void> _selectProfile(String name) async {
    await _controller.selectProfile(name);
    if (_hubLoaded) await _hub?.reset();
  }

  Future<void> _update() async {
    final hub = _hub!;
    if (hub.update() != null) await showSkillJobSheet(context, hub);
  }

  Future<void> _create() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SkillEditorScreen.create(
          onSave: (name, category, text) =>
              _controller.create(name, text, category: category),
        ),
      ),
    );
    if (name == null || !mounted) return;
    await _open(HermesSkill(name: name, source: SkillSource.agent));
  }

  Future<void> _toggle(HermesSkill skill, bool enabled) async {
    final ok = await _controller.toggle(skill.name, enabled);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change ${skill.name}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, ?_hub, _tabs]),
      builder: (context, _) {
        final hub = _hub;
        final onDiscover = hub != null && _tabs.index == 1;
        final ready = _controller.status == SkillsStatus.ready;
        return SettingsScaffold(
          title: 'Skills',
          subtitle: _subtitle(context),
          subtitleMenu: _profileMenu(),
          actions: [
            if (ready && !onDiscover)
              SettingsBarAction(
                key: const Key('skills-new'),
                label: 'New skill',
                icon: AppIcons.add,
                onPressed: _create,
              ),
          ],
          tabs: hub == null ? null : const ['Installed', 'Discover'],
          tabController: _tabs,
          search: onDiscover
              ? _hubSearch(hub)
              : ready && _controller.hasSkills
              ? _skillsSearch()
              : null,
          body: hub == null
              ? _body()
              : Column(
                  children: [
                    if (hub.busy) _JobBar(hub: hub),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _body(),
                          DiscoverTab(hub: hub, onOpen: _openHub),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// The profile, and on a Mac how many skills it has.
  String? _subtitle(BuildContext context) {
    final profile = _controller.profile;
    if (profile == null) return null;
    final ready = _controller.status == SkillsStatus.ready;
    if (!ready || platformChromeOf(context) != PlatformChrome.macos) {
      return profile;
    }
    final count = _controller.skillCount;
    return '$profile · $count skill${count == 1 ? '' : 's'}';
  }

  SettingsSubtitleMenu<String>? _profileMenu() {
    final profile = _controller.profile;
    final others = _controller.availableProfiles;
    if (profile == null || others.isEmpty) return null;
    return SettingsSubtitleMenu<String>(
      label: 'Profile',
      onSelected: _selectProfile,
      itemBuilder: (_) => [
        for (final p in others)
          CheckedPopupMenuItem(
            value: p.name,
            checked: p.name == profile,
            child: Text(p.label),
          ),
      ],
    );
  }

  SettingsSearch _skillsSearch() => SettingsSearch(
    query: _controller.query,
    onChanged: _controller.setQuery,
    hint: 'Search skills',
    filters: [
      for (final filter in SkillFilter.values)
        SettingsFilter(
          label: _filterLabel(filter),
          selected: _controller.filter == filter,
          onSelected: () => _controller.setFilter(filter),
        ),
    ],
  );

  SettingsSearch? _hubSearch(SkillsHubController hub) {
    if (hub.status != HubStatus.ready) return null;
    return SettingsSearch(
      query: hub.query,
      onChanged: hub.setQuery,
      hint: 'Search the skills hub',
      filters: [
        if (hub.sources.isNotEmpty)
          for (final (id, label) in [
            (SkillsHubController.allSources, 'All sources'),
            for (final s in hub.sources) (s.id, s.label),
          ])
            SettingsFilter(
              label: label,
              selected: hub.source == id,
              onSelected: () => hub.setSource(id),
            ),
      ],
    );
  }

  Widget _body() {
    switch (_controller.status) {
      case SkillsStatus.loading:
        return const Center(child: CircularProgressIndicator.adaptive());
      case SkillsStatus.unsupported:
        return const StateMessage(
          title: 'The connected Hermes does not support skills.',
        );
      case SkillsStatus.failed:
        return StateMessage(
          title: 'Could not load skills',
          action: FilledButton(
            onPressed: _controller.load,
            child: const Text('Retry'),
          ),
        );
      case SkillsStatus.ready:
        break;
    }
    if (!_controller.hasSkills) {
      return const StateMessage(title: 'This profile has no skills yet.');
    }
    final hub = _hub;
    return InstalledSkillsList(
      groups: _controller.groups,
      onOpen: _open,
      onToggle: _toggle,
      onClearFilters: _controller.clearFilters,
      onCheckForUpdates: hub != null && _controller.hasHubSkills
          ? _update
          : null,
      updating: hub?.busy ?? false,
    );
  }

  static String _filterLabel(SkillFilter f) => switch (f) {
    SkillFilter.all => 'All',
    SkillFilter.enabled => 'Enabled',
    SkillFilter.hub => 'Hub',
    SkillFilter.bundled => 'Bundled',
    SkillFilter.agent => 'Agent',
  };
}

/// Shown while a job runs that the user has sent to the background.
class _JobBar extends StatelessWidget {
  const _JobBar({required this.hub});

  final SkillsHubController hub;

  @override
  Widget build(BuildContext context) {
    final job = hub.job;
    if (job == null) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        dense: true,
        key: const ValueKey('job-bar'),
        title: Text('${job.title}…'),
        subtitle: const BusyBar(),
        onTap: () => showSkillJobSheet(context, hub),
      ),
    );
  }
}
