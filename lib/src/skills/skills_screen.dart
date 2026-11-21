import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../app_lock/app_lock_controller.dart';
import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import '../widgets/app_inactive_watcher.dart';
import 'curator/curator_config.dart';
import 'curator/curator_controller.dart';
import 'curator/curator_section_host.dart';
import 'curator/curator_telemetry.dart';
import 'curator/hermes_curator_repository.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../tools/widgets/tools_difference_sheet.dart';
import 'widgets/skill_job_bar.dart';
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
import '../widgets/grouped_list.dart';
import '../widgets/route_dismissal.dart';

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
    this.curatorRepository,
    this.curatorConfig,
  });

  final HermesSkillsRepository? repository;
  final HermesSkillsHubRepository? hubRepository;
  final HermesProfilesRepository? profiles;
  final String? chatProfile;

  /// The skill curator's routes, for a test; the connection's otherwise. With
  /// neither there is no curator section.
  final HermesCuratorRepository? curatorRepository;
  final CuratorConfigReader? curatorConfig;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen>
    with SingleTickerProviderStateMixin {
  late final SkillsController _controller;
  SkillsHubController? _hub;
  late final TabController _tabs;
  bool _hubLoaded = false;

  /// The skill curator of the profile shown, created with the first profile
  /// this screen knows. It belongs to this State alone: the home shell builds
  /// the next State before this one disposes, so [dispose] touches only it.
  CuratorController? _curator;
  HermesCuratorRepository? _curatorRepository;
  CuratorConfigReader? _curatorConfig;
  AppLockController? _lock;
  AppInactiveWatcher? _away;

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
    _startCurator(widget.curatorRepository, widget.curatorConfig, repositories);
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _startCurator(
    HermesCuratorRepository? repository,
    CuratorConfigReader? config,
    HermesRepositories? known,
  ) {
    final connection = known ?? HermesRepositories.maybeOf(context);
    repository ??= connection?.curator;
    config ??= connection?.curatorConfig;
    if (repository == null || config == null) return;
    _curatorRepository = repository;
    _curatorConfig = config;
    _lock = _maybeRead<AppLockController>()?..addListener(_onLock);
    _away = AppInactiveWatcher()..addListener(_onAway);
    _controller.addListener(_onSkillsChanged);
    final profile = _controller.profile;
    if (profile != null) _ensureCurator(profile);
  }

  /// Creates the curator for [profile], or points it at the new profile.
  void _ensureCurator(String profile) {
    final existing = _curator;
    if (existing != null) {
      existing.switchProfile(profile);
      return;
    }
    final repository = _curatorRepository;
    final config = _curatorConfig;
    if (repository == null || config == null) return;
    final connection = HermesRepositories.maybeOf(context);
    final curator = CuratorController(
      repository: repository,
      readConfig: config.call,
      profile: profile,
      telemetry: CuratorTelemetry(
        connection?.telemetry ?? const ConnectionTelemetry(),
        _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      ),
      onProfileGone: () => unawaited(_controller.loadProfiles()),
      // Archived skills leave the list.
      onRunEnded: () => unawaited(_controller.load(quiet: true)),
    );
    _curator = curator;
    _syncSearching();
    final lock = _lock;
    if (lock != null && lock.locked) curator.lock();
    curator.setInactive(_away?.away ?? false);
    curator.start();
  }

  /// A search or a filter hides the section; nothing else of it changes.
  void _syncSearching() {
    _curator?.searching =
        _controller.query.trim().isNotEmpty ||
        _controller.filter != SkillFilter.all;
  }

  void _onSkillsChanged() => _syncSearching();

  /// App Lock locked: the output is dropped and an open question closes.
  void _onLock() {
    final curator = _curator;
    final lock = _lock;
    if (curator == null || lock == null) return;
    if (lock.locked) {
      curator.lock();
    } else {
      curator.unlocked();
    }
    if (lock.covered) curator.cancelRun();
  }

  void _onAway() {
    final away = _away;
    final curator = _curator;
    if (away == null || curator == null) return;
    curator.setInactive(away.away);
    if (!away.away) curator.resumed();
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
    _controller.removeListener(_onSkillsChanged);
    _lock?.removeListener(_onLock);
    _away?.dispose();
    // Cancelling first closes an open question; then the controller goes.
    _curator?.cancelRun();
    _curator?.dispose();
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
    if (draft != null && mounted) dismissRoute(context, draft);
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
    final selected = _controller.selectProfile(name);
    // The old profile's result, polling and question go with the switch.
    if (_curatorRepository != null) _ensureCurator(name);
    await selected;
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
        return _withCurator(
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        );
      case SkillsStatus.unsupported:
        return const StateMessage(
          title: 'The connected Hermes does not support skills.',
        );
      case SkillsStatus.failed:
        return _withCurator(
          StateMessage(
            title: 'Could not load skills',
            action: FilledButton(
              onPressed: _controller.load,
              child: const Text('Retry'),
            ),
          ),
        );
      case SkillsStatus.ready:
        break;
    }
    if (!_controller.hasSkills) {
      return _withCurator(
        const StateMessage(title: 'This profile has no skills yet.'),
      );
    }
    final hub = _hub;
    final curator = _curator;
    return InstalledSkillsList(
      groups: _controller.groups,
      onOpen: _open,
      onToggle: _toggle,
      onClearFilters: _controller.clearFilters,
      onCheckForUpdates: hub != null && _controller.hasHubSkills
          ? _update
          : null,
      updating: hub?.busy ?? false,
      onWhatsTheDifference: () => showToolsDifferenceSheet(context),
      header: curator == null ? null : CuratorSectionHost(controller: curator),
    );
  }

  /// A state with no list (loading, empty, failed) keeps the curator above
  /// it: a run works on a profile with no skills, and a failed list says
  /// nothing about the curator. Without a curator the state stands alone.
  Widget _withCurator(Widget state) {
    final curator = _curator;
    if (curator == null) return state;
    return GroupedListView(
      children: [
        CuratorSectionHost(controller: curator),
        state,
      ],
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
    return SkillJobBar(
      key: const ValueKey('job-bar'),
      title: job.title,
      onTap: () => showSkillJobSheet(context, hub),
    );
  }
}
