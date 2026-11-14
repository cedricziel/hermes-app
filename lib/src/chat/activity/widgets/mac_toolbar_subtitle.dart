import 'package:flutter/material.dart';

import '../../../theme/hermes_theme.dart';
import 'working_indicator.dart';

const double _kIndicator = 12;
const double _kIndicatorGap = 5;

/// The least width the status is worth drawing at; below it the spinner and
/// the status are left out rather than shown as a lone spinner or an ellipsis.
const double _kMinStatus = 24;

/// The subtitle of a Mac chat toolbar: "profile · model" and, while Hermes
/// works, a 12 pt spinner and the newest Working sentence after it.
///
/// "profile · model" never shrinks (it is cut only when it alone does not fit);
/// the status gives way first, with an end ellipsis, and goes entirely, spinner
/// and separator with it, when too little room is left. A plain-model widget:
/// pass the words, not a controller.
class MacToolbarSubtitle extends StatelessWidget {
  const MacToolbarSubtitle({
    super.key,
    this.profile,
    this.model,
    this.status,
    this.busy = false,
  });

  final String? profile, model;

  /// The newest Working sentence; null or empty when nothing is working.
  final String? status;

  /// Whether the spinner is drawn before [status].
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final muted = context.hermesColors.subtleText;
    final style = DefaultTextStyle.of(context).style
        .merge(TextStyle(fontSize: 11, height: 1.25, color: muted));
    final lead = [
      if (profile case final profile? when profile.isNotEmpty) profile,
      if (model case final model? when model.isNotEmpty) model,
    ].join(' · ');
    final status = this.status?.trim();
    final working = status != null && status.isNotEmpty;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    Widget leadText(String text) => Text(
      text,
      key: const Key('mac-subtitle-lead'),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final room = box.hasBoundedWidth ? box.maxWidth : double.infinity;
        final withSeparator = working && lead.isNotEmpty ? '$lead · ' : lead;
        final spinner = busy ? _kIndicator + _kIndicatorGap : 0.0;
        final left = room - measure(withSeparator).ceilToDouble() - spinner;
        final showStatus = working && left >= _kMinStatus;
        final text = showStatus ? withSeparator : lead;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: room.isFinite ? room : 400,
                ),
                child: leadText(text),
              ),
            if (showStatus) ...[
              if (busy) ...[
                const WorkingIndicator(size: _kIndicator),
                const SizedBox(width: _kIndicatorGap),
              ],
              Flexible(
                child: Text(
                  status,
                  key: const Key('mac-subtitle-status'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
