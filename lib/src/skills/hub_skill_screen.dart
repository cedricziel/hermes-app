import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

import '../../l10n/l10n.dart';

import '../widgets/settings_scaffold.dart';
import '../widgets/grouped_list.dart';
import 'widgets/skill_install_confirm_dialog.dart';
import 'widgets/skill_security_scan.dart';
import 'widgets/skill_markdown_panel.dart';

import 'widgets/skill_badges.dart';
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
    final go = await showAppDialog<bool>(
      context: context,
      builder: (context) =>
          SkillInstallConfirmDialog(skillName: widget.skill.name, scan: scan),
    );
    if (go == true) await _install(confirmed: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) => SettingsScaffold(
        title: widget.skill.name,
        previousTitle: context.l10n.skillsScreenTitle,
        body: Column(
          children: [
            Expanded(child: GroupedListView(children: [_body(context)])),
            _bottom(context),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final skill = widget.skill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (skill.description.isNotEmpty) Text(skill.description),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TrustBadge(skill.trustLevel),
            if (skill.source.isNotEmpty) Text(skill.source),
            if (_preview != null)
              Text(
                context.l10n.skillsHubSkillFileCount(_preview!.files.length),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SkillSecurityScan(scan: _scan, failed: _scanFailed, onRetry: _load),
        if (_previewFailed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(context.l10n.skillsHubSkillContentsFailed),
          ),
        if (_preview != null) ...[
          if (_preview!.files.isNotEmpty)
            GroupedSection(
              header: context.l10n.skillsHubSkillFiles,
              children: [
                for (final file in _preview!.files)
                  Padding(
                    padding: EdgeInsets.all(
                      GroupedMetrics.of(context).rowPadding,
                    ),
                    child: Text(
                      file,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: GroupedMetrics.of(context).footerSize,
                      ),
                    ),
                  ),
              ],
            ),
          SkillMarkdownPanel(text: skillMarkdownBody(_preview!.skillMd)),
        ],
      ],
    );
  }

  Widget _bottom(BuildContext context) {
    final hub = widget.hub;
    final scan = _scan;
    final l10n = context.l10n;
    Widget button;
    String? caption;
    if (hub.isInstalled(widget.skill)) {
      button = FilledButton(
        onPressed: null,
        child: Text(l10n.skillsHubInstalled),
      );
    } else if (scan == null) {
      button = FilledButton(
        onPressed: null,
        child: Text(l10n.skillsHubSkillInstall),
      );
    } else {
      final busy = hub.busy;
      switch (scan.policy) {
        case InstallPolicy.allow:
          button = FilledButton(
            onPressed: busy ? null : _install,
            child: Text(l10n.skillsHubSkillInstall),
          );
        case InstallPolicy.ask:
          button = OutlinedButton(
            onPressed: busy ? null : _confirmAndInstall,
            child: Text(l10n.skillsHubSkillInstallAnyway),
          );
          caption = l10n.skillsHubSkillPolicyAsk;
        case InstallPolicy.block:
          button = FilledButton(
            onPressed: null,
            child: Text(l10n.skillsHubSkillInstall),
          );
          caption = l10n.skillsHubSkillPolicyBlock;
      }
    }
    final metrics = GroupedMetrics.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(metrics.gutter, 8, metrics.gutter, 12),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.maxWidth),
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
        ),
      ),
    );
  }
}
