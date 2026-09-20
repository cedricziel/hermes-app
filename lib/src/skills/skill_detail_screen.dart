import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'hermes_skills_repository.dart';
import 'skill_editor_screen.dart';
import 'skill_job_sheet.dart';
import 'skills_controller.dart';
import 'skills_hub_controller.dart';
import 'skills_screen.dart' show SourceBadge;

/// What the chat composer is given when the user asks the agent to delete a
/// skill. The server has no delete route, so the agent does it.
String deleteRequestFor(String name) =>
    'Please delete the skill named "$name".';

/// The `SKILL.md` without its front matter, which renders as noise.
String skillMarkdownBody(String text) {
  final match = RegExp(r'^---\s*\n[\s\S]*?\n---\s*(\n|$)').firstMatch(text);
  return match == null ? text : text.substring(match.end).trimLeft();
}

/// One skill: its rendered `SKILL.md`, its switch, and, for a skill the agent
/// wrote, Edit and Ask agent to delete. Pops with the drafted request when
/// the user asks for a delete.
class SkillDetailScreen extends StatefulWidget {
  const SkillDetailScreen({
    super.key,
    required this.controller,
    required this.name,
    this.hub,
  });

  final SkillsController controller;
  final SkillsHubController? hub;
  final String name;

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  String? _content;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _content = null;
      _failed = false;
    });
    try {
      final text = await widget.controller.repository.content(
        widget.name,
        profile: widget.controller.profile,
      );
      if (mounted) setState(() => _content = text);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit() async {
    final text = _content;
    if (text == null) return;
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SkillEditorScreen.edit(
          name: widget.name,
          initialText: text,
          onSave: (_, _, updated) =>
              widget.controller.save(widget.name, updated),
        ),
      ),
    );
    if (saved != null) await _load();
  }

  Future<void> _askDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.name}?'),
        content: const Text(
          'The app cannot delete skills. This drafts a message asking the '
          'agent to do it; nothing is sent until you send it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Draft message'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(deleteRequestFor(widget.name));
    }
  }

  Future<void> _uninstall() async {
    final hub = widget.hub;
    if (hub == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Uninstall ${widget.name}?'),
        content: const Text('The skill is removed from this profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (hub.uninstall(widget.name) != null) {
      await showSkillJobSheet(context, hub);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, ?widget.hub]),
      builder: (context, _) {
        final skill = widget.controller.skill(widget.name);
        return Scaffold(
          appBar: AppBar(title: Text(widget.name)),
          body: skill == null
              ? const Center(child: Text('This skill no longer exists.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _details(skill),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _details(HermesSkill skill) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (skill.category.isNotEmpty) Chip(label: Text(skill.category)),
            SourceBadge(skill.source),
            if (skill.usage > 0) Text('used ${skill.usage}×'),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enabled'),
          subtitle: const Text('The agent may load this skill'),
          value: skill.enabled,
          onChanged: (v) async {
            final ok = await widget.controller.toggle(skill.name, v);
            if (!ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not change ${skill.name}')),
              );
            }
          },
        ),
        if (skill.editable)
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _content == null ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton(
                onPressed: _askDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Ask agent to delete'),
              ),
            ],
          )
        else if (skill.source == SkillSource.hub && widget.hub != null)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.hub!.busy ? null : _uninstall,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Uninstall'),
              ),
            ],
          )
        else
          Text(
            'Bundled and hub skills can only be switched on or off here.',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        if (_failed)
          Column(
            children: [
              const Text('Could not load this skill'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (_content == null)
          const Center(child: CircularProgressIndicator())
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GptMarkdown(skillMarkdownBody(_content!)),
            ),
          ),
      ],
    );
  }
}
