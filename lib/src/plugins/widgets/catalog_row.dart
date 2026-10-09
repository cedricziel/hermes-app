import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../catalog_entry.dart';

/// A catalog entry in the grouped list: its name, "Official" beside it, who
/// maintains it and what it does, and either where it stands ("Installed",
/// "Update available") or a small Install button.
class CatalogRow extends StatelessWidget {
  const CatalogRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onInstall,
    this.installing = false,
    this.selected = false,
  });

  final CatalogEntry entry;
  final VoidCallback onTap;
  final VoidCallback onInstall;
  final bool installing;

  /// The entry whose details show beside the list.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (entry.maintainer.isNotEmpty) entry.maintainer,
      if (entry.description.isNotEmpty) entry.description,
    ].join(' · ');
    return GroupedRow(
      key: ValueKey('catalog-row-${entry.name}'),
      title: entry.name,
      meta: entry.official ? 'Official' : null,
      subtitle: subtitle.isEmpty ? null : subtitle,
      value: !entry.installed
          ? null
          : entry.updateAvailable
          ? 'Update available'
          : 'Installed',
      trailing: entry.installed
          ? null
          : InstallButton(
              key: Key('catalog-install-${entry.name}'),
              installing: installing,
              onPressed: onInstall,
            ),
      chevron: entry.installed && platformChromeOf(context).isApple,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// A row's small Install (or [label]) button: a tinted pill on iOS, a
/// bordered push button on macOS, an outlined pill on Material. It spins
/// while [installing].
class InstallButton extends StatelessWidget {
  const InstallButton({
    super.key,
    required this.installing,
    required this.onPressed,
    this.label = 'Install',
  });

  final bool installing;
  final VoidCallback onPressed;

  /// What the button does, such as "Add".
  final String label;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final mac = chrome == PlatformChrome.macos;
    final label = installing
        ? SizedBox.square(
            dimension: mac ? 12 : 16,
            child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : Text(this.label);
    final onPressed = installing ? null : this.onPressed;
    final text = Theme.of(context).textTheme.labelLarge;
    if (chrome == PlatformChrome.ios) {
      return FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
          textStyle: text?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: label,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, mac ? 22 : 32),
        padding: mac
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: mac ? VisualDensity.compact : null,
        shape: mac
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
            : const StadiumBorder(),
        textStyle: text?.copyWith(
          fontSize: mac ? 12 : 14,
          fontWeight: mac ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      child: label,
    );
  }
}
