import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);

/// The surface-high box an install command or an installer's lines sit in.
class InstallCodeBox extends StatelessWidget {
  const InstallCodeBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
}

/// The installer's latest lines in monospace, each cut off after
/// [maxLines]. With [selectable] each line is its own selectable text, so one
/// can be copied alone, and a long line wraps instead of being cut.
class InstallLogLines extends StatelessWidget {
  const InstallLogLines(
    this.lines, {
    super.key,
    this.maxLines = 1,
    this.selectable = false,
  });

  final List<String> lines;
  final int maxLines;
  final bool selectable;

  @override
  Widget build(BuildContext context) => InstallCodeBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (selectable)
            SelectableText(line, style: _mono)
          else
            Text(
              line,
              style: _mono,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
      ],
    ),
  );
}

/// A 16 pt spinner beside a line of text. With reduced motion the spinner is
/// a still hourglass, since a progress animation is what that setting turns
/// off.
class InstallSpinnerRow extends StatelessWidget {
  const InstallSpinnerRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: 16,
        child: MediaQuery.disableAnimationsOf(context)
            ? AppIcon(
                AppIcons.waiting,
                size: 16,
                color: context.hermesColors.subtleText,
              )
            : const CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

/// An install in progress: [title] with a spinner, the latest [lines] when
/// there are any, and a muted [note]. [selectableLines] and [liveRegion] are
/// for screens that want the lines copyable and the block announced.
class InstallRunningBody extends StatelessWidget {
  const InstallRunningBody({
    super.key,
    required this.title,
    required this.lines,
    required this.note,
    this.selectableLines = false,
    this.liveRegion = false,
  });

  final String title;
  final List<String> lines;
  final String note;
  final bool selectableLines;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstallSpinnerRow(title),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          InstallLogLines(lines, selectable: selectableLines),
        ],
        const SizedBox(height: 6),
        Text(
          note,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.hermesColors.subtleText),
        ),
      ],
    );
    return liveRegion ? Semantics(liveRegion: true, child: body) : body;
  }
}
