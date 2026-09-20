import 'package:flutter/material.dart';

import 'mcp_banner.dart';
import 'mcp_command_review_items.dart';
import 'mcp_presentation.dart';

/// Shows [McpCommandReview] as a bottom sheet below
/// [mcpWideBreakpoint] and as a dialog at or above it. True only
/// when the user confirms; going back, tapping outside or the system back
/// gesture all answer false.
Future<bool> showMcpCommandReview(
  BuildContext context,
  List<McpCommandReviewItem> commands, {
  required String confirmLabel,
}) async {
  Widget review(BuildContext context) =>
      McpCommandReview(commands: commands, confirmLabel: confirmLabel);
  final wide = MediaQuery.sizeOf(context).width >= mcpWideBreakpoint;
  final confirmed = wide
      ? await showDialog<bool>(
          context: context,
          builder: (dialog) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: review(dialog),
            ),
          ),
        )
      : await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: review,
        );
  return confirmed == true;
}

/// The step before a command server is saved: it says that the server is a
/// program that runs on the Hermes host, and shows the exact command, each
/// argument and the names, never the values, of its environment variables.
class McpCommandReview extends StatefulWidget {
  const McpCommandReview({
    super.key,
    required this.commands,
    required this.confirmLabel,
  });

  final List<McpCommandReviewItem> commands;
  final String confirmLabel;

  @override
  State<McpCommandReview> createState() => _McpCommandReviewState();
}

class _McpCommandReviewState extends State<McpCommandReview> {
  bool _answered = false;

  void _answer(bool confirmed) {
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final many = widget.commands.length > 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            many ? 'Run these on your server?' : 'Run this on your server?',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            many
                ? 'Command servers are programs that run on your Hermes host, '
                      "with that machine's permissions, every time a chat uses "
                      'them.'
                : 'A command server is a program that runs on your Hermes host, '
                      "with that machine's permissions, every time a chat uses "
                      'it.',
          ),
          const SizedBox(height: 12),
          for (final command in widget.commands) _Command(command),
          const McpBanner(
            tone: McpTone.warning,
            icon: Icons.warning_amber_outlined,
            title: 'Only add commands you recognise.',
            detail:
                'You can remove the server afterwards, but not undo what it '
                'ran.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('mcp-review-confirm'),
            onPressed: () => _answer(true),
            child: Text(widget.confirmLabel),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('mcp-review-back'),
            onPressed: () => _answer(false),
            child: const Text('Back to edit'),
          ),
        ],
      ),
    );
  }
}

class _Command extends StatelessWidget {
  const _Command(this.item);

  final McpCommandReviewItem item;

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _Fact('command', [item.command], mono),
            if (item.args.isNotEmpty) _Fact('args', item.args, mono),
            if (item.envNames.isNotEmpty) _Fact('env', item.envNames, mono),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.lines, this.style);

  final String label;
  final List<String> lines;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines) SelectableText(line, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
