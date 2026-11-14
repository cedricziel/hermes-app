import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';

/// The pinned bottom of the Browse and Type pages: a warning note when it
/// applies, and the filled button that chooses the folder. With a null
/// [onPressed] the button is disabled.
class WorkspaceUseBar extends StatelessWidget {
  const WorkspaceUseBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.note,
  });

  final String label;
  final String? note;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        // At the largest text size the note and the button can be taller than
        // the room, so the bar itself scrolls instead of overflowing.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          // The same centred column as the lists above it.
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                math.max(metrics.gutter, (box.maxWidth - metrics.maxWidth) / 2),
                12,
                math.max(metrics.gutter, (box.maxWidth - metrics.maxWidth) / 2),
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GroupedStatusLine(
                        icon: AppIcons.warning,
                        text: note!,
                        color: colors.warning,
                        size: metrics.subtitleSize,
                        scaleIcon: true,
                        liveRegion: true,
                      ),
                    ),
                  // A Mac button keeps its own width, at the end of the column.
                  if (FilesMetrics.of(context).pointer)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        key: const Key('folder-browser-use'),
                        onPressed: onPressed,
                        style: FilesMetrics.of(context).buttonStyle(),
                        child: Text(label, textAlign: TextAlign.center),
                      ),
                    )
                  else
                    FilledButton(
                      key: const Key('folder-browser-use'),
                      onPressed: onPressed,
                      style: FilesMetrics.of(context)
                          .buttonStyle(fullWidth: true),
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
