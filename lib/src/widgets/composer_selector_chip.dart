import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A bounded composer selector with an independently named recovery action.
/// The accessible label and tooltip retain text that the visual label truncates.
class ComposerSelectorChip extends StatelessWidget {
  const ComposerSelectorChip({
    super.key,
    required this.label,
    this.semanticLabel,
    this.leading,
    this.trailing,
    this.onPressed,
    this.actionLabel,
    this.actionSemanticLabel,
    this.onAction,
  });

  final String label;
  final String? semanticLabel;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final String? actionLabel;
  final String? actionSemanticLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = semanticLabel ?? label;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: LayoutBuilder(
        builder: (context, constraints) => Material(
          color: theme.colorScheme.onSurface.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Tooltip(
                  message: name,
                  excludeFromSemantics: true,
                  child: Semantics(
                    label: name,
                    button: onPressed != null,
                    onTap: onPressed,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onPressed,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: LayoutBuilder(
                          builder: (context, mainConstraints) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (leading != null &&
                                    mainConstraints.maxWidth >= 80) ...[
                                  SizedBox.square(
                                    dimension: 24,
                                    child: Center(child: leading),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ),
                                if (trailing != null &&
                                    mainConstraints.maxWidth >= 80)
                                  trailing!,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (actionLabel != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(104.0, constraints.maxWidth * .45),
                  ),
                  child: Semantics(
                    label: actionSemanticLabel ?? actionLabel,
                    button: true,
                    enabled: onAction != null,
                    onTap: onAction,
                    excludeSemantics: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onAction,
                      child: Text(
                        actionLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
