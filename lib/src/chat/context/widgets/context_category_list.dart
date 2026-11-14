import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/loading_skeleton.dart';
import '../context_models.dart';
import 'context_fill_bar.dart';
import 'context_format.dart';

/// What the list of "What's in it" shows.
enum ContextCategoryListState {
  loaded,
  loading,
  failed,

  /// The server has no breakdown: nothing is drawn, and nothing says why.
  unsupported,
}

/// The friendly name of [kind]. The server's own labels are never shown.
String contextCategoryName(
  AppLocalizations l10n,
  ContextCategoryKind kind,
) => switch (kind) {
  ContextCategoryKind.systemPrompt => l10n.chatContextCategoryNameSystemPrompt,
  ContextCategoryKind.toolDefinitions => l10n.chatContextCategoryNameTools,
  ContextCategoryKind.rules => l10n.chatContextCategoryNameRules,
  ContextCategoryKind.skills => l10n.chatContextCategoryNameSkills,
  ContextCategoryKind.mcp => l10n.chatContextCategoryNameMcp,
  ContextCategoryKind.subagentDefinitions =>
    l10n.chatContextCategoryNameSubagents,
  ContextCategoryKind.memory => l10n.chatContextCategoryNameMemory,
  ContextCategoryKind.conversation => l10n.chatContextCategoryNameConversation,
  ContextCategoryKind.other => l10n.chatContextCategoryNameOther,
};

/// "What's in it" on the Context details page: one row per category in the
/// order given (largest first), a decorative bar under each, and a footer
/// that says the numbers are estimated tokens. Only the list loads or fails;
/// the total above it stays.
class ContextCategoryList extends StatelessWidget {
  const ContextCategoryList({
    super.key,
    required this.state,
    this.categories = const [],
    this.onRetry,
  });

  final ContextCategoryListState state;
  final List<ContextCategory> categories;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == ContextCategoryListState.unsupported) {
      return const SizedBox.shrink();
    }
    if (state == ContextCategoryListState.loaded && categories.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final heading = Semantics(
      header: true,
      child: Text(
        l10n.chatContextCategoryHeading,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    final body = switch (state) {
      ContextCategoryListState.loading => LoadingSkeleton(
        label: l10n.chatContextCategoryLoading,
      ),
      ContextCategoryListState.failed => _Failed(onRetry: onRetry),
      _ => _Rows(categories: categories),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        heading,
        const SizedBox(height: 4),
        body,
        if (state == ContextCategoryListState.loaded) ...[
          const SizedBox(height: 8),
          Text(
            l10n.chatContextCategoryFooter,
            style: TextStyle(fontSize: 13, color: subtle),
          ),
        ],
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.categories});

  final List<ContextCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = categories.fold<int>(0, (sum, c) => sum + c.tokens);
    final barColor = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              container: true,
              label:
                  '${contextCategoryName(l10n, category.kind)}, '
                  '${l10n.chatContextCategoryTokens(contextTokensFull(l10n, category.tokens))}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nameAndValue(
                      context,
                      Text(
                        contextCategoryName(l10n, category.kind),
                        style: const TextStyle(fontSize: 15),
                      ),
                      Text(
                        contextTokensFull(l10n, category.tokens),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ContextFillBar(
                      fraction: total == 0 ? 0 : category.tokens / total,
                      height: 3,
                      color: barColor,
                      animate: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Text(l10n.chatContextCategoryFailed),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            style: contextButtonStyle(context),
            onPressed: onRetry,
            child: Text(l10n.chatContextCategoryRetry),
          ),
        ),
      ],
    );
  }
}

/// Name and count side by side; at the largest text size the count moves under
/// the name so neither is broken mid-word.
Widget _nameAndValue(BuildContext context, Widget name, Widget value) {
  if (contextLargeText(context)) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [name, value],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: name),
      const SizedBox(width: 12),
      value,
    ],
  );
}
