import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../starter_prompts.dart';

/// Empty-thread state — a centered greeting plus a grid of starter prompts,
/// the same shape as assistant-ui's default `<ThreadWelcome />`.
class WelcomeView extends StatelessWidget {
  const WelcomeView({
    super.key,
    required this.greetingName,
    required this.prompts,
    required this.onPick,
  });

  final String? greetingName;
  final List<StarterPrompt> prompts;
  final ValueChanged<StarterPrompt> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = greetingName == null || greetingName!.isEmpty
        ? 'Where should we begin?'
        : 'Where should we begin, $greetingName?';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask Hermes Agent about your server, your codebase, or '
                'anything it has tools for.',
                style: TextStyle(
                  color: context.hermesColors.subtleText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  // One column at the full width when two cards do not fit.
                  final width = constraints.maxWidth < 2 * _cardWidth + 10
                      ? constraints.maxWidth
                      : _cardWidth;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final prompt in prompts)
                        _SuggestionCard(
                          text: prompt.text,
                          icon: _icon(prompt.source),
                          width: width,
                          onTap: () => onPick(prompt),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const double _cardWidth = 290;

IconData _icon(StarterSource source) => switch (source) {
  StarterSource.generic => Icons.lightbulb_outline,
  StarterSource.schedule => Icons.schedule,
  StarterSource.kanban => Icons.view_kanban_outlined,
  StarterSource.chat => Icons.chat_bubble_outline,
  StarterSource.skill => Icons.extension_outlined,
};

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.text,
    required this.icon,
    required this.width,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kHermesRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kHermesRadius),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: context.hermesColors.subtleText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
