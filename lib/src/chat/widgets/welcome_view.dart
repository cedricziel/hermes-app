import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../mock_chat_data.dart';

/// Empty-thread state — a centered greeting plus a grid of starter prompts,
/// the same shape as assistant-ui's default `<ThreadWelcome />`.
class WelcomeView extends StatelessWidget {
  const WelcomeView({
    super.key,
    required this.greetingName,
    required this.onPick,
  });

  final String? greetingName;
  final ValueChanged<String> onPick;

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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final prompt in kStarterPrompts)
                    _SuggestionCard(text: prompt, onTap: () => onPick(prompt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 290,
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
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
