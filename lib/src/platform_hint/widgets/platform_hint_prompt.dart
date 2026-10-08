import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/disclosure_tile.dart';

/// Asks whether to add the app's note to Hermes, which tells the agent this
/// app renders formatting and files. It names the profiles the note goes to
/// and can show the exact text. With several profiles each is a checkbox,
/// and only the [selected] ones are saved. While [busy] the controls are off;
/// profiles in [failed] could not be saved and [onAdd] retries them.
class PlatformHintPrompt extends StatelessWidget {
  const PlatformHintPrompt({
    super.key,
    required this.profiles,
    required this.selected,
    required this.onToggle,
    required this.text,
    required this.onAdd,
    required this.onLater,
    required this.onNever,
    this.update = false,
    this.busy = false,
    this.failed = const [],
    this.saved = const {},
  });

  /// The profiles the note would be written to.
  final List<String> profiles;

  /// The note, shown on request.
  final String text;

  /// The profiles ticked to receive it.
  final Set<String> selected;

  /// Ticks or unticks a profile.
  final void Function(String profile, bool selected) onToggle;

  /// Every profile holds an older note this app wrote.
  final bool update;
  final bool busy;
  final List<String> failed;

  /// Profiles already saved by an earlier try; they stay ticked and locked.
  final Set<String> saved;
  final VoidCallback onAdd;
  final VoidCallback onLater;
  final VoidCallback onNever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final many = profiles.length > 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcon(
                AppIcons.sparkle,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              update
                  ? 'Update the note Hermes has about this app?'
                  : 'Tell Hermes about this app?',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            update
                ? 'This version of the app has a better description of what '
                      'your chats can show. It replaces the note the app '
                      'added before.'
                : "Hermes doesn't know what this app can show, so it may "
                      'avoid formatting and never send you files. A short '
                      'note in your server settings fixes that.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            many
                ? 'Choose the profiles on your server that get it:'
                : 'Saved to the “${profiles.single}” profile on your server.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (many) ...[
            const SizedBox(height: 8),
            _ProfileChecklist(
              profiles: profiles,
              selected: selected,
              failed: failed,
              saved: saved,
              onToggle: busy ? null : onToggle,
            ),
          ],
          const SizedBox(height: 8),
          DisclosureTile(
            title: const Text('Show the note'),
            dense: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            children: [_Note(text)],
          ),
          if (failed.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Failure(failed, all: failed.length == profiles.length),
          ],
          const SizedBox(height: 16),
          _Actions(
            busy: busy,
            addLabel: _addLabel,
            onAdd: selected.isEmpty ? null : onAdd,
            onLater: onLater,
            onNever: onNever,
          ),
        ],
      ),
    );
  }

  String get _addLabel {
    if (failed.isNotEmpty) return 'Try again';
    final count = selected.length;
    if (profiles.length == 1 || count == 0) {
      return update ? 'Update note' : 'Add note';
    }
    final noun = count == 1 ? 'profile' : 'profiles';
    return update ? 'Update $count $noun' : 'Add to $count $noun';
  }
}

/// A row ending in the main button on a wide layout; on a narrow one the
/// buttons stack at full width with the main one on top, within thumb reach.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.busy,
    required this.addLabel,
    required this.onAdd,
    required this.onLater,
    required this.onNever,
  });

  final bool busy;
  final String addLabel;
  final VoidCallback? onAdd;
  final VoidCallback onLater;
  final VoidCallback onNever;

  @override
  Widget build(BuildContext context) {
    final add = FilledButton(
      key: const ValueKey('platform-hint-add'),
      onPressed: busy ? null : onAdd,
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(addLabel),
    );
    final later = TextButton(
      key: const ValueKey('platform-hint-later'),
      onPressed: busy ? null : onLater,
      child: const Text('Not now'),
    );
    final never = TextButton(
      key: const ValueKey('platform-hint-never'),
      onPressed: busy ? null : onNever,
      child: const Text("Don't ask again", overflow: TextOverflow.ellipsis),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: [
              Flexible(child: never),
              const Spacer(),
              later,
              const SizedBox(width: 8),
              add,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [add, const SizedBox(height: 4), later, never],
        );
      },
    );
  }
}

/// One checkbox row per profile, grouped in a card so the ticked state reads
/// at a glance; a profile that failed says so under its name.
class _ProfileChecklist extends StatelessWidget {
  const _ProfileChecklist({
    required this.profiles,
    required this.selected,
    required this.failed,
    required this.saved,
    required this.onToggle,
  });

  final List<String> profiles;
  final Set<String> selected;
  final List<String> failed;
  final Set<String> saved;
  final void Function(String profile, bool selected)? onToggle;

  Widget? _status(String profile, ColorScheme scheme) {
    if (failed.contains(profile)) {
      return Text("Couldn't save", style: TextStyle(color: scheme.error));
    }
    if (saved.contains(profile)) return const Text('Saved');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (i, profile) in profiles.indexed) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            CheckboxListTile.adaptive(
              key: ValueKey('platform-hint-profile-$profile'),
              value: saved.contains(profile) || selected.contains(profile),
              onChanged: onToggle == null || saved.contains(profile)
                  ? null
                  : (value) => onToggle!(profile, value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(profile),
              subtitle: _status(profile, scheme),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(text, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          Text(
            'Stored as platform_hints.hermes_app in the profile config. New '
            'chats use it; you can edit or remove it there.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure(this.profiles, {required this.all});

  final List<String> profiles;
  final bool all;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(AppIcons.warning, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                all
                    ? "Couldn't save the note. Check the connection and try again."
                    : "Couldn't save to ${profiles.join(', ')}. The others are done.",
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
