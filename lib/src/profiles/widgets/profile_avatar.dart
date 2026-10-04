import 'package:flutter/material.dart';

/// The first letters of up to two words of [label], upper case; "?" when it
/// has none.
String initialsOf(String label) {
  final words = label
      .split(RegExp(r'[\s_\-.@/:]+'))
      .where((w) => w.isNotEmpty)
      .take(2);
  final letters = words.map((w) => w.characters.first.toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

/// A round avatar with the initials of [label].
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.label, this.size = 24});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest,
        ),
        child: Text(
          initialsOf(label),
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
