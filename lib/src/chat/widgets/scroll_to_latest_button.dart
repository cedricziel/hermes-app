import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ComposerHeightNotifier;
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';

/// The chat list's jump-to-latest button above the composer: named for
/// screen readers, and out of the semantics tree and out of reach while it is
/// scaled away.
class ScrollToLatestButton extends StatelessWidget {
  const ScrollToLatestButton({
    super.key,
    required this.animation,
    required this.onPressed,
  });

  final Animation<double> animation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeArea = MediaQuery.paddingOf(context).bottom;
    return Consumer<ComposerHeightNotifier>(
      builder: (context, composer, _) => Positioned(
        right: 16,
        bottom: composer.height + 20 + safeArea,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final hidden = animation.value == 0;
            return ExcludeSemantics(
              excluding: hidden,
              child: IgnorePointer(ignoring: hidden, child: child),
            );
          },
          child: ScaleTransition(
            scale: animation,
            child: FloatingActionButton(
              heroTag: null,
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: scheme.surfaceContainer,
              foregroundColor: scheme.onSurface,
              tooltip: context.l10n.chatScrollToLatest,
              onPressed: onPressed,
              child: const Icon(Icons.keyboard_arrow_down),
            ),
          ),
        ),
      ),
    );
  }
}
