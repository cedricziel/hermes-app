import 'package:flutter_test/flutter_test.dart' show Finder, find;
import 'package:flutter/material.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:provider/provider.dart';

/// A caller of [AdaptivePopupMenuButton] that passes its own `child` (F.441),
/// as the app builds it.
class PopupCaller {
  const PopupCaller(
    this.name,
    this.build,
    this.text,
    this.popup,
    this.child, {
    this.chip = false,
  });

  final String name;
  final Widget Function() build;

  /// The caller's own [AdaptivePopupMenuButton], one of the page's.
  final Finder popup;

  /// The widget the caller passes as the `child` of the button.
  final Finder child;

  /// What the trigger's child says, and so what a screen reader reads.
  final String text;

  /// The Kanban filter chip, whose box differs from what it paints.
  final bool chip;
}

void _ignore(Object? _) {}

final _popup = find.byWidgetPredicate((w) => w is AdaptivePopupMenuButton);

Finder _within(Type type) =>
    find.descendant(of: find.byType(type).first, matching: _popup).first;

final popupCallers = <PopupCaller>[
  PopupCaller(
    'log level pill',
    () => const LogLevelMenuButton(
      value: LogLevelFilter.warnings,
      onChanged: _ignore,
    ),
    'Warnings and errors',
    _within(LogLevelMenuButton),
    find
        .descendant(
          of: find.descendant(
            of: _within(LogLevelMenuButton),
            matching: find.byType(ExcludeSemantics),
          ),
          matching: find.byType(ConstrainedBox),
        )
        .first,
  ),
  PopupCaller(
    'settings subtitle menu',
    () => SizedBox(
      width: 390,
      height: 300,
      child: SettingsScaffold(
        title: 'Server logs',
        subtitle: 'work profile',
        subtitleMenu: SettingsSubtitleMenu<String>(
          label: 'Profile',
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'work', child: Text('work')),
            PopupMenuItem(value: 'home', child: Text('home')),
          ],
          onSelected: _ignore,
        ),
        body: const SizedBox.shrink(),
      ),
    ),
    'Profile',
    find.byKey(const Key('settings-subtitle-menu')),
    find
        .descendant(
          of: find.byKey(const Key('settings-subtitle-menu')),
          matching: find.byType(Row),
        )
        .first,
  ),
  PopupCaller(
    'grouped value row',
    () => SizedBox(
      width: 390,
      child: GroupedSection(
        children: [
          GroupedMenuRow<String>(
            title: 'Provider',
            options: const ['anthropic', 'openrouter'],
            labelOf: (o) => o,
            selected: 'anthropic',
            onSelected: _ignore,
          ),
          GroupedMenuRow<String>(
            title: 'Effort',
            options: const ['low', 'high'],
            labelOf: (o) => o,
            selected: 'high',
            onSelected: _ignore,
          ),
        ],
      ),
    ),
    'Provider',
    _within(GroupedMenuRow<String>),
    find.byType(GroupedValueRow).first,
  ),
  PopupCaller(
    'kanban filter chip',
    // In the toolbar's horizontal scroll view, as the app builds it.
    () => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          KanbanFilterMenu(
            label: 'All assignees',
            all: 'All assignees',
            options: const ['ada', 'grace'],
            onSelected: _ignore,
          ),
        ],
      ),
    ),
    'All assignees',
    _within(KanbanFilterMenu),
    find.byType(Chip),
    chip: true,
  ),
  PopupCaller(
    'account footer',
    () => ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: const SizedBox(width: 300, child: AccountFooter()),
    ),
    'Not connected',
    _within(AccountFooter),
    find
        .descendant(of: _within(AccountFooter), matching: find.byType(Padding))
        .first,
  ),
];
