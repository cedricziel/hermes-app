import 'package:flutter/widgets.dart';

import '../files/widgets/safe_path_text.dart';

/// [text] cut to at most [maxChars] characters, the middle replaced by an
/// ellipsis. With [keepExtension] the end is the extension and a few
/// characters before it, so `quarterly-report-final.pdf` keeps its `.pdf`.
String elideMiddle(
  String text, {
  required int maxChars,
  bool keepExtension = false,
}) {
  text = safePathText(text);
  final chars = safeTextUnits(text);
  if (chars.length <= maxChars || maxChars < 5) return text;
  final dot = text.lastIndexOf('.');
  final extension = dot > 0 ? text.substring(dot) : '';
  var tail = (maxChars - 1) ~/ 2;
  if (keepExtension && extension.isNotEmpty && extension.length <= 8) {
    final wanted = extension.characters.length + 3;
    tail = wanted < maxChars - 4 ? wanted : maxChars - 4;
  }
  final head = maxChars - 1 - tail;
  return '${chars.take(head).join()}…${chars.sublist(chars.length - tail).join()}';
}

/// What the end of a [MiddleEllipsisText] keeps when the text is cut.
enum MiddleTail {
  /// A file name: the extension and three characters before it, else the
  /// last three characters.
  extension,

  /// An identifier such as a model id: about 40 percent of what fits, and at
  /// least 8 characters, so `claude-sonnet-4-5-20…250929` keeps the part that
  /// tells versions apart. A `.` is never an extension (`gpt-5.1`).
  balanced,
}

/// A name drawn on at most [maxLines] lines, wrapped at word boundaries (a
/// word breaks only when nothing else fits). A name too long for them is cut
/// in the middle, so the end that tells names apart stays: with the default
/// [tail] its extension. With no [maxLines] the whole name wraps. The full
/// text is what assistive technology reads.
class MiddleEllipsisText extends StatelessWidget {
  const MiddleEllipsisText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.tail = MiddleTail.extension,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final MiddleTail tail;

  @override
  Widget build(BuildContext context) {
    final text = safePathText(this.text);
    final lines = maxLines;
    if (lines == null) return Text(text, style: style);
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        if (!width.isFinite) return Text(text, style: style, maxLines: lines);
        bool fits(String candidate) {
          final painter = TextPainter(
            text: TextSpan(text: candidate, style: base),
            textDirection: direction,
            textScaler: scaler,
            maxLines: lines,
          )..layout(maxWidth: width);
          try {
            return !painter.didExceedMaxLines;
          } finally {
            painter.dispose();
          }
        }

        return Text(
          fits(text) ? text : _cut(text, fits, tail),
          semanticsLabel: text,
          style: style,
          maxLines: lines,
          overflow: TextOverflow.clip,
        );
      },
    );
  }

  /// The longest `head…tail` that fits, found by bisection.
  static String _cut(String text, bool Function(String) fits, MiddleTail mode) {
    final chars = safeTextUnits(text);
    if (mode == MiddleTail.balanced) return _cutBalanced(chars, fits);
    final dot = text.lastIndexOf('.');
    final extension = dot > 0 ? text.substring(dot) : '';
    final keep = extension.isNotEmpty && extension.length <= 8
        ? extension.characters.length + 3
        : 3;
    final tailLength = keep < chars.length - 1 ? keep : chars.length ~/ 2;
    final tail = chars.sublist(chars.length - tailLength).join();
    var low = 0;
    var high = chars.length - tailLength - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (fits('${chars.take(mid).join()}…$tail')) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return '${chars.take(low).join()}…$tail';
  }

  /// The most units that fit, the last 40 percent of them (at least 8) as
  /// the tail.
  static String _cutBalanced(List<String> chars, bool Function(String) fits) {
    String candidate(int kept) {
      final wanted = (kept * 0.4).round();
      final tail = kept < 8 ? kept : (wanted < 8 ? 8 : wanted);
      return '${chars.take(kept - tail).join()}…'
          '${chars.sublist(chars.length - tail).join()}';
    }

    var low = 0;
    var high = chars.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (fits(candidate(mid))) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return candidate(low);
  }
}
