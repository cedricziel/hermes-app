import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../widgets/markdown_links.dart';
import 'discover_tab.dart' show TrustBadge;
import 'hermes_skills_hub_repository.dart';
import 'skill_detail_screen.dart' show skillMarkdownBody;
import 'skill_job_sheet.dart';
import 'skills_hub_controller.dart';

/// A skill on the hub: what it is, what it contains and what the server's
/// security scan found, before anything is installed.
///
/// The scan runs when the page opens. Install is offered only as the scan's
/// policy allows: at once for `allow`, after a confirmation that lists the
/// findings for `ask`, and not at all for `block`.
class HubSkillScreen extends StatefulWidget {
  const HubSkillScreen({super.key, required this.hub, required this.skill});

  final SkillsHubController hub;
  final HubSkill skill;

  @override
  State<HubSkillScreen> createState() => _HubSkillScreenState();
}

class _HubSkillScreenState extends State<HubSkillScreen> {
  HubPreview? _preview;
  HubScan? _scan;
  bool _previewFailed = false;
  bool _scanFailed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _preview = null;
      _scan = null;
      _previewFailed = false;
      _scanFailed = false;
    });
    final repository = widget.hub.repository;
    final profile = widget.hub.skills.profile;
    final id = widget.skill.identifier;
    await Future.wait([
      repository
          .preview(id, profile: profile)
          .then(
            (p) => _apply(() => _preview = p),
            onError: (_) => _apply(() => _previewFailed = true),
          ),
      repository
          .scan(id, profile: profile)
          .then(
            (s) => _apply(() => _scan = s),
            onError: (_) => _apply(() => _scanFailed = true),
          ),
    ]);
  }

  void _apply(VoidCallback change) {
    if (!_disposed) setState(change);
  }

  Future<void> _install({bool confirmed = false}) async {
    final job = widget.hub.install(widget.skill, _scan, confirmed: confirmed);
    if (job != null && mounted) await showSkillJobSheet(context, widget.hub);
  }

  Future<void> _confirmAndInstall() async {
    final scan = _scan;
    if (scan == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Install ${widget.skill.name}?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scan.policyReason.isNotEmpty
                    ? scan.policyReason
                    : 'The security scan asks for your confirmation.',
              ),
              const SizedBox(height: 12),
              for (final f in scan.findings) _FindingRow(f),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Install anyway'),
          ),
        ],
      ),
    );
    if (go == true) await _install(confirmed: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(widget.skill.name)),
        bottomNavigationBar: _bottom(context),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kDetailContentMaxWidth,
                ),
                child: _body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final skill = widget.skill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (skill.description.isNotEmpty) Text(skill.description),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TrustBadge(skill.trustLevel),
            if (skill.source.isNotEmpty) Chip(label: Text(skill.source)),
            if (_preview != null)
              Chip(label: Text('${_preview!.files.length} files')),
          ],
        ),
        const SizedBox(height: 16),
        _scanCard(theme),
        if (_previewFailed)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Could not load the skill\'s contents.'),
          ),
        if (_preview != null) ...[
          if (_preview!.files.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('FILES', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            for (final f in _preview!.files)
              Text(
                f,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
          ],
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GptMarkdown(
                skillMarkdownBody(_preview!.skillMd),
                onLinkTap: markdownLinkHandler(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _scanCard(ThemeData theme) {
    if (_scanFailed) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not run the security scan.'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final scan = _scan;
    if (scan == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Running the security scan…'),
        ),
      );
    }
    final color = switch (scan.policy) {
      InstallPolicy.allow => theme.colorScheme.primary,
      InstallPolicy.ask => context.hermesColors.warning,
      InstallPolicy.block => theme.colorScheme.error,
    };
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SECURITY SCAN', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              switch (scan.policy) {
                InstallPolicy.allow => 'Passed',
                InstallPolicy.ask => 'Caution: confirmation required',
                InstallPolicy.block => 'Blocked',
              },
              key: const ValueKey('scan-verdict'),
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
            if (scan.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(scan.summary),
            ],
            if (scan.severityCounts.values.any((n) => n > 0)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in scan.severityCounts.entries)
                    if (e.value > 0) Chip(label: Text('${e.value} ${e.key}')),
                ],
              ),
            ],
            if (scan.policy == InstallPolicy.block &&
                scan.policyReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(scan.policyReason, style: TextStyle(color: color)),
            ],
            for (final f in scan.findings) ...[
              const Divider(height: 20),
              _FindingRow(f),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _bottom(BuildContext context) {
    final hub = widget.hub;
    final scan = _scan;
    Widget button;
    String? caption;
    if (hub.isInstalled(widget.skill)) {
      button = const FilledButton(onPressed: null, child: Text('Installed'));
    } else if (scan == null) {
      button = const FilledButton(onPressed: null, child: Text('Install'));
    } else {
      final busy = hub.busy;
      switch (scan.policy) {
        case InstallPolicy.allow:
          button = FilledButton(
            onPressed: busy ? null : _install,
            child: const Text('Install'),
          );
        case InstallPolicy.ask:
          button = OutlinedButton(
            onPressed: busy ? null : _confirmAndInstall,
            child: const Text('Install anyway…'),
          );
          caption = 'Server policy: ask. You will be asked to confirm.';
        case InstallPolicy.block:
          button = const FilledButton(onPressed: null, child: Text('Install'));
          caption = 'Blocked by the server\'s policy.';
      }
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: double.infinity, child: button),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow(this.finding);

  final ScanFinding finding;

  @override
  Widget build(BuildContext context) {
    final where = [
      if (finding.file.isNotEmpty) finding.file,
      if (finding.line != null) '${finding.line}',
    ].join(':');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${finding.severity.toUpperCase()}  ${finding.description}'),
          if (where.isNotEmpty)
            Text(
              where,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
        ],
      ),
    );
  }
}
