import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_icon_button.dart';
import 'reply_error_note.dart';

/// What the user asked to do with the last turn.
enum TurnAction {
  retry('Trying again…'),
  edit('Taking the prompt back…');

  const TurnAction(this.progress);

  /// Said while the action runs.
  final String progress;
}

/// The retry or edit running on the last turn, or why the last one failed.
@immutable
class TurnActionStatus {
  const TurnActionStatus({this.running, this.problem});

  static const idle = TurnActionStatus();

  final TurnAction? running;
  final String? problem;

  @override
  bool operator ==(Object other) =>
      other is TurnActionStatus &&
      other.running == running &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(running, problem);
}

/// The small row of actions under a finished reply — assistant-ui's action
/// bar. Copy takes the reply's text; retry, when given, asks again, and edit
/// takes the prompt back to change it. A reply the user [stopped] says so
/// first, so it does not read as finished. While [status] has an action
/// running, it takes the place of retry and edit; a [TurnActionStatus.problem]
/// is said below the bar.
class MessageActions extends StatefulWidget {
  const MessageActions({
    super.key,
    required this.text,
    this.showCopy = true,
    this.stopped = false,
    this.onRetry,
    this.onEdit,
    this.status = TurnActionStatus.idle,
  });

  final String text;

  /// False for a failed reply that kept no text.
  final bool showCopy;
  final bool stopped;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final TurnActionStatus status;

  @override
  State<MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<MessageActions> {
  Timer? _copiedTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showCopy &&
        widget.onRetry == null &&
        widget.onEdit == null &&
        !widget.stopped &&
        widget.status == TurnActionStatus.idle) {
      return const SizedBox.shrink();
    }
    final color = context.hermesColors.subtleText;
    final touch = platformChromeOf(context) == PlatformChrome.ios;
    final box = touch ? kAppleMinTapTarget : 32.0;
    Widget action(String label, AppIconSet icon, VoidCallback onPressed) =>
        NamedIconButton(
          label: label,
          icon: icon,
          iconSize: 16,
          color: color,
          onPressed: onPressed,
          visualDensity: touch ? VisualDensity.standard : VisualDensity.compact,
          constraints: BoxConstraints.tightFor(width: box, height: box),
          padding: EdgeInsets.zero,
        );
    final running = widget.status.running;
    final problem = widget.status.problem;
    final bar = Padding(
      padding: EdgeInsets.only(top: touch ? 0 : 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.stopped) ...[
            AppIcon(AppIcons.stop, size: 16, color: color),
            const SizedBox(width: 4),
            Text('Stopped', style: TextStyle(color: color, fontSize: 12.5)),
            const SizedBox(width: 8),
          ],
          if (widget.showCopy)
            action(
              _copied ? 'Copied' : 'Copy',
              _copied ? AppIcons.check : AppIcons.copyOutlined,
              _copy,
            ),
          if (running != null)
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: SizedBox(
                  height: box,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: touch ? 12 : 8),
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          running.progress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            if (widget.onRetry case final retry?)
              action('Try again', AppIcons.refresh, retry),
            if (widget.onEdit case final edit?)
              action('Edit prompt', AppIcons.edit, edit),
          ],
        ],
      ),
    );
    if (problem == null || running != null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(liveRegion: true, child: ReplyErrorNote(problem)),
        bar,
      ],
    );
  }
}
