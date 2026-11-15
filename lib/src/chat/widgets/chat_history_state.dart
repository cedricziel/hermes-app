import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/busy_bar.dart' show reduceMotionOf;
import '../../widgets/loading_skeleton.dart';
import '../../widgets/state_message.dart';
import '../chat_models.dart';

/// How long a chat's messages may take before the transcript shows that they
/// are loading, so a read that finishes at once never flashes it.
const kChatHistoryLoadingDelay = Duration(milliseconds: 180);

/// What the transcript of a stored chat shows until its messages are on
/// screen: a quiet skeleton while they load (after
/// [kChatHistoryLoadingDelay]), or the failure with a Retry. It fills the
/// transcript's area; the header and the composer around it stay as they are.
class ChatHistoryState extends StatefulWidget {
  const ChatHistoryState({
    super.key,
    required this.status,
    this.onRetry,
    this.delay = kChatHistoryLoadingDelay,
    this.bottomPadding = 0,
  });

  final ChatHistoryStatus status;

  /// Reads the messages again; without it a failure offers no button.
  final VoidCallback? onRetry;
  final Duration delay;

  /// Height of whatever overlays the bottom of the area, the composer in chat.
  final double bottomPadding;

  @override
  State<ChatHistoryState> createState() => _ChatHistoryStateState();
}

class _ChatHistoryStateState extends State<ChatHistoryState> {
  Timer? _timer;
  late bool _due = widget.delay == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_due) {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _due = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final Widget content = switch (widget.status) {
      // Read out once when it appears, so a screen reader hears that the
      // messages did not load without hunting for the text.
      ChatHistoryStatus.failed => _FadeIn(
        key: const ValueKey('failed'),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: StateMessage(
            icon: AppIcons.error,
            title: l10n.chatWidgetsHistoryFailedTitle,
            detail: l10n.chatWidgetsHistoryFailedDetail,
            action: widget.onRetry == null
                ? null
                : FilledButton(
                    onPressed: widget.onRetry,
                    child: Text(l10n.commonRetry),
                  ),
          ),
        ),
      ),
      ChatHistoryStatus.loading =>
        !_due
            ? const SizedBox.expand()
            // A box shorter than the skeleton (a phone on its side with the
            // keyboard open) clips it from the bottom instead of overflowing.
            : _FadeIn(
                key: const ValueKey('skeleton'),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: LoadingSkeleton(
                    label: l10n.chatWidgetsHistoryLoading,
                    lines: 6,
                    liveRegion: true,
                    // The default bar colour is the page's own on light
                    // surfaces; this one reads on both themes.
                    color: scheme.onSurface.withValues(alpha: 0.16),
                  ),
                ),
              ),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: content,
    );
  }
}

/// Fades its child in when it is first built, unless the system asks to
/// reduce motion. Keyed by what it shows, so each state fades in on its own.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: reduceMotionOf(context) ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 150),
    builder: (context, opacity, child) =>
        Opacity(key: _fadeKey, opacity: opacity, child: child),
    child: child,
  );
}

const _fadeKey = ValueKey('chat-history-fade');
