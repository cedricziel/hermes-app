import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/app_banner.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../memory_proposals.dart';
import '../memory_proposals_controller.dart';
import '../memory_proposals_repository.dart';
import '../memory_settings.dart';
import 'memory_learning_section.dart';
import 'memory_proposal_parts.dart';

const kProposalsIntro =
    'Hermes wanted to change what it remembers. Nothing here is saved until '
    'you approve it. Long new text is shortened in this list; approving '
    'applies all of it.';

const kAskBeforeSavingSubtitle =
    'Off: Hermes saves new entries itself and only asks before a background '
    'review replaces or removes one';

/// The Waiting for you list: an intro, what the last decision came to, a row
/// for each proposal, Reject all, and the Ask before saving switch. [snapshot]
/// is null until the first read ends. [selectedId] marks the row whose detail
/// shows beside the list.
class MemoryProposalsList extends StatelessWidget {
  const MemoryProposalsList({
    super.key,
    required this.snapshot,
    required this.onOpen,
    required this.onRetry,
    required this.onRejectAll,
    this.selectedId,
    this.notice,
    this.deciding = false,
    this.askBeforeSaving,
    this.onAskBeforeSaving,
  });

  final ProposalsSnapshot? snapshot;
  final String? selectedId;
  final MemoryProposalsNotice? notice;

  /// Approve all or Reject all is running.
  final bool deciding;
  final ValueChanged<MemoryProposal> onOpen;
  final VoidCallback onRetry, onRejectAll;

  /// `memory.write_approval`; null while the settings are not read, which
  /// disables the switch.
  final bool? askBeforeSaving;
  final ValueChanged<bool>? onAskBeforeSaving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final read = snapshot;
    final proposals = read?.proposals ?? const <MemoryProposal>[];
    return GroupedListView(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            12,
            metrics.rowPadding,
            12,
          ),
          child: Text(
            kProposalsIntro,
            style: TextStyle(fontSize: metrics.subtitleSize, color: muted),
          ),
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppBanner(
              tone: notice!.isError
                  ? AppBannerTone.error
                  : AppBannerTone.success,
              icon: notice!.isError ? AppIcons.error : AppIcons.checkCircle,
              title: notice!.title,
              detail: notice!.detail ?? '',
            ),
          ),
        if (read == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else ...[
          ..._notes(l10n, read),
          if (proposals.isNotEmpty)
            GroupedSection(
              children: [
                for (final proposal in proposals)
                  GroupedRow(
                    key: ValueKey('proposal-${proposal.id}'),
                    title: proposalPreview(proposal),
                    titleMaxLines: 2,
                    subtitle: proposalOrigin(proposal),
                    leading: ProposalBadge(proposal.action),
                    selected: proposal.id == selectedId,
                    onTap: () => onOpen(proposal),
                  ),
              ],
            )
          else if (read.waiting != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Text(
                    l10n.memoryProposalsEmptyTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.memoryProposalsEmptyBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: metrics.subtitleSize,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          if (proposals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Align(
                child: TextButton(
                  key: const Key('proposals-reject-all'),
                  onPressed: deciding ? null : onRejectAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.memoryRejectAllAction),
                ),
              ),
            ),
        ],
        GroupedSection(
          children: [
            GroupedSwitchRow(
              key: const Key('proposals-ask-before-saving'),
              title: memorySettingLabel(
                context.l10n,
                MemorySetting.writeApproval,
              ),
              subtitle: kAskBeforeSavingSubtitle,
              subtitleMaxLines: 3,
              value: askBeforeSaving ?? false,
              onChanged: askBeforeSaving == null ? null : onAskBeforeSaving,
            ),
          ],
        ),
      ],
    );
  }

  /// What could not be read, as a row that retries.
  List<Widget> _notes(AppLocalizations l10n, ProposalsSnapshot read) {
    final rows = <Widget>[];
    void note(String title, String? detail) => rows.add(
      GroupedSection(
        children: [
          GroupedRow(
            wrapWhenStacked: true,
            title: title,
            subtitle: detail,
            subtitleMaxLines: 6,
            value: l10n.commonRetry,
            onTap: onRetry,
          ),
        ],
      ),
    );
    final both =
        read.memory.status == ProposalReadStatus.unsupported &&
        read.skills.status == ProposalReadStatus.unsupported;
    if (both) {
      note(l10n.memoryProposalsReadUnsupported, null);
      return rows;
    }
    for (final (failedTitle, kind) in [
      (l10n.memoryProposalsReadFailedMemory, read.memory),
      (l10n.memoryProposalsReadFailedSkills, read.skills),
    ]) {
      switch (kind.status) {
        case ProposalReadStatus.ok:
        case ProposalReadStatus.unsupported:
          break;
        case ProposalReadStatus.failed:
          note(failedTitle, null);
        case ProposalReadStatus.unreadable:
          note(l10n.memoryProposalsReadUnreadable, kind.raw);
      }
    }
    return rows;
  }
}
