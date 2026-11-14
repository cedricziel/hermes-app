import 'package:flutter/material.dart';

import '../../../theme/hermes_theme.dart';
import 'working_indicator.dart';

/// The subtitle of a Mac chat toolbar: "profile · model" and, while Hermes
/// works, a 12 pt spinner and the newest Working sentence after it.
///
/// "profile · model" never shrinks (it is cut only when it alone does not fit);
/// the status gives way first, with an end ellipsis. A plain-model widget:
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
    final style = TextStyle(fontSize: 11, height: 1.25, color: muted);
    final lead = [
      if (profile case final profile? when profile.isNotEmpty) profile,
      if (model case final model? when model.isNotEmpty) model,
    ].join(' · ');
    final status = this.status?.trim();
    final working = status != null && status.isNotEmpty;
    final text = working && lead.isNotEmpty ? '$lead · ' : lead;

    return LayoutBuilder(
      builder: (context, box) {
        final spinner = working && busy ? 17.0 : 0.0;
        final room = box.hasBoundedWidth ? box.maxWidth - spinner : 400.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: room < 0 ? 0 : room),
                child: Text(
                  text,
                  key: const Key('mac-subtitle-lead'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            if (working) ...[
              if (busy) ...[
                const WorkingIndicator(size: 12),
                const SizedBox(width: 5),
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
