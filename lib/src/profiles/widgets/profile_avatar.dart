import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../hermes_profiles_repository.dart';
import '../profile_avatar_repository.dart';

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
  const InitialsAvatar({
    super.key,
    required this.label,
    this.identity,
    this.size = 24,
  });

  final String label;
  final String? identity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.surfaceContainerHighest, scheme.onSurface),
    ];
    final hash = (identity ?? label).codeUnits.fold(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    final (background, foreground) = palette[hash % palette.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: background),
        child: Text(
          initialsOf(label),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// One recipient's accessible identity, with configured imagery when available.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.repository,
    this.imageBytes,
    this.size = 40,
  });

  final HermesProfile profile;
  final ProfileAvatarRepository? repository;
  final Uint8List? imageBytes;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.repository?.addListener(_invalidated);
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository?.removeListener(_invalidated);
      widget.repository?.addListener(_invalidated);
    }
    if (oldWidget.profile.name != widget.profile.name ||
        oldWidget.repository != widget.repository ||
        oldWidget.imageBytes != widget.imageBytes) {
      _load();
    }
  }

  void _invalidated() => setState(_load);

  void _load() {
    final generation = ++_generation;
    _bytes = widget.imageBytes;
    if (_bytes != null) return;
    widget.repository?.load(widget.profile.name).then((bytes) {
      if (!mounted || generation != _generation) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  void dispose() {
    widget.repository?.removeListener(_invalidated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = InitialsAvatar(
      label: widget.profile.label,
      identity: widget.profile.name,
      size: widget.size,
    );
    return Semantics(
      label: widget.profile.label,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: _bytes == null
              ? fallback
              : ClipOval(
                  child: Image.memory(
                    _bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: false,
                    errorBuilder: (_, _, _) => fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Distinguishes a group from a single profile without implying membership.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.label, this.size = 40});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label, group',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(size * .28),
          ),
          child: Icon(
            Icons.group_outlined,
            size: size * .6,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
