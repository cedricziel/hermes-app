import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'care_row_value.dart';

/// Where the check is, as the Server screen's Tools row tells it.
enum ServerCheckRowState {
  /// Nothing ran yet, or the result was dropped.
  idle,

  /// A check is running now.
  running,

  /// The last check's summary and age are shown.
  result,
}

/// The "Run a check" row of the Server screen's Tools section: what the
/// check does, that it is running now, or what the last one found and when.
/// Models only; the screen reads the controller.
class ServerCheckRow extends StatelessWidget {
  const ServerCheckRow({
    super.key,
    required this.state,
    this.summary,
    this.ago,
    this.onTap,
  });

  final ServerCheckRowState state;

  /// With [ServerCheckRowState.result]: "All checks passed" or "2 problems".
  final String? summary;

  /// With [ServerCheckRowState.result]: "just now", "5 minutes ago".
  final String? ago;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = this.summary;
    final ago = this.ago;
    return CareValueRow(
      title: l10n.serverCareCheckRun,
      value: state == ServerCheckRowState.running
          ? l10n.serverCareCheckRowChecking
          : null,
      subtitle: switch (state) {
        ServerCheckRowState.running => null,
        ServerCheckRowState.result when summary != null && ago != null =>
          l10n.serverCareCheckRowSubtitleResult(summary, ago),
        _ => l10n.serverCareCheckRowSubtitle,
      },
      onTap: onTap,
    );
  }
}
