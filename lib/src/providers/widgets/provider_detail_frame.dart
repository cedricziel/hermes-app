import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/state_message.dart';

/// The provider's name above its detail in the pane beside the list, where no
/// bar names it. On a pushed page the bar does, so this is not used there.
class ProviderDetailHeader extends StatelessWidget {
  const ProviderDetailHeader({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    // The same inset as the detail under it: the list view centres its
    // column at most `maxWidth` wide, and rows start `rowPadding` in.
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          metrics.gutter,
          (box.maxWidth - metrics.maxWidth) / 2,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            side + metrics.rowPadding,
            16,
            side + metrics.rowPadding,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              header: true,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What the pane beside the list says while there is no provider to show:
/// nothing is connected yet, so the list is where to start.
class ProviderDetailPlaceholder extends StatelessWidget {
  const ProviderDetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StateMessage(
      icon: AppIcons.tune,
      title: l10n.providersAddHeading,
      detail: l10n.providersDetailPlaceholder,
    );
  }
}
