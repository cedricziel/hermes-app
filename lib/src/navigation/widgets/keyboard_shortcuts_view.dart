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
  Widget build(BuildContext context) {
    // From 1.3x text the key caps sit on a line of their own, where they can
    // wrap, instead of squeezing the name of the command.
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.3;
    return GroupedListView(
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
                  separateTrailing: stacked,
                  trailingBelow: stacked,
                  trailing: ChordKeys(
                    chords: row.chords,
                    alignment: stacked
                        ? WrapAlignment.start
                        : WrapAlignment.end,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
