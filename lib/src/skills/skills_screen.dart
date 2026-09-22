import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';

import '../profiles/hermes_profiles_repository.dart';
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
  final _search = TextEditingController();

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

  AppEventLogger _events() {
    try {
      return context.read<AppEventLogger>();
    } on ProviderNotFoundException {
      return noopAppEventLogger;
    }
  }

  @override
  void dispose() {
    _hub?.dispose();
    _tabs.dispose();
    _controller.dispose();
    _search.dispose();
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
        final installed = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kDetailContentMaxWidth),
            child: _body(),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Skills'),
            actions: [
              _ProfileChip(controller: _controller, onSelected: _selectProfile),
              const SizedBox(width: 12),
            ],
            bottom: hub == null
                ? null
                : TabBar(
                    controller: _tabs,
                    tabs: const [
                      Tab(text: 'Installed'),
                      Tab(text: 'Discover'),
                    ],
                  ),
          ),
          floatingActionButton:
              _controller.status == SkillsStatus.ready && _tabs.index == 0
              ? FloatingActionButton.extended(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('New skill'),
                )
              : null,
          body: hub == null
              ? installed
              : Column(
                  children: [
                    if (hub.busy) _JobBar(hub: hub),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          installed,
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: kDetailContentMaxWidth,
                              ),
                              child: DiscoverTab(hub: hub, onOpen: _openHub),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _body() {
    switch (_controller.status) {
      case SkillsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SkillsStatus.unsupported:
        return const _Message('The connected Hermes does not support skills.');
      case SkillsStatus.failed:
        return _Message(
          'Could not load skills',
          action: FilledButton(
            onPressed: _controller.load,
            child: const Text('Retry'),
          ),
        );
      case SkillsStatus.ready:
        break;
    }
    if (!_controller.hasSkills) {
      return const _Message('This profile has no skills yet.');
    }
    final groups = _controller.groups;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _controller.setQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search skills',
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final filter in SkillFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _controller.filter == filter,
                    onSelected: (_) => _controller.setFilter(filter),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? _Message(
                  'No skills match.',
                  action: TextButton(
                    onPressed: () {
                      _search.clear();
                      _controller.clearFilters();
                    },
                    child: const Text('Clear filters'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          group.category.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      for (final skill in group.skills)
                        _SkillRow(
                          skill: skill,
                          onTap: () => _open(skill),
                          onToggle: (v) => _toggle(skill, v),
                        ),
                    ],
                    if (_hub != null && _controller.hasHubSkills)
                      ListTile(
                        leading: const Icon(Icons.system_update_alt),
                        title: const Text('Check for updates'),
                        subtitle: const Text('Updates the skills from the hub'),
                        enabled: !_hub!.busy,
                        onTap: _update,
                      ),
                  ],
                ),
        ),
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

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.controller, required this.onSelected});

  final SkillsController controller;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    if (profile == null) return const SizedBox.shrink();
    final others = controller.availableProfiles;
    if (others.isEmpty) return Chip(label: Text(profile));
    return PopupMenuButton<String>(
      tooltip: 'Profile',
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final p in others)
          CheckedPopupMenuItem(
            value: p.name,
            checked: p.name == profile,
            child: Text(p.label),
          ),
      ],
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(profile), const Icon(Icons.arrow_drop_down)],
        ),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skill,
    required this.onTap,
    required this.onToggle,
  });

  final HermesSkill skill;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = skill.enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: 0.65);
    return ListTile(
      key: ValueKey('skill-${skill.name}'),
      onTap: onTap,
      title: Text(
        skill.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: skill.enabled ? null : muted,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (skill.description.isNotEmpty)
            Text(
              skill.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SourceBadge(skill.source),
              if (skill.usage > 0)
                Text(
                  'used ${skill.usage}×',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
      trailing: Switch(value: skill.enabled, onChanged: onToggle),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});

  final SkillSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(switch (source) {
        SkillSource.hub => 'Hub',
        SkillSource.bundled => 'Bundled',
        SkillSource.agent => 'Agent',
      }, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
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
        subtitle: const LinearProgressIndicator(),
        onTap: () => showSkillJobSheet(context, hub),
      ),
    );
  }
}
