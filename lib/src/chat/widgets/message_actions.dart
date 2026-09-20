import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hermes_theme.dart';

/// The small row of actions under a finished reply — assistant-ui's action
/// bar. Copy takes the reply's text; retry, when given, asks again.
class MessageActions extends StatefulWidget {
  const MessageActions({
    super.key,
    required this.text,
    this.showCopy = true,
    this.onRetry,
  });

  final String text;

  /// False for a failed reply, whose text is only the error.
  final bool showCopy;
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
    if (!widget.showCopy && widget.onRetry == null) {
      return const SizedBox.shrink();
    }
    final color = context.hermesColors.subtleText;
    Widget action(String tooltip, IconData icon, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 16, color: color),
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
