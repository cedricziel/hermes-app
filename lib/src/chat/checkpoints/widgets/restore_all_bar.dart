import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/destructive_tint_button.dart';
import '../../../widgets/grouped_list.dart';
import '../checkpoints_state.dart';
import 'restore_refusal_text.dart';

/// The sticky footer of the Changes page: how many files differ and the red
/// outlined "Restore all files…" button, never filled.
///
/// A [refusal] disables the button and says why under it;
/// [RestoreRefusal.restoring] shows the button busy instead. [fileCount]
/// null reads "Some files differ". When the count and the label do not fit
/// side by side (large text, a long translation) the count sits over a
/// full-width button. Takes plain values and callbacks only.
class RestoreAllBar extends StatelessWidget {
  const RestoreAllBar({
    super.key,
    this.fileCount,
    this.refusal,
    this.onRestoreAll,
  });

  final int? fileCount;
  final RestoreRefusal? refusal;
  final VoidCallback? onRestoreAll;

  static const _countStyle = TextStyle(fontWeight: FontWeight.w600);

  /// Whether [count] and a button labelled [label] fit on one line in
  /// [width], with room for the count to stay on one line.
  static bool _fitsBeside(
    BuildContext context,
    double width,
    String count,
    String label, {
    required bool busy,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      try {
        return painter.width;
      } finally {
        painter.dispose();
      }
    }

    final base = DefaultTextStyle.of(context).style;
    final countWidth = measure(count, base.merge(_countStyle));
    // The button's own padding and border come on top of its label.
    final buttonWidth =
        measure(label, base.copyWith(fontWeight: FontWeight.w500)) +
        48 +
        // The busy spinner and its gap, plus a margin for the real font.
        (busy ? 24 : 0) +
        8;
    return countWidth + 12 + buttonWidth <= width;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final refusal = this.refusal;
    final busy = refusal == RestoreRefusal.restoring;
    final count = fileCount;
    final countText = count == null
        ? l10n.chatCheckpointsChangesBarSome
        : l10n.chatCheckpointsChangesBarCount(count);
    final label = busy
        ? l10n.chatCheckpointsChangesBarRestoring
        : l10n.chatCheckpointsChangesBarRestoreAll;
    final text = Text(countText, style: _countStyle);
    final button = DestructiveTintButton(
      label: label,
      busy: busy,
      onPressed: refusal == null ? onRestoreAll : null,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: GroupedMetrics.of(context).maxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: LayoutBuilder(
                builder: (context, box) {
                  final stacked = !_fitsBeside(
                    context,
                    box.maxWidth,
                    countText,
                    label,
                    busy: busy,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stacked) ...[
                        text,
                        const SizedBox(height: 10),
                        button,
                      ] else
                        Row(
                          spacing: 12,
                          children: [
                            Expanded(child: text),
                            button,
                          ],
                        ),
                      if (refusal != null && !busy)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            restoreRefusalText(l10n, refusal),
                            textAlign: stacked
                                ? TextAlign.start
                                : TextAlign.end,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.hermesColors.subtleText,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
