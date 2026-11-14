import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import 'file_glyph.dart';

/// A blank surface with only the file type's icon, drawn over a preview while
/// the app is inactive, so the app switcher's snapshot shows no name and no
/// content. The screen shows it whether or not App Lock is on.
class FilePreviewCover extends StatelessWidget {
  const FilePreviewCover({super.key, required this.glyph});

  final FileGlyph glyph;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.filesCoverLabel,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ExcludeSemantics(
          child: AppIcon(
            glyph.icon,
            size: 72,
            color: context.hermesColors.subtleText,
          ),
        ),
      ),
    ),
  );
}
