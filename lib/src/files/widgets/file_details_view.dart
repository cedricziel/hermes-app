import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import 'file_glyph.dart';
import 'file_preview_header.dart';
import 'files_metrics.dart';

/// A button of the details view.
class FileDetailsAction {
  const FileDetailsAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;
}

/// What is known of a file that has no inline preview: a PDF, any other file,
/// a file too large for text, or a download the user cancelled. A 56 pt icon,
/// the name (wrapping), "type · size", an optional [note] line, then the
/// [primary] action filled and the [secondary] ones outlined, stacked at full
/// width up to 320 pt. Nothing is fetched until one is pressed.
class FileDetailsView extends StatelessWidget {
  const FileDetailsView({
    super.key,
    required this.name,
    this.size,
    this.note,
    required this.primary,
    this.secondary = const [],
  });

  final String name;

  /// Null until a header or `read-text` said.
  final int? size;
  final String? note;
  final FileDetailsAction primary;
  final List<FileDetailsAction> secondary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = FilesMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final style = files.buttonStyle(fullWidth: true);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: AppIcon(
                        fileGlyphForName(name).icon,
                        size: 56,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filePreviewSubtitle(l10n, name, size),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 8),
                      Text(note!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: primary.onPressed,
                      style: style,
                      child: Text(primary.label),
                    ),
                    for (final action in secondary) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: action.onPressed,
                        style: style,
                        child: Text(action.label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
