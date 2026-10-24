import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../telemetry/breadcrumbs.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/settings_scaffold.dart';
import 'memory_decisions.dart';
import 'memory_proposals.dart';
import 'memory_proposals_controller.dart';
import 'memory_settings.dart';
import 'memory_settings_controller.dart';
import 'widgets/memory_proposal_detail.dart';
import 'widgets/memory_proposals_list.dart';
import 'widgets/memory_proposals_split.dart';

/// Opens the Waiting for you inbox for the profile [controller] reads.
Future<void> openMemoryProposals(
  BuildContext context, {
  required MemoryProposalsController controller,
  MemorySettingsController? settings,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        MemoryProposalsScreen(controller: controller, settings: settings),
  ),
);

/// Waiting for you: the memory and skill changes Hermes holds for approval.
/// At [isWideLayout] the list sits beside the selected proposal; narrower, a
/// proposal opens as its own page.
class MemoryProposalsScreen extends StatefulWidget {
  const MemoryProposalsScreen({
    super.key,
    required this.controller,
    this.settings,
  });

  final MemoryProposalsController controller;

  /// The profile's memory settings, for the Ask before saving switch.
  final MemorySettingsController? settings;

  @override
  State<MemoryProposalsScreen> createState() => _MemoryProposalsScreenState();
}

class _MemoryProposalsScreenState extends State<MemoryProposalsScreen> {
  MemoryProposalsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    Breadcrumbs breadcrumbs;
    try {
      breadcrumbs = context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      breadcrumbs = Breadcrumbs.none;
    }
    breadcrumbs('memory.inbox.opened', {'count': _controller.waiting ?? 0});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.load();
    });
  }

  Future<void> _rejectAll() async {
    final count = _controller.waiting ?? 0;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reject all changes?',
      message:
          'Hermes drops the $count change${count == 1 ? '' : 's'} listed here. '
          'This cannot be undone.',
      confirmLabel: 'Reject all',
      destructive: true,
    );
    if (confirmed && mounted) await _controller.decideAll(approve: false);
  }

  void _open(MemoryProposal proposal, {required bool wide}) {
    _controller.select(proposal.id);
    if (wide) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryProposalPage(
          controller: _controller,
          proposalId: proposal.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, ?widget.settings]),
    builder: (context, _) {
      final controller = _controller;
      final settings = widget.settings?.settings;
      final waiting = controller.waiting ?? 0;
      return SettingsScaffold(
        title: 'Waiting for you',
        subtitle: controller.profile,
        actions: [
          SettingsBarAction(
            key: const Key('proposals-refresh'),
            label: 'Refresh',
            icon: AppIcons.refresh,
            onPressed: controller.loading ? null : controller.load,
          ),
          if (waiting > 0)
            SettingsBarAction(
              key: const Key('proposals-approve-all'),
              label: 'Approve all',
              icon: AppIcons.checkCircle,
              onPressed: controller.deciding
                  ? null
                  : () => controller.decideAll(approve: true),
            ),
        ],
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = isWideLayout(context, width: constraints.maxWidth);
            final selected = controller.selected;
            final list = MemoryProposalsList(
              snapshot: controller.snapshot,
              selectedId: wide ? selected?.id : null,
              notice: controller.notice,
              deciding: controller.deciding,
              onOpen: (proposal) => _open(proposal, wide: wide),
              onRetry: controller.load,
              onRejectAll: _rejectAll,
              askBeforeSaving: settings?.writeApproval,
              onAskBeforeSaving: (value) =>
                  widget.settings?.change(MemorySetting.writeApproval, value),
            );
            if (!wide || selected == null) return list;
            return MemoryProposalsSplit(
              list: list,
              detailKey: selected.id,
              detail: BoundProposalDetail(
                controller: controller,
                proposal: selected,
              ),
            );
          },
        ),
      );
    },
  );
}

/// A proposal's detail wired to the inbox: its decision state, its changes
/// and the two buttons.
class BoundProposalDetail extends StatelessWidget {
  const BoundProposalDetail({
    super.key,
    required this.controller,
    required this.proposal,
  });

  final MemoryProposalsController controller;
  final MemoryProposal proposal;

  @override
  Widget build(BuildContext context) => MemoryProposalDetail(
    proposal: proposal,
    decision:
        controller.decisions?.stateOf(proposal.id) ?? MemoryDecisionState.idle,
    diff: controller.diffOf(proposal.id),
    busy: controller.deciding,
    onApprove: () => controller.decide(proposal, approve: true),
    onReject: () => controller.decide(proposal, approve: false),
    onShowChanges: () => controller.showChanges(proposal),
  );
}

/// One proposal as a page, for a window too narrow for a pane. It closes
/// itself when the proposal is gone from the list.
class MemoryProposalPage extends StatefulWidget {
  const MemoryProposalPage({
    super.key,
    required this.controller,
    required this.proposalId,
  });

  final MemoryProposalsController controller;
  final String proposalId;

  @override
  State<MemoryProposalPage> createState() => _MemoryProposalPageState();
}

class _MemoryProposalPageState extends State<MemoryProposalPage> {
  var _closing = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final proposal = controller.snapshot?.proposals
          .where((p) => p.id == widget.proposalId)
          .firstOrNull;
      if (proposal == null && controller.snapshot != null && !_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      return SettingsScaffold(
        title: proposal?.action.label ?? 'Change',
        previousTitle: 'Waiting for you',
        body: proposal == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: BoundProposalDetail(
                  controller: controller,
                  proposal: proposal,
                ),
              ),
      );
    },
  );
}
