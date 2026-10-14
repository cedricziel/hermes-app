import 'package:flutter/material.dart';

import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/named_icon_button.dart';
import '../../../widgets/state_message.dart';

/// The open chat's activity: Now (live work), Plan and This session
/// (reference), in that order. A section without content is left out.
///
/// Shown in a sheet on phones and as an inspector on wide layouts; [onClose]
/// adds a close button for the sheet. [scrollController] is the sheet's, so
/// dragging the list drags the sheet.
class ActivityPanel extends StatelessWidget {
  const ActivityPanel({
    super.key,
    this.now = const [],
    this.plan,
    this.session = const [],
    this.onClose,
    this.scrollController,
  });

  final List<Widget> now;
  final Widget? plan;
  final List<Widget> session;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  bool get isEmpty => now.isEmpty && plan == null && session.isEmpty;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final onClose = this.onClose;
    return Column(
      key: const Key('activity-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Activity',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (onClose != null)
                NamedIconButton(
                  key: const Key('activity-close'),
                  label: 'Close activity',
                  icon: AppIcons.close,
                  onPressed: onClose,
                ),
            ],
          ),
        ),
        Expanded(
          child: isEmpty
              ? ListView(
                  controller: scrollController,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: StateMessage(
                        icon: AppIcons.inspector,
                        title: 'No activity for this chat',
                        detail:
                            'Plans, running work and session details show up '
                            'here.',
                      ),
                    ),
                  ],
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (now.isNotEmpty) ...[const _SectionTitle('Now'), ...now],
                    if (plan != null) ...[const _SectionTitle('Plan'), plan],
                    if (session.isNotEmpty) ...[
                      const _SectionTitle('This session'),
                      ...session,
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Semantics(
      header: true,
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.hermesColors.subtleText,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    ),
  );
}

/// Opens the Activity panel, or closes the inspector when it is [open].
class ActivityButton extends StatelessWidget {
  const ActivityButton({
    super.key,
    required this.open,
    required this.onPressed,
  });

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => NamedIconButton(
    key: const Key('header-activity'),
    label: open ? 'Hide activity' : 'Activity',
    icon: AppIcons.inspector,
    isSelected: open,
    onPressed: onPressed,
  );
}
