import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';

/// What a Server screen row shows once a value that does not fit has moved.
typedef CareRowText = ({String? value, String? subtitle});

/// The room a [GroupedRow] gives its value: half the row's content, less the
/// gap before it.
double careRowValueWidth(double rowContentWidth) => rowContentWidth / 2 - 8;

/// Passes [value] on when it fits [maxValueWidth], otherwise moves it into the
/// subtitle (before an existing subtitle, joined with a middle dot), since a
/// [GroupedRow] would cut it with an ellipsis.
CareRowText careRowText({
  required String? value,
  String? subtitle,
  required double maxValueWidth,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) {
  if (value == null || value.isEmpty) return (value: null, subtitle: subtitle);
  final painter = TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  if (width <= maxValueWidth) return (value: value, subtitle: subtitle);
  return (
    value: null,
    subtitle: subtitle == null || subtitle.isEmpty
        ? value
        : '$value · $subtitle',
  );
}

/// A [GroupedRow] for a status value that may be longer than half the row,
/// such as "Running, some channels offline". Such a value becomes the
/// subtitle; titles and subtitles wrap rather than end in an ellipsis.
class CareValueRow extends StatelessWidget {
  const CareValueRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.warning,
    this.error,
    this.onTap,
  });

  final String title;
  final String? value;
  final String? subtitle;
  final String? warning;
  final String? error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final stacked = groupedRowStacksAt(context);
    return LayoutBuilder(
      builder: (context, box) {
        // Stacked rows show the value under the title at full width.
        final text = stacked
            ? (value: value, subtitle: subtitle)
            : careRowText(
                value: value,
                subtitle: subtitle,
                maxValueWidth: careRowValueWidth(
                  box.maxWidth - 2 * metrics.rowPadding,
                ),
                style: DefaultTextStyle.of(context).style
                    .merge(TextStyle(fontSize: metrics.subtitleSize)),
                textScaler: scaler,
                textDirection: direction,
              );
        return GroupedRow(
          title: title,
          titleMaxLines: null,
          value: text.value,
          subtitle: text.subtitle,
          subtitleMaxLines: null,
          warning: warning,
          error: error,
          onTap: onTap,
        );
      },
    );
  }
}
