import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/settings_scaffold.dart';
import '../keyboard_shortcut_models.dart';
import 'chord_keys.dart';

/// The "Keyboard shortcuts" page: a read-only list of commands and the keys
/// that run them, one section per menu.
class KeyboardShortcutsPage extends StatelessWidget {
  const KeyboardShortcutsPage({super.key, required this.sections});

  final List<ShortcutSectionModel> sections;

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: context.l10n.navigationKeyboardShortcutsTitle,
    body: KeyboardShortcutsView(sections: sections),
  );
}

/// The list of [KeyboardShortcutsPage] without its bar.
class KeyboardShortcutsView extends StatelessWidget {
  const KeyboardShortcutsView({super.key, required this.sections});

  final List<ShortcutSectionModel> sections;

  @override
  Widget build(BuildContext context) => GroupedListView(
    children: [
      for (final section in sections)
        GroupedSection(
          header: section.title,
          children: [
            for (final row in section.rows)
              GroupedRow(
                title: row.label,
                titleMaxLines: null,
                focusable: false,
                trailing: ChordKeys(chords: row.chords),
              ),
          ],
        ),
    ],
  );
}
