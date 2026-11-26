import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_icon_button.dart';
import 'reply_error_note.dart';
import 'reply_interrupted_note.dart';

/// What the user asked to do with the last turn.
enum TurnAction {
  retry('Trying again…'),
  edit('Taking the prompt back…'),
  branch('Branching…');

  const TurnAction(this.progress);

  /// Said while the action runs.
  final String progress;
}

/// Why taking the turn back, or branching the chat, did not happen.
enum TurnProblemKind {
  /// Hermes could not be reached.
  unreachable,

  /// Hermes answered and refused.
  rejected,

  /// Hermes answered that its turn is still running ("busy"): nothing was
  /// changed and nothing was sent.
  busy,
}

/// A failed [action] and why, said under the last reply in the words of the
/// screen's locale (the controller makes no text).
@immutable
class TurnActionProblem {
  const TurnActionProblem(this.action, this.kind);

  final TurnAction action;
  final TurnProblemKind kind;

  /// The sentence for [l10n].
  String text(AppLocalizations l10n) => switch (kind) {
    TurnProblemKind.busy => l10n.chatTurnBusy,
    TurnProblemKind.rejected => l10n.chatTurnRejected(action.name),
    TurnProblemKind.unreachable => l10n.chatTurnUnreachable(action.name),
  };

  @override
  bool operator ==(Object other) =>
      other is TurnActionProblem &&
      other.action == action &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(action, kind);
}

/// The retry or edit running on the last turn, why the last one failed, and
/// whether they are held because the server may still be running the turn
/// ([held]: Retry and Edit show dimmed, with a line that says why).
@immutable
class TurnActionStatus {
  const TurnActionStatus({this.running, this.problem, this.held = false});

  static const idle = TurnActionStatus();

  final TurnAction? running;
  final TurnActionProblem? problem;
  final bool held;

  @override
  bool operator ==(Object other) =>
      other is TurnActionStatus &&
      other.running == running &&
      other.problem == problem &&
      other.held == held;

  @override
  int get hashCode => Object.hash(running, problem, held);
}

/// Where reading a reply aloud stands: [loading] while Hermes speaks it,
/// [playing] while it plays. Either can be stopped.
enum ReadAloudState { idle, loading, playing }

/// The small row of actions under a finished reply — assistant-ui's action
/// bar. Copy takes the reply's text; retry, when given, asks again, and edit
/// takes the prompt back to change it. A reply the user [stopped] says so
/// first, so it does not read as finished; one that [regenerated] an earlier
/// reply (Retry or Edit) says so on a line above the actions. While [status] has an action
/// running, it takes the place of retry and edit; a [TurnActionStatus.problem]
/// is said below the bar. While the status is [TurnActionStatus.held] Retry
/// and Edit stay on the bar but cannot be pressed, and a line says why
/// ([heldAnnounceKey] makes a screen reader say it once). A non-null [readAloud] adds Read aloud after Copy,
/// which [onReadAloud] starts and, while loading or playing, stops.
/// [onBranch], when given, copies the chat up to this reply into a new one.
class MessageActions extends StatefulWidget {
  const MessageActions({
    super.key,
    required this.text,
    this.showCopy = true,
    this.stopped = false,
    this.regenerated = false,
    this.onRetry,
    this.onEdit,
    this.onBranch,
    this.status = TurnActionStatus.idle,
    this.heldAnnounceKey,
    this.readAloud,
    this.onReadAloud,
  });

  final String text;

  /// False for a failed reply that kept no text.
  final bool showCopy;
  final bool stopped;
  final bool regenerated;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onBranch;
  final TurnActionStatus status;

  /// Says which reply the held line belongs to, for [ReplyInterruptedNote]'s
  /// announce-once rule. Null never announces, as in the catalog.
  final String? heldAnnounceKey;

  /// Null hides Read aloud: the profile has no text to speech, or the reply
  /// has nothing to say.
  final ReadAloudState? readAloud;

  /// Null disables Read aloud, for example during a voice call.
  final VoidCallback? onReadAloud;

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
        widget.onBranch == null &&
        widget.readAloud == null &&
        !widget.stopped &&
        !widget.regenerated &&
        widget.status == TurnActionStatus.idle) {
      return const SizedBox.shrink();
    }
    final color = context.hermesColors.subtleText;
    final android = isAndroid(context);
    final touch = platformChromeOf(context) == PlatformChrome.ios;
    final box = touch ? kAppleMinTapTarget : 32.0;
    Widget action(String label, AppIconSet icon, VoidCallback? onPressed) =>
        NamedIconButton(
          label: label,
          icon: icon,
          iconSize: 16,
          color: color,
          onPressed: onPressed,
          visualDensity: touch || android
              ? VisualDensity.standard
              : VisualDensity.compact,
          constraints: BoxConstraints.tightFor(width: box, height: box),
          padding: EdgeInsets.zero,
          style: android
              ? IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.padded,
                  minimumSize: const Size.square(32),
                )
              : null,
        );
    final running = widget.status.running;
    final problem = widget.status.problem;
    final held = widget.status.held && running == null;
    final l10n = context.l10n;
    final labelStyle = TextStyle(color: color, fontSize: 12.5);
    Widget statusLabel(AppIconSet icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: labelStyle)),
      ],
    );
    final bar = Padding(
      padding: EdgeInsets.only(top: touch ? 0 : 4),
      // A wrap, not a row: the label and five actions do not fit 320 pt, so
      // what does not fit goes on a second line instead of overflowing.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.stopped)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: statusLabel(AppIcons.stop, l10n.chatReplyStopped),
            ),
          if (widget.showCopy)
            action(
              _copied ? 'Copied' : 'Copy',
              _copied ? AppIcons.check : AppIcons.copyOutlined,
              _copy,
            ),
          if (widget.readAloud case final state?)
            switch (state) {
              ReadAloudState.idle => action(
                'Read aloud',
                AppIcons.speaker,
                widget.onReadAloud,
              ),
              ReadAloudState.playing => Semantics(
                liveRegion: true,
                child: action(
                  'Stop reading',
                  AppIcons.stop,
                  widget.onReadAloud,
                ),
              ),
              ReadAloudState.loading => Stack(
                alignment: Alignment.center,
                children: [
                  action('Stop reading', AppIcons.stop, widget.onReadAloud),
                  IgnorePointer(
                    child: SizedBox.square(
                      key: const Key('read-aloud-loading'),
                      dimension: 24,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ],
              ),
            },
          if (running != null)
            Semantics(
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
            )
          else ...[
            if (widget.onRetry case final retry?)
              action('Try again', AppIcons.refresh, held ? null : retry),
            if (widget.onEdit case final edit?)
              action('Edit prompt', AppIcons.edit, held ? null : edit),
            if (widget.onBranch case final branch?)
              action('Branch in new chat', AppIcons.branch, branch),
          ],
        ],
      ),
    );
    final showProblem = problem != null && running == null;
    if (!showProblem && !held && !widget.regenerated) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Above the actions, not beside them: five actions fill a 320 pt
        // row, and at large text the word would shrink to an ellipsis.
        if (widget.regenerated)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: statusLabel(AppIcons.refresh, l10n.chatReplyRegenerated),
          ),
        if (showProblem)
          Semantics(
            liveRegion: true,
            child: problem.kind == TurnProblemKind.busy
                ? ReplyInterruptedNote(
                    text: problem.text(l10n),
                    unconfirmed: true,
                  )
                : ReplyErrorNote(problem.text(l10n)),
          ),
        bar,
        if (held)
          ReplyInterruptedNote(
            text: l10n.chatTurnHeld,
            unconfirmed: true,
            announceKey: widget.heldAnnounceKey,
          ),
      ],
    );
  }
}
