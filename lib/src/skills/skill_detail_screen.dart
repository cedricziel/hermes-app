import 'package:flutter/material.dart';

import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'widgets/skill_detail_actions.dart';
import 'widgets/skill_markdown_panel.dart';

import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import 'hermes_skills_repository.dart';
import 'skill_editor_screen.dart';
import 'skill_job_sheet.dart';
import 'skills_controller.dart';
import 'skills_hub_controller.dart';
import 'widgets/skill_badges.dart';
import '../widgets/route_dismissal.dart';

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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${widget.name}?',
      message:
          'The app cannot delete skills. This drafts a message asking the '
          'agent to do it; nothing is sent until you send it.',
      confirmLabel: 'Draft message',
    );
    if (confirmed && mounted) {
      dismissRoute(context, deleteRequestFor(widget.name));
    }
  }

  Future<void> _uninstall() async {
    final hub = widget.hub;
    if (hub == null) return;
    final go = await showConfirmDialog(
      context,
      title: 'Uninstall ${widget.name}?',
      message: 'The skill is removed from this profile.',
      confirmLabel: 'Uninstall',
    );
    if (!go || !mounted) return;
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
        return SettingsScaffold(
          title: widget.name,
          previousTitle: 'Skills',
          body: skill == null
              ? const Center(child: Text('This skill no longer exists.'))
              : GroupedListView(children: [_details(skill)]),
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
            if (skill.category.isNotEmpty)
              Text(skill.category, style: theme.textTheme.bodySmall),
            SourceBadge(skill.source),
            if (skill.usage > 0) Text('used ${skill.usage}×'),
          ],
        ),
        SkillDetailActions(
          enabled: skill.enabled,
          editable: skill.editable,
          contentReady: _content != null,
          canUninstall: skill.source == SkillSource.hub && widget.hub != null,
          busy: widget.hub?.busy ?? false,
          onToggle: (value) => _toggle(skill, value),
          onEdit: _edit,
          onAskDelete: _askDelete,
          onUninstall: _uninstall,
        ),
        if (_failed)
          GroupedSection(
            children: [
              const GroupedRow(
                title: 'Could not load this skill',
                chevron: false,
              ),
              GroupedRow(title: 'Retry', chevron: false, onTap: _load),
            ],
          )
        else if (_content == null)
          const GroupedSection(
            children: [
              GroupedRow(
                title: 'Loading skill contents…',
                chevron: false,
                trailing: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            ],
          )
        else
          SkillMarkdownPanel(text: skillMarkdownBody(_content!)),
      ],
    );
  }

  Future<void> _toggle(HermesSkill skill, bool enabled) async {
    final ok = await widget.controller.toggle(skill.name, enabled);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change ${skill.name}')));
    }
  }
}
