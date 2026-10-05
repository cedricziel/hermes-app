import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
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
    this.bottomPadding = 0,
    this.assistantName,
  });

  final String? greetingName;
  final String? assistantName;
  final List<StarterPrompt> prompts;
  final ValueChanged<StarterPrompt> onPick;

  /// Height of whatever overlays the bottom of this view, the composer in chat.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final greeting = assistantName != null
        ? 'What can $assistantName help you with?'
        : greetingName == null || greetingName!.isEmpty
        ? 'Where should we begin?'
        : 'Where should we begin, $greetingName?';

    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (viewport.maxHeight - bottomPadding).clamp(
              0,
              double.infinity,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                      child: AppIcon(
                        AppIcons.sparkle,
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
                      assistantName == null
                          ? 'Ask Hermes Agent about your server, your codebase, or '
                                'anything it has tools for.'
                          : 'Start a conversation with $assistantName. Your Bot Chat stays available whenever you return.',
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
                                text: prompt.label,
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
          ),
        ),
      ),
    );
  }
}

const double _cardWidth = 290;

AppIconSet _icon(StarterSource source) => switch (source) {
  StarterSource.generic => AppIcons.idea,
  StarterSource.schedule => AppIcons.schedule,
  StarterSource.kanban => AppIcons.kanban,
  StarterSource.chat => AppIcons.chat,
  StarterSource.skill => AppIcons.extension,
};

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.text,
    required this.icon,
    required this.width,
    required this.onTap,
  });

  final String text;
  final AppIconSet icon;
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
                AppIcon(icon, size: 16, color: context.hermesColors.subtleText),
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
