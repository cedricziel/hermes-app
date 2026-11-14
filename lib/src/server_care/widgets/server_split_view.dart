import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/settings_pane.dart';
import '../../widgets/state_message.dart';

/// The width of the overview list beside a page on a wide window.
const double kServerListWidth = 340;

/// The Server screen on a wide window: the overview [list] on the left, the
/// page that is selected on the right.
///
/// It lays out two panes and nothing else. The page in [detail] is a full
/// settings page; the pane tells its bar not to offer Back ([SettingsPane])
/// and gives it [onClose] to leave through. With no [detail] the pane says
/// that there is nothing to show.
///
/// Swapping [detail] for a page of another [Key] disposes the old page, so a
/// page that holds anything private lets go of it.
class ServerSplitView extends StatelessWidget {
  const ServerSplitView({
    super.key,
    required this.list,
    required this.detail,
    required this.onClose,
    this.listWidth = kServerListWidth,
  });

  final Widget list;

  /// The selected page, or null when the server has none to offer.
  final Widget? detail;

  /// Called by a page that has nothing left to show, such as Usage on a server
  /// without the route.
  final VoidCallback onClose;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: listWidth,
          child: FocusTraversalGroup(child: list),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: FocusTraversalGroup(
            child: SettingsPane(
              close: onClose,
              child: detail ?? const _NothingToShow(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NothingToShow extends StatelessWidget {
  const _NothingToShow();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StateMessage(
      icon: AppIcons.info,
      title: context.l10n.serverCareSplitEmpty,
    ),
  );
}
