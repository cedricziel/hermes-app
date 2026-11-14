import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../server_path.dart';
import 'files_metrics.dart';
import 'safe_path_text.dart';

/// "· on your server" as one unit that never breaks inside: the spaces are
/// non-breaking, so a wrapped path moves the whole suffix to the next line.
String serverPathSuffix(String onYourServer) =>
    '·\u00A0${onYourServer.replaceAll(' ', '\u00A0')}';

/// The font a server path is set in.
const String kServerPathFont = 'monospace';

/// [path] shortened to what [fits], the middle replaced by an ellipsis and the
/// last folder kept, so `/home/me/code/demo/api` can become `/home/…/demo/api`.
/// A path that fits is returned as it is. The tail keeps at most 28 characters
/// of the end (less when the head would be left with nothing), and the head
/// as much of the start as is left.
String elidePathMiddle(String path, bool Function(String) fits) {
  if (fits(path)) return path;
  final chars = path.characters.toList();
  // Nothing to cut out of one or two characters.
  if (chars.length < 3) return path;
  final last = path.lastIndexOf(
    RegExp(r'[/\\]'),
    path.length > 1 ? path.length - 2 : 0,
  );
  final lastSegment = last < 0
      ? chars.length ~/ 2
      : path.substring(last).characters.length;
  var tailLength = lastSegment.clamp(4, 28);
  tailLength = tailLength.clamp(1, chars.length - 2);
  String cut(int head, int tail) =>
      '${chars.take(head).join()}…${chars.sublist(chars.length - tail).join()}';
  while (true) {
    var low = 0;
    var high = chars.length - tailLength - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (fits(cut(mid, tailLength))) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    // Keep a head of at least a few characters, or give the tail back some
    // room: `…/api` alone says too little.
    if (low >= 4 || tailLength <= 6) return cut(low, tailLength);
    tailLength = (tailLength * 2 ~/ 3).clamp(6, tailLength - 1);
  }
}

/// A path drawn on one line, cut in the middle when it does not fit, with an
/// optional [suffix] that is always shown after it. The cut keeps the last
/// folder. A long press (and a pointer hover) shows the full path.
class PathCutText extends StatelessWidget {
  const PathCutText(
    this.path, {
    super.key,
    this.style,
    this.suffix,
    this.suffixStyle,
    this.tooltip = true,
    this.monospace = true,
  });

  final String path;
  final TextStyle? style;

  /// Text after the path that is never cut, such as ` · on your server`.
  final String? suffix;
  final TextStyle? suffixStyle;

  /// Whether a long press shows the full path.
  final bool tooltip;

  /// Set the path in the monospace font. A heading keeps its own font.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final path = safePathText(this.path);
    final base = DefaultTextStyle.of(context).style;
    final pathStyle = monospace
        ? base.merge(style).copyWith(fontFamily: kServerPathFont)
        : base.merge(style);
    final tailStyle = base.merge(suffixStyle ?? style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final suffix = this.suffix;
    final text = LayoutBuilder(
      builder: (context, box) {
        TextSpan span(String shown) => TextSpan(
          children: [
            TextSpan(text: shown, style: pathStyle),
            if (suffix != null) TextSpan(text: suffix, style: tailStyle),
          ],
        );
        bool fits(String shown) {
          final painter = TextPainter(
            text: span(shown),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout(maxWidth: box.maxWidth);
          try {
            return !painter.didExceedMaxLines;
          } finally {
            painter.dispose();
          }
        }

        final shown = box.maxWidth.isFinite
            ? elidePathMiddle(path, fits)
            : path;
        return Text.rich(
          span(shown),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        );
      },
    );
    // The drawn text may be shortened; a screen reader gets all of it.
    final labelled = Semantics(
      label: '$path${suffix ?? ''}',
      excludeSemantics: true,
      child: text,
    );
    if (!tooltip) return labelled;
    return Tooltip(
      message: path,
      excludeFromSemantics: true,
      triggerMode: TooltipTriggerMode.longPress,
      child: labelled,
    );
  }
}

/// A path on the Hermes server with "· on your server" after it, so it never
/// reads as a file on the phone.
///
/// By default it is one line cut in the middle (the last folder stays) with a
/// long press showing the full path. At a large text size, or with [wrap], the
/// whole path is shown and wraps, and "on your server" takes its own line at
/// the largest sizes. With [selectable] the path is always shown in full and
/// wraps (a shortened path could not be selected) and can be selected and
/// copied (⌘C on a Mac); the suffix is not part of what is copied.
///
/// A screen reader reads the full path and "on your server" as one label.
class ServerPathText extends StatelessWidget {
  /// A path the app parsed.
  ServerPathText(
    ServerPath path, {
    super.key,
    this.style,
    this.wrap,
    this.selectable = false,
  }) : path = path.value;

  /// A path that is not a [ServerPath], such as one that starts with `~`.
  const ServerPathText.text(
    this.path, {
    super.key,
    this.style,
    this.wrap,
    this.selectable = false,
  });

  final String path;
  final TextStyle? style;

  /// Show the whole path wrapped. Null: wrap at a large text size only.
  final bool? wrap;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = safePathText(this.path);
    final large = isLargeText(context);
    // A selectable path shows in full: a shortened one cannot be selected.
    final wrapped = wrap ?? (large || selectable);
    final base = DefaultTextStyle.of(context).style.merge(style);
    final suffix = serverPathSuffix(l10n.workspacesOnYourServer);
    final Widget text;
    if (!wrapped) {
      text = PathCutText(path, style: style, suffix: ' $suffix');
    } else {
      final pathText = Text(
        path,
        style: base.copyWith(fontFamily: kServerPathFont),
      );
      if (large) {
        text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            selectable ? SelectionArea(child: pathText) : pathText,
            Text(suffix, style: base),
          ],
        );
      } else {
        final pathSpan = TextSpan(
          text: path,
          style: base.copyWith(fontFamily: kServerPathFont),
        );
        final inline = Text.rich(
          TextSpan(
            children: [
              pathSpan,
              if (selectable)
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: SelectionContainer.disabled(
                    child: Text(' $suffix', style: base),
                  ),
                )
              else
                TextSpan(text: ' $suffix', style: base),
            ],
          ),
        );
        text = selectable ? SelectionArea(child: inline) : inline;
      }
    }
    return Semantics(
      container: true,
      label: l10n.workspacesPathLabel(path),
      excludeSemantics: true,
      child: text,
    );
  }
}
