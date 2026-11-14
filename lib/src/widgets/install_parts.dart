import 'package:flutter/material.dart';

import '../theme/hermes_theme.dart';
import 'motion_spinner.dart';

/// The monospace style of an installer's lines and commands.
const kInstallMono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  height: 1.4,
);

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
            SelectableText(line, style: kInstallMono)
          else
            Text(
              line,
              style: kInstallMono,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
      ],
    ),
  );
}

/// A spinner beside a line of text (see [MotionSpinner] for reduced motion).
class InstallSpinnerRow extends StatelessWidget {
  const InstallSpinnerRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const MotionSpinner(),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

/// An install in progress: [title] with a spinner, the latest [lines] when
/// there are any, and a muted [note], under the lines or, with [noteFirst],
/// right under the title. [selectableLines] makes the lines copyable.
/// [liveRegion] announces the title (and the note when it is first) as one
/// polite live region; the lines are not part of it, so each new line does
/// not interrupt a screen reader.
class InstallRunningBody extends StatelessWidget {
  const InstallRunningBody({
    super.key,
    required this.title,
    required this.lines,
    required this.note,
    this.selectableLines = false,
    this.liveRegion = false,
    this.noteFirst = false,
  });

  final String title;
  final List<String> lines;
  final String note;
  final bool selectableLines;
  final bool liveRegion;
  final bool noteFirst;

  @override
  Widget build(BuildContext context) {
    final noteText = Text(
      note,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: context.hermesColors.subtleText),
    );
    Widget head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstallSpinnerRow(title),
        if (noteFirst) ...[const SizedBox(height: 4), noteText],
      ],
    );
    if (liveRegion) {
      head = Semantics(
        liveRegion: true,
        container: true,
        label: noteFirst ? '$title. $note' : title,
        child: ExcludeSemantics(child: head),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          InstallLogLines(lines, selectable: selectableLines),
        ],
        if (!noteFirst) ...[const SizedBox(height: 6), noteText],
      ],
    );
  }
}
