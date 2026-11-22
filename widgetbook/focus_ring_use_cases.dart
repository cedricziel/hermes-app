import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/widgets/attach_menu.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_confirmation_layout.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:hermes_app/src/chat/widgets/scroll_to_latest_button.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/kanban/widgets/new_task_fab.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/platform_hint/platform_hint_repository.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/widgets/adaptive_segmented_control.dart';
import 'package:hermes_app/src/widgets/composer_selector_chip.dart';
import 'package:hermes_app/src/widgets/disclosure_tile.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ComposerHeightNotifier;
import 'package:provider/provider.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';
import 'package:hermes_app/src/plugins/catalog_tab.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:hermes_app/src/plugins/widgets/catalog_row.dart';
import 'package:hermes_app/src/skills/widgets/curator_run_confirmation.dart';
import 'package:hermes_app/src/skills/widgets/installed_skills_list.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/voice/widgets/hands_free_strip.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_toolbar_button.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// Shows [child] as it looks when the keyboard has moved focus to its
/// [focusIndex]-th focusable control, or to its [button]-th button: the
/// highlight mode is forced to traditional, as it is after a Tab press, and
/// put back when the use case goes away. With neither, every control is at
/// rest. A [button] that finds no button in [child] falls back to its first
/// focusable control, for a platform that draws a tappable row there. [hover] puts a mouse over the child first, for controls a row shows
/// only while hovered.
class _KeyboardFocus extends StatefulWidget {
  const _KeyboardFocus({
    this.focusIndex,
    this.button,
    this.hover = false,
    this.where,
    required this.child,
  });

  final int? focusIndex;
  final int? button;
  final bool hover;

  /// Narrows the focusable controls that [focusIndex] counts to the ones this
  /// accepts, for a child whose first controls are not the one to show.
  final bool Function(FocusNode node)? where;
  final Widget child;

  @override
  State<_KeyboardFocus> createState() => _KeyboardFocusState();
}

class _KeyboardFocusState extends State<_KeyboardFocus> {
  /// How many of these are mounted. The next use case builds before the last
  /// one is disposed, so the strategy goes back only when none is left.
  static var _live = 0;

  /// Each hover preview is its own mouse device, so a second one never adds
  /// a device the first still holds; `dispose` removes it again.
  static var _devices = 0;
  final _device = ++_devices;
  Offset? _hoverAt;

  @override
  void initState() {
    super.initState();
    _live++;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.hover) {
        final box = context.findRenderObject()! as RenderBox;
        final at = box.localToGlobal(box.size.center(Offset.zero));
        _hoverAt = at;
        GestureBinding.instance
          ..handlePointerEvent(
            PointerAddedEvent(
              position: at,
              kind: PointerDeviceKind.mouse,
              device: _device,
            ),
          )
          ..handlePointerEvent(
            PointerHoverEvent(
              position: at,
              kind: PointerDeviceKind.mouse,
              device: _device,
            ),
          );
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      var nodes = FocusScope.of(context).traversalDescendants.toList();
      final where = widget.where;
      if (where != null) nodes = nodes.where(where).toList();
      // A click on an earlier example must not hide this one's ring.
      if (widget.button != null || widget.focusIndex != null) {
        markFocusRingKeyboardInput();
      }
      var button = widget.button;
      if (button != null) {
        final buttons = [
          for (final n in nodes)
            if (_insideButton(n)) n,
        ];
        // A platform may draw a tappable row where another draws a button:
        // "Check for updates" (iPhone, Material) and "Messaging Set up"
        // (iPhone). The first focusable control takes the focus then.
        if (buttons.isEmpty) {
          button = 0;
        } else {
          nodes = buttons;
        }
      }
      final index = button ?? widget.focusIndex;
      if (index != null && index < nodes.length) nodes[index].requestFocus();
    });
  }

  @override
  void dispose() {
    final at = _hoverAt;
    if (at != null) {
      GestureBinding.instance.handlePointerEvent(
        PointerRemovedEvent(
          position: at,
          kind: PointerDeviceKind.mouse,
          device: _device,
        ),
      );
    }
    if (--_live == 0) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Whether [node] belongs to a Material button (they all extend
/// [ButtonStyleButton], so an exact-type lookup would find none).
bool _insideButton(FocusNode node) {
  var inside = false;
  node.context?.visitAncestorElements((element) {
    inside = element.widget is ButtonStyleButton;
    return !inside;
  });
  return inside;
}

void _noop() {}

Widget _buttons() => Wrap(
  spacing: 16,
  runSpacing: 16,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    FilledButton(onPressed: _noop, child: const Text('Filled')),
    OutlinedButton(onPressed: _noop, child: const Text('Outlined')),
    TextButton(onPressed: _noop, child: const Text('Text')),
    IconButton(onPressed: _noop, tooltip: 'Add', icon: const Icon(Icons.add)),
  ],
);

Widget _rows() => const GroupedSection(
  header: 'Messaging',
  children: [
    GroupedRow(title: 'Telegram', value: 'Set up', onTap: _noop),
    GroupedRow(title: 'Discord', value: 'Off', onTap: _noop),
    GroupedRow(title: 'Slack', value: 'Off', onTap: _noop),
  ],
);

/// A real menu, opened under the host and with its second item focused, since
/// a menu item only builds inside a menu route.
class _OpenMenu extends StatefulWidget {
  const _OpenMenu();

  @override
  State<_OpenMenu> createState() => _OpenMenuState();
}

class _OpenMenuState extends State<_OpenMenu> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final menu = showMenu<int>(
        context: context,
        position: const RelativeRect.fromLTRB(16, 16, 0, 0),
        items: const [
          FocusRingMenuItem<int>(value: 1, child: Text('Rename')),
          FocusRingMenuItem<int>(value: 2, child: Text('Duplicate')),
          FocusRingMenuItem<int>(value: 3, child: Text('Archive')),
        ],
      );
      await WidgetsBinding.instance.endOfFrame;
      final items = FocusManager.instance.rootScope.traversalDescendants
          .where(
            (n) =>
                n.context
                    ?.findAncestorWidgetOfExactType<FocusRingMenuItem<int>>() !=
                null,
          )
          .toList();
      if (items.length > 1) {
        // A click on an earlier example must not hide this one's ring.
        markFocusRingKeyboardInput();
        items[1].requestFocus();
      }
      await menu;
    });
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 200, child: Text('The menu opens at the corner.'));
}

/// A real [AdaptivePopupMenuButton] menu of checked items, opened at its
/// button with the second item focused (an item only builds in a menu route).
class _OpenCheckedMenu extends StatefulWidget {
  const _OpenCheckedMenu();

  @override
  State<_OpenCheckedMenu> createState() => _OpenCheckedMenuState();
}

class _OpenCheckedMenuState extends State<_OpenCheckedMenu> {
  final _menu = AdaptiveMenuController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _menu.open();
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final items = FocusManager.instance.rootScope.traversalDescendants
          .where(
            (n) =>
                n.context
                    ?.findAncestorWidgetOfExactType<
                      CheckedPopupMenuItem<int>
                    >() !=
                null,
          )
          .toList();
      if (items.length > 1) {
        // A click on an earlier example must not hide this one's ring.
        markFocusRingKeyboardInput();
        items[1].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: Align(
      alignment: Alignment.topLeft,
      child: AdaptivePopupMenuButton<int>(
        controller: _menu,
        tooltip: 'Sort',
        icon: const Icon(Icons.sort),
        onSelected: (_) {},
        itemBuilder: (_) => const [
          CheckedPopupMenuItem<int>(
            value: 1,
            checked: true,
            child: Text('Newest first'),
          ),
          CheckedPopupMenuItem<int>(
            value: 2,
            checked: false,
            child: Text('Oldest first'),
          ),
          CheckedPopupMenuItem<int>(
            value: 3,
            checked: false,
            child: Text('Name'),
          ),
        ],
      ),
    ),
  );
}

Widget _chips() => Wrap(
  spacing: 16,
  runSpacing: 16,
  children: [
    FilterChip(
      label: const Text('Archived'),
      selected: true,
      onSelected: (_) {},
    ),
    ChoiceChip(
      label: const Text('Running 3'),
      selected: false,
      onSelected: (_) {},
    ),
  ],
);

const _recipients = [
  HermesProfile(name: 'writer', displayName: 'Writer'),
  HermesProfile(name: 'research', displayName: 'Research'),
];

/// The Material controls the ring was wired into after the buttons: checked
/// menu items, the tiles of a list, and chips.
List<WidgetbookUseCase> _menuTileChipUseCases() => [
  WidgetbookUseCase(
    name: 'Checked menu item',
    builder: (_) => _at(null, const _OpenCheckedMenu()),
  ),
  WidgetbookUseCase(
    name: 'List tile (attach menu)',
    builder: (_) => _at(
      1,
      const Card(
        child: AttachMenu(origins: AttachOrigin.values, onPick: _ignoreOrigin),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'List tile, selected (recipient picker)',
    builder: (_) => _at(
      1,
      RecipientPicker(
        profiles: _recipients,
        selectedProfile: 'writer',
        onSelected: (_) {},
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Switch list tile (take over)',
    builder: (_) => _at(
      0,
      Card(
        child: TakeoverConfirmation(onCancel: () {}, onConfirm: (_) {}),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Checkbox list tile (platform hint)',
    builder: (_) => _at(
      1,
      Card(
        margin: EdgeInsets.zero,
        child: PlatformHintPrompt(
          profiles: const ['default', 'work'],
          text: appPlatformHint,
          selected: const {'default'},
          onToggle: (_, _) {},
          onAdd: () {},
          onLater: () {},
          onNever: () {},
        ),
      ),
    ),
  ),
  WidgetbookUseCase(name: 'Filter chip', builder: (_) => _at(0, _chips())),
  WidgetbookUseCase(name: 'Choice chip', builder: (_) => _at(1, _chips())),
];

void _ignoreOrigin(AttachOrigin _) {}

Widget _segments() => PillSegmentedControl<int>(
  value: 0,
  segments: const {0: 'Chats', 1: 'Files', 2: 'Tasks'},
  onChanged: (_) {},
);

Widget _at(int? index, Widget child) =>
    frame(_KeyboardFocus(focusIndex: index, child: child));

Widget _buttonAt(int n, Widget child) =>
    frame(_KeyboardFocus(button: n, child: child));

Widget _mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: child,
  ),
);

Widget _settingsFormAction() => SizedBox(
  height: 320,
  child: _KeyboardFocus(
    button: 0,
    child: SettingsScaffold(
      title: 'New task',
      subtitle: 'work',
      previousTitle: null,
      formAction: SettingsFormAction(label: 'Save', onPressed: () {}),
      body: ListView(children: const [ListTile(title: Text('Name'))]),
    ),
  ),
);

const _curator = CuratorRunConfirmationModel(
  staleAfterDays: 30,
  archiveAfterDays: 90,
  pruneBuiltins: true,
  consolidate: true,
);

/// The own-shape buttons that the ring was wired into after the theme's: each
/// takes the ring through `focusRingShapeOf`.
List<WidgetbookUseCase> _ownShapeUseCases() => [
  WidgetbookUseCase(
    name: 'Destructive tint button',
    builder: (_) => _buttonAt(
      0,
      DestructiveTintButton(label: 'Stop process', onPressed: () {}),
    ),
  ),
  WidgetbookUseCase(
    name: 'Settings form action (Mac Save)',
    builder: (_) => _mac(_settingsFormAction()),
  ),
  WidgetbookUseCase(
    name: 'Restore confirmation Cancel',
    builder: (_) => _buttonAt(
      0,
      RestoreConfirmationLayout(
        title: 'Restore this file?',
        body: const Text('The file goes back to how it was 12 minutes ago.'),
        cancelLabel: 'Cancel',
        confirmLabel: 'Restore',
        onCancel: () {},
        onConfirm: () {},
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Catalog detail Install',
    builder: (_) =>
        _buttonAt(0, InstallActions(installing: false, onInstall: (_) {})),
  ),
  ...onEachPlatform(
    'Catalog row Install',
    (_) => _buttonAt(0, InstallButton(installing: false, onPressed: () {})),
  ),
  WidgetbookUseCase(
    name: 'Curator confirmation Cancel',
    builder: (_) => _buttonAt(
      0,
      CuratorRunConfirmation(model: _curator, onCancel: () {}, onRun: () {}),
    ),
  ),
  WidgetbookUseCase(
    name: 'Curator confirmation Run',
    builder: (_) => _buttonAt(
      1,
      CuratorRunConfirmation(model: _curator, onCancel: () {}, onRun: () {}),
    ),
  ),
  ...onEachPlatform(
    'Check for updates',
    (_) => _buttonAt(0, SkillUpdatesSection(onPressed: () {})),
  ),
  WidgetbookUseCase(
    name: 'Hands-free strip End',
    builder: (_) => _buttonAt(
      0,
      HandsFreeStrip(microphone: HandsFreeMicrophone.open, onEnd: () {}),
    ),
  ),
  ...onEachPlatform(
    'Folder toolbar button',
    (_) => _buttonAt(
      0,
      FolderToolbarButton(
        folderName: 'hermes-app',
        path: '~/dev/hermes-app',
        branch: 'main',
        onPressed: () {},
      ),
    ),
  ),
  for (final (name, n) in [('Archive', 0), ('More', 1)])
    WidgetbookUseCase(
      name: 'Mac thread row $name (20 pt)',
      builder: (_) => _mac(
        frame(
          _KeyboardFocus(
            button: n,
            hover: true,
            child: SizedBox(
              width: 260,
              child: MacThreadRow(
                title: 'Plan the release',
                selected: false,
                onTap: () {},
                onArchive: () {},
                menuItems: (context) => macThreadMenuItems(
                  context.l10n,
                  pinned: false,
                  manageable: true,
                ),
                onAction: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  ...onEachPlatform(
    'Messaging Set up',
    (_) => _buttonAt(
      0,
      GroupedSection(
        children: [
          MessagingPlatformRow(
            platform: const HermesMessagingPlatform(
              id: 'whatsapp',
              name: 'WhatsApp',
            ),
            onSetUp: () {},
            onToggle: (_) {},
          ),
        ],
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Mac toolbar button',
    builder: (_) => _mac(
      _buttonAt(
        0,
        MacToolbarButton(
          label: 'New Task',
          shortcut: '⌘N',
          icon: AppIcons.add,
          onPressed: () {},
        ),
      ),
    ),
  ),
];

Widget _on(TargetPlatform platform, Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: platform),
    child: child,
  ),
);

/// A menu of plain rows opened under its button on a Mac, with the second row
/// focused (the Mac compact menu: every row is a [MacMenuRow]).
class _OpenMacRows extends StatefulWidget {
  const _OpenMacRows();

  @override
  State<_OpenMacRows> createState() => _OpenMacRowsState();
}

class _OpenMacRowsState extends State<_OpenMacRows> {
  final _menu = AdaptiveMenuController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _menu.open();
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final items = FocusManager.instance.rootScope.traversalDescendants
          .where(
            (n) =>
                n.context
                    ?.findAncestorWidgetOfExactType<PopupMenuItem<int>>() !=
                null,
          )
          .toList();
      if (items.length > 1) {
        markFocusRingKeyboardInput();
        items[1].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: Align(
      alignment: Alignment.topLeft,
      child: AdaptivePopupMenuButton<int>(
        controller: _menu,
        tooltip: 'More',
        icon: const Icon(Icons.more_horiz),
        onSelected: (_) {},
        itemBuilder: (_) => [
          const AdaptiveMenuItem<int>(value: 1, child: Text('Rename')),
          const AdaptiveMenuItem<int>(
            value: 2,
            shortcut: '⌘D',
            child: Text('Duplicate'),
          ),
          const AdaptiveMenuItem<int>(
            value: 3,
            destructive: true,
            child: Text('Delete'),
          ),
        ],
      ),
    ),
  );
}

/// The Mac right-click menu of a list row ([RowActions]): a secondary press
/// opens it, then its second item is focused.
class _OpenRowContextMenu extends StatefulWidget {
  const _OpenRowContextMenu();

  @override
  State<_OpenRowContextMenu> createState() => _OpenRowContextMenuState();
}

class _OpenRowContextMenuState extends State<_OpenRowContextMenu> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final box = context.findRenderObject()! as RenderBox;
      final at = box.localToGlobal(const Offset(80, 24));
      GestureBinding.instance
        ..handlePointerEvent(
          PointerDownEvent(
            position: at,
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        )
        ..handlePointerEvent(
          PointerUpEvent(position: at, kind: PointerDeviceKind.mouse),
        );
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final items = FocusManager.instance.rootScope.traversalDescendants
          .where(
            (n) =>
                n.context
                    ?.findAncestorWidgetOfExactType<
                      FocusRingMenuItem<RowAction>
                    >() !=
                null,
          )
          .toList();
      if (items.length > 1) {
        markFocusRingKeyboardInput();
        items[1].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: RowActions(
      title: 'Daily summary',
      actions: [
        RowAction(label: 'Run now', icon: AppIcons.play, onPressed: () {}),
        RowAction(label: 'Pause', icon: AppIcons.pause, onPressed: () {}),
        RowAction(
          label: 'Delete',
          icon: AppIcons.delete,
          destructive: true,
          onPressed: () {},
        ),
      ],
      child: const ListTile(title: Text('Daily summary')),
    ),
  );
}

Widget _disclosure({bool open = false}) => Card(
  margin: EdgeInsets.zero,
  child: DisclosureTile(
    initiallyExpanded: open,
    title: const Text('Tool output'),
    children: const [
      Padding(padding: EdgeInsets.all(16), child: Text('3 files changed')),
    ],
  ),
);

Widget _weekdays() => StatefulBuilder(
  builder: (context, setState) => SchedulePicker(
    spec: const WeeklySpec({1, 2, 3, 4, 5}, 9, 0),
    now: DateTime(2026, 11, 22),
    onChanged: (_) {},
  ),
);

/// Whether [node] sits in a weekday toggle of the schedule picker, the only
/// controls there that a screen reader reads as toggled.
bool _inWeekdayToggle(FocusNode node) {
  var found = false;
  node.context?.visitAncestorElements((e) {
    final w = e.widget;
    found = w is Semantics && w.properties.toggled != null;
    return !found;
  });
  return found;
}

/// The controls that took the ring after the first pass: segmented controls,
/// hand-rolled tap targets, floating buttons, disclosure tiles and the Mac
/// menus.
List<WidgetbookUseCase> _remainingControlUseCases() => [
  WidgetbookUseCase(
    name: 'Segmented control (Material)',
    builder: (_) => _on(
      TargetPlatform.android,
      _at(
        1,
        AdaptiveSegmentedControl<int>(
          value: 0,
          segments: const {0: 'Chats', 1: 'Files', 2: 'Tasks'},
          onChanged: (_) {},
          semanticLabel: 'View',
        ),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Segmented control (iPhone)',
    builder: (_) => _on(
      TargetPlatform.iOS,
      _at(
        1,
        AdaptiveSegmentedControl<int>(
          value: 0,
          segments: const {0: 'Chats', 1: 'Files', 2: 'Tasks'},
          onChanged: (_) {},
          semanticLabel: 'View',
        ),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Model pill',
    builder: (_) => _at(
      0,
      ComposerSelectorChip(
        label: 'claude-sonnet · high',
        trailing: const Icon(Icons.expand_more, size: 16),
        onPressed: () {},
      ),
    ),
  ),
  ...onEachPlatform(
    'Weekday toggle',
    (_) => frame(
      _KeyboardFocus(
        focusIndex: 1,
        where: _inWeekdayToggle,
        child: _weekdays(),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'New chat button',
    builder: (_) => _on(
      TargetPlatform.android,
      _buttonAt(
        0,
        Padding(
          padding: const EdgeInsets.all(8),
          child: NewChatFab(onPressed: () {}),
        ),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Scroll to latest button',
    builder: (_) => _on(
      TargetPlatform.android,
      ChangeNotifierProvider(
        create: (_) => ComposerHeightNotifier(),
        child: _at(
          0,
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                ScrollToLatestButton(
                  animation: const AlwaysStoppedAnimation(1),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Extended button (New task)',
    builder: (_) => _on(
      TargetPlatform.android,
      _buttonAt(
        0,
        Padding(
          padding: const EdgeInsets.all(8),
          child: const NewTaskFab(onPressed: _noop),
        ),
      ),
    ),
  ),
  WidgetbookUseCase(
    name: 'Disclosure tile (closed)',
    builder: (_) => _at(0, _disclosure()),
  ),
  WidgetbookUseCase(
    name: 'Disclosure tile (open)',
    builder: (_) => _at(0, _disclosure(open: true)),
  ),
  WidgetbookUseCase(
    name: 'Mac menu row',
    builder: (_) => _on(TargetPlatform.macOS, _at(null, const _OpenMacRows())),
  ),
  WidgetbookUseCase(
    name: 'Mac checked menu item',
    builder: (_) =>
        _on(TargetPlatform.macOS, _at(null, const _OpenCheckedMenu())),
  ),
  WidgetbookUseCase(
    name: 'Mac row context menu',
    builder: (_) =>
        _on(TargetPlatform.macOS, _at(null, const _OpenRowContextMenu())),
  ),
];

/// The keyboard focus ring: 2 px in the link colour, 2 px outside a button
/// (its radius plus 2), 2 px inside a list row, menu item or segment that a
/// container clips. It shows only after the keyboard moved focus, never after
/// a pointer press; a text field keeps its own focus border. Each use case
/// forces keyboard mode and focuses one control; "Resting" is the same
/// controls with nothing focused, and "Try it" is for pressing Tab.
WidgetbookNode focusRingNode() => WidgetbookComponent(
  name: 'Keyboard focus ring',
  useCases: [
    WidgetbookUseCase(name: 'Resting', builder: (_) => _at(null, _buttons())),
    WidgetbookUseCase(
      name: 'Filled button',
      builder: (_) => _at(0, _buttons()),
    ),
    WidgetbookUseCase(
      name: 'Outlined button',
      builder: (_) => _at(1, _buttons()),
    ),
    WidgetbookUseCase(name: 'Text button', builder: (_) => _at(2, _buttons())),
    WidgetbookUseCase(name: 'Icon button', builder: (_) => _at(3, _buttons())),
    WidgetbookUseCase(name: 'Grouped row', builder: (_) => _at(1, _rows())),
    WidgetbookUseCase(
      name: 'Menu item',
      builder: (_) => _at(null, const _OpenMenu()),
    ),
    WidgetbookUseCase(name: 'Segment', builder: (_) => _at(1, _segments())),
    WidgetbookUseCase(
      name: 'Text field (own border)',
      builder: (_) => _at(
        0,
        const TextField(decoration: InputDecoration(labelText: 'Name')),
      ),
    ),
    ..._menuTileChipUseCases(),
    ..._ownShapeUseCases(),
    ..._remainingControlUseCases(),
    WidgetbookUseCase(
      name: 'Try it (press Tab)',
      builder: (_) => _at(
        null,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buttons(), const SizedBox(height: 16), _rows()],
        ),
      ),
    ),
  ],
);
