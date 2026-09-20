import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../profiles/hermes_profiles_repository.dart';
import 'hermes_skills_repository.dart';
import 'skill_detail_screen.dart';
import 'skill_editor_screen.dart';
import 'skills_controller.dart';

/// The skills installed on a profile: switch them on and off, read and edit
/// them, and create new ones.
///
/// It starts on [chatProfile] and can look at another profile without moving
/// the chat. It pops with a drafted chat message when the user asks the agent
/// to delete a skill, which the chat puts in its composer.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({
    super.key,
    this.repository,
    this.profiles,
    this.chatProfile,
  });

  final HermesSkillsRepository? repository;
  final HermesProfilesRepository? profiles;
  final String? chatProfile;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  late final SkillsController _controller;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final api = widget.repository == null
        ? context.read<AuthController>().api?.raw
        : null;
    _controller = SkillsController(
      repository:
          widget.repository ??
          HermesSkillsRepository(api ?? (throw StateError('not signed in'))),
      profiles:
          widget.profiles ??
          (api == null ? null : HermesProfilesRepository(api)),
      chatProfile: widget.chatProfile,
      events: _events(),
    );
    _controller
      ..load()
      ..loadProfiles();
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
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(HermesSkill skill) async {
    final draft = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            SkillDetailScreen(controller: _controller, name: skill.name),
      ),
    );
    if (draft != null && mounted) Navigator.of(context).pop(draft);
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
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Skills'),
          actions: [
            _ProfileChip(controller: _controller),
            const SizedBox(width: 12),
          ],
        ),
        floatingActionButton: _controller.status == SkillsStatus.ready
            ? FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New skill'),
              )
            : null,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _body(),
          ),
        ),
      ),
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
  const _ProfileChip({required this.controller});

  final SkillsController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    if (profile == null) return const SizedBox.shrink();
    final others = controller.availableProfiles;
    if (others.isEmpty) return Chip(label: Text(profile));
    return PopupMenuButton<String>(
      tooltip: 'Profile',
      onSelected: controller.selectProfile,
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
    final muted = skill.enabled ? scheme.onSurfaceVariant : scheme.outline;
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
