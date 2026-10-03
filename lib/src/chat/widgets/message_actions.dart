import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';

/// The small row of actions under a finished reply — assistant-ui's action
/// bar. Copy takes the reply's text; retry, when given, asks again. A reply
/// the user [stopped] says so first, so it does not read as finished.
class MessageActions extends StatefulWidget {
  const MessageActions({
    super.key,
    required this.text,
    this.showCopy = true,
    this.stopped = false,
    this.onRetry,
  });

  final String text;

  /// False for a failed reply that kept no text.
  final bool showCopy;
  final bool stopped;
  final VoidCallback? onRetry;

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
    if (!widget.showCopy && widget.onRetry == null && !widget.stopped) {
      return const SizedBox.shrink();
    }
    final color = context.hermesColors.subtleText;
    Widget action(String label, IconData icon, VoidCallback onPressed) =>
        NamedIconButton(
          label: label,
          icon: icon,
          iconSize: 16,
          color: color,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.stopped) ...[
            Icon(Icons.stop_circle_outlined, size: 16, color: color),
            const SizedBox(width: 4),
            Text('Stopped', style: TextStyle(color: color, fontSize: 12.5)),
            const SizedBox(width: 8),
          ],
          if (widget.showCopy)
            action(
              _copied ? 'Copied' : 'Copy',
              _copied ? Icons.check : Icons.content_copy_outlined,
              _copy,
            ),
          if (widget.onRetry case final retry?)
            action('Try again', Icons.refresh, retry),
        ],
      ),
    );
  }
}
