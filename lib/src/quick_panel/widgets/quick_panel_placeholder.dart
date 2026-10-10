import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The quick panel until it holds a chat: a field to type into, focused each
/// time the panel shows, and Escape to hide it.
class QuickPanelPlaceholder extends StatefulWidget {
  const QuickPanelPlaceholder({
    super.key,
    required this.shown,
    required this.onHide,
  });

  /// Fires each time the panel is shown.
  final Stream<void> shown;

  final VoidCallback onHide;

  @override
  State<QuickPanelPlaceholder> createState() => _QuickPanelPlaceholderState();
}

class _QuickPanelPlaceholderState extends State<QuickPanelPlaceholder> {
  final _focus = FocusNode();
  late final StreamSubscription<void> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.shown.listen((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _subscription.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onHide,
      },
      child: Material(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                focusNode: _focus,
                autofocus: true,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(
                  hintText: 'Ask Hermes…',
                  border: InputBorder.none,
                ),
              ),
              const Spacer(),
              Text(
                'Sending from the quick panel comes in a later update.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
