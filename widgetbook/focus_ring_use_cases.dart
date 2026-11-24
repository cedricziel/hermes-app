import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_line_model.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_state.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/file_checkpoints_row.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/context_state.dart';
import 'package:hermes_app/src/chat/context/widgets/context_format.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_row.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_json_tree.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_advanced_row.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/widgets/attach_menu.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_confirmation_layout.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/sidebar_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
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
import 'package:hermes_app/src/bot_screen/bot_screen_preview_model.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/models/model_provider_option.dart'
    show ModelChoice, ModelOption, ModelOptions, ModelProviderOption;
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/widgets/named_icon_button.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'bot_screen_fixture.dart';
import 'catalog_auth.dart';
import 'fixtures.dart';
import 'frame.dart';
import 'platform_theme.dart';

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
  builder: (context) =>
      Theme(data: platformTheme(context, TargetPlatform.macOS), child: child),
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
  builder: (context) =>
      Theme(data: platformTheme(context, platform), child: child),
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

/// [child] on [platform], with the app theme built for it (`buildHermes*Theme`
/// recomputes the tap-target size, density and chrome that `copyWith` would
/// keep), in the brightness the catalog is showing.
Widget _onPlatform(TargetPlatform platform, Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.brightnessOf(context) == Brightness.dark
        ? buildHermesDarkTheme(platform: platform)
        : buildHermesLightTheme(platform: platform),
    child: child,
  ),
);

const _platformNames = {
  TargetPlatform.iOS: 'iPhone',
  TargetPlatform.macOS: 'Mac',
  TargetPlatform.android: 'Material',
};

/// One use case per platform of [platforms], for a ring whose radius follows
/// the section's (iOS 10, Mac 8, Material 12).
List<WidgetbookUseCase> _eachPlatform(
  String name,
  Widget Function() build, {
  List<TargetPlatform> platforms = const [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ],
}) => [
  for (final platform in platforms)
    WidgetbookUseCase(
      name: '$name (${_platformNames[platform]})',
      builder: (_) => _onPlatform(platform, build()),
    ),
];

Widget _section(List<Widget> rows) => GroupedSection(children: rows);

Widget _actionRows() => _section([
  GroupedActionRow(
    title: 'Restart gateway',
    icon: AppIcons.refresh,
    onPressed: () {},
  ),
  GroupedActionRow(
    title: 'Run a server check',
    icon: AppIcons.play,
    onPressed: () {},
  ),
]);

Widget _valueRows() => _section([
  GroupedValueRow(title: 'Provider', value: 'Anthropic', onTap: () {}),
  GroupedValueRow(
    title: 'Model',
    value: 'claude-sonnet',
    caption: 'Anthropic',
    onTap: () {},
  ),
]);

/// The Schedules form's "Advanced" row, in a section under another row.
Widget _advancedRow() => _section([
  const GroupedRow(title: 'Prompt', value: 'Summarize the news'),
  ScheduleAdvancedRow(open: false, onTap: () {}),
]);

const _folder = FileRowModel(name: 'src', isFolder: true);
const _file = FileRowModel(name: 'analysis.py', isFolder: false);

Widget _fileRows() => Builder(
  builder: (context) => GroupedSection(
    dividerIndent: GroupedMetrics.of(context).indentAfterLeading,
    children: [
      FileRow(model: _folder, onTap: () {}),
      FileRow(model: _file, onTap: () {}),
    ],
  ),
);

Widget _activityLine() => Builder(
  builder: (context) => ActivityLine(
    model: ActivityLineModel.fromSummary(
      context.l10n,
      WorkingSummary(
        sentence: const WorkingSentence(
          WorkingSentenceKind.goal,
          at: 1,
          text: 'Ship the weekly report by Friday',
        ),
      ),
    ),
    onOpen: () {},
  ),
);

const _agent = AgentRowModel(
  goal: 'Audit the dependency tree for packages with known vulnerabilities',
  state: AgentState.running,
  runTime: Duration(minutes: 1, seconds: 12),
  toolCount: 4,
  currentTool: 'read_file',
  currentPreview: 'go.sum',
);

Widget _agentRows() => Column(
  children: [
    AgentRow(model: _agent, onShowDetails: () {}, onStop: () {}),
    AgentRow(
      model: const AgentRowModel(
        goal: 'Summarize the open advisories',
        state: AgentState.finished,
        runTime: Duration(seconds: 48),
        toolCount: 4,
      ),
      onShowDetails: () {},
    ),
  ],
);

Widget _contextRow() {
  const figures = ContextFigures(
    used: 124000,
    max: 200000,
    percent: 62,
    estimated: false,
    source: ContextSource.providerUsage,
  );
  return ContextRow(
    figures: figures,
    level: contextLevelOf(figures),
    onOpen: () {},
    onCompress: () {},
    onDismissSuggestion: () {},
  );
}

Widget _checkpointsRow() => FileCheckpointsRow(
  state: CheckpointsRowState.count,
  count: 3,
  onOpen: () {},
);

const _subagents = [
  Subagent(
    id: 'agent-1',
    goal: 'Audit the dependency tree for packages with known vulnerabilities',
    count: 2,
    toolCount: 6,
    lastTool: 'read_file',
    lastToolPreview: 'go.sum',
  ),
  Subagent(
    id: 'agent-2',
    goal: 'Summarize the open advisories for the release notes',
    index: 1,
    count: 2,
    status: SubagentStatus.completed,
    toolCount: 4,
    summary: 'Two advisories apply; both are fixed in the next patch release.',
    duration: Duration(seconds: 48),
  ),
];

Widget _subagentCard() => const SubagentGroupCard(
  subagents: _subagents,
  initiallyOpen: true,
  onShowDetails: _ignoreId,
);

void _ignoreId(String _) {}

Widget _jsonTree() => const Card(
  margin: EdgeInsets.zero,
  clipBehavior: Clip.antiAlias,
  child: ToolJsonTree(
    text:
        '{"path": "go.sum", "limit": 20, "options": {"recursive": true, '
        '"follow": false}, "tags": ["a", "b"]}',
  ),
);

Widget _restartBanner() => ServerRestartBanner.restarting(onTap: () {});

Widget _workingFolderRow() => Builder(
  builder: (context) => Container(
    color: Theme.of(context).colorScheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: WorkingDirectoryRow(
      folderName: 'demo',
      path: '/home/me/code/demo',
      branch: 'main',
      serverDefault: true,
      onTap: () {},
    ),
  ),
);

Widget _workingFolderLine({required bool belowBar}) => WorkingDirectoryLine(
  title: 'Weekly planning',
  folderName: 'api',
  branch: 'main',
  belowBar: belowBar,
  onTap: () {},
);

const _plainTask = KanbanTask(
  id: 't_1a2b3c',
  title: 'Draft the weekly report',
  status: 'todo',
  assignee: 'writer',
  commentCount: 2,
);

Widget _kanbanColumn({bool selected = false}) => SizedBox(
  width: 260,
  child: Column(
    spacing: 8,
    children: [
      KanbanCard(task: _plainTask, onTap: () {}, selected: selected),
      KanbanCard(
        task: const KanbanTask(
          id: 't_4d5e6f',
          title: 'Review the release notes',
          status: 'todo',
          priority: 2,
        ),
        onTap: () {},
      ),
    ],
  ),
);

/// The rows that take the ring inside their own edge, because a section, a
/// list or a card clips them (F.427, tables B and C). Each focuses a row with
/// the keyboard: the ring is 2 px inside the row, with the radius the row's
/// container gives it.
List<WidgetbookUseCase> _insideRowUseCases() => [
  ..._eachPlatform(
    'Inside row: Grouped action row',
    () => _at(1, _actionRows()),
  ),
  ..._eachPlatform(
    'Inside row: Grouped value row (iOS wrapper)',
    () => _at(1, _valueRows()),
    platforms: const [TargetPlatform.iOS],
  ),
  ..._eachPlatform(
    'Inside row: Schedules Advanced row',
    () => _at(1, _advancedRow()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: File row',
    builder: (_) => _at(1, _fileRows()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Activity line',
    builder: (_) => _at(0, _activityLine()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Agent row',
    builder: (_) => _at(0, _agentRows()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Context row',
    builder: (_) => _at(0, _contextRow()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: File checkpoints row',
    builder: (_) => _at(0, _checkpointsRow()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Sub-agent group header',
    builder: (_) => _at(0, _subagentCard()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Sub-agent line',
    builder: (_) => _at(1, _subagentCard()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Tool-call JSON tree row',
    builder: (_) => _at(1, _jsonTree()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Restart banner',
    builder: (_) => _at(0, _restartBanner()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Working-folder row',
    builder: (_) => _at(0, _workingFolderRow()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Working-folder line',
    builder: (_) => _at(0, _workingFolderLine(belowBar: false)),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Working-folder line (full width)',
    builder: (_) => _at(0, _workingFolderLine(belowBar: true)),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Kanban card',
    builder: (_) => _at(0, _kanbanColumn()),
  ),
  WidgetbookUseCase(
    name: 'Inside row: Kanban card, selected',
    builder: (_) => _at(0, _kanbanColumn(selected: true)),
  ),
];

/// The keyboard-focused states of the tap targets that nothing clips (F.427,
/// table D): the ring is 2 px outside the control, the control's radius plus 2.
/// Each is the real widget on its platform's own theme.
const _outsidePhones = {
  'Material': TargetPlatform.android,
  'iPhone': TargetPlatform.iOS,
  'Mac': TargetPlatform.macOS,
};

List<WidgetbookUseCase> _outside(
  String item,
  Widget Function() build, {
  Map<String, TargetPlatform> platforms = _outsidePhones,
  bool Function(FocusNode node)? where,
}) => [
  for (final MapEntry(key: name, value: platform) in platforms.entries)
    WidgetbookUseCase(
      name: 'Outside tap target: $item ($name)',
      builder: (_) => _on(
        platform,
        frame(_KeyboardFocus(focusIndex: 0, where: where, child: build())),
      ),
    ),
];

bool _inSave(FocusNode node) {
  var found = false;
  node.context?.visitAncestorElements((element) {
    found = element.widget is NamedIconButton;
    return !found;
  });
  return found;
}

bool _inEffort(FocusNode node) {
  var found = false;
  node.context?.visitAncestorElements((element) {
    found = element.widget.key == const Key('effort-medium');
    return !found;
  });
  return found;
}

/// One model only, so that at a large text size (where the effort pills sit at
/// the end of the list) the pills are still on screen.
const _oneModel = ModelOptions(
  current: ModelChoice('anthropic', 'claude-opus-4'),
  providers: [
    ModelProviderOption(
      id: 'anthropic',
      label: 'Anthropic',
      models: [ModelOption(id: 'claude-opus-4', canDisableReasoning: true)],
    ),
  ],
);

Widget _effortPicker({double textScale = 1}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: SizedBox(
      width: 420,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ModelPicker(
          options: textScale > 1 ? _oneModel : modelOptions,
          selected: const ModelChoice(
            'anthropic',
            'claude-opus-4',
            effort: 'high',
          ),
          onChanged: (_) {},
        ),
      ),
    ),
  ),
);

List<WidgetbookUseCase> _outsideTapTargetUseCases() => [
  ..._outside(
    'Tool-call group header',
    () => const ToolCallGroup(calls: finishedToolRun),
  ),
  ..._outside(
    'Reasoning toggle',
    () => const ReasoningBlock(text: reasoningText),
  ),
  ..._outside(
    'Attachment retry card',
    () => AttachmentCardFrame(
      attachment: const ChatAttachment(
        name: 'quarterly-report.pdf',
        kind: AttachmentKind.file,
        size: 482113,
      ),
      notice: "Couldn't download. Tap to retry.",
      noticeIsError: true,
      onTap: _noop,
    ),
    platforms: {
      'Material': TargetPlatform.android,
      'Mac': TargetPlatform.macOS,
    },
  ),
  // Save draws its own ring and the card's stays off. A Mac card has no tap.
  ..._outside(
    'Attachment card, Save focused',
    () => AttachmentCardFrame(
      attachment: const ChatAttachment(
        name: 'quarterly-report.pdf',
        kind: AttachmentKind.file,
        size: 482113,
      ),
      onTap: _noop,
      trailing: NamedIconButton(
        label: 'Save quarterly-report.pdf',
        tooltip: 'Save',
        icon: AppIcons.download,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        onPressed: _noop,
      ),
    ),
    where: _inSave,
  ),
  ..._outside(
    'Bot Screen preview',
    () => BotScreenPreview(
      model: BotScreenPreviewFrame(bytes: botScreenFixturePng()),
      onTap: _noop,
    ),
  ),
  ..._outside(
    'Welcome card',
    () => SizedBox(
      height: 460,
      child: WelcomeView(
        greetingName: 'Ada',
        prompts: buildStarterPrompts(const StarterContext()),
        onPick: (_) {},
      ),
    ),
  ),
  ..._outside('Effort pill', _effortPicker, where: _inEffort),
  ..._outside(
    'Effort pill, text 3x',
    () => _effortPicker(textScale: 3),
    platforms: const {'Material': TargetPlatform.android},
    where: _inEffort,
  ),
  ..._outside(
    'Mac pop-up value',
    () => const GroupedSection(
      children: [
        GroupedValueRow(title: 'Model', value: 'claude-opus-4', onTap: _noop),
      ],
    ),
    platforms: const {'Mac': TargetPlatform.macOS},
  ),
  // What the screens build: the button round the row takes the focus.
  ..._outside(
    'Mac pop-up value in a menu row',
    () => GroupedSection(
      children: [
        GroupedMenuRow<String>(
          title: 'Model',
          options: const ['claude-opus-4', 'claude-sonnet-4'],
          labelOf: (option) => option,
          selected: 'claude-opus-4',
          onSelected: (_) {},
        ),
      ],
    ),
    platforms: const {'Mac': TargetPlatform.macOS},
  ),
];

/// Owns the sign-in state a sidebar reads, for as long as the use case is on
/// screen. Built in `initState`, not asynchronously, so that the focus the
/// preview moves is there on the first frame.
class _SidebarHost extends StatefulWidget {
  const _SidebarHost({required this.child});

  final Widget child;

  @override
  State<_SidebarHost> createState() => _SidebarHostState();
}

class _SidebarHostState extends State<_SidebarHost> {
  final _auth = CatalogAuth(gated: true);

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => withAppProviders(_auth, widget.child);
}

bool _inside<T extends Widget>(FocusNode node) {
  var found = false;
  node.context?.visitAncestorElements((element) {
    found = element.widget is T;
    return !found;
  });
  return found;
}

bool _inSidebarRow(FocusNode node) => _inside<SidebarRow>(node);

/// The row's own ink well: inside the row and not inside a button of it.
bool _sidebarRowItself(FocusNode node) =>
    _inSidebarRow(node) && !_insideButton(node);

bool _sidebarRowButton(FocusNode node) =>
    _inSidebarRow(node) && _insideButton(node);

bool _macTileItself(FocusNode node) =>
    _inside<MacSourceListTile>(node) && !_insideButton(node);

bool _macTileButton(FocusNode node) =>
    _inside<MacSourceListTile>(node) && _insideButton(node);

bool _inSidebarAction(FocusNode node) => _inside<SidebarAction>(node);

bool _inMacHit(FocusNode node) => _inside<MacSearchHitRow>(node);

const _sidebarPlatforms = {
  'iPhone': TargetPlatform.iOS,
  'Material': TargetPlatform.android,
  'Windows': TargetPlatform.windows,
  'Linux': TargetPlatform.linux,
};

/// Platforms whose thread row has the inline More button (everywhere but iOS,
/// where a swipe and a long press open the menu).
final _inlineMoreRows = {
  for (final e in _sidebarPlatforms.entries)
    if (e.value != TargetPlatform.iOS) e.key: e.value,
};

/// The thread sidebar as the app builds it, with housekeeping so a thread row
/// has its More button off iOS.
Widget _threadSidebar() => fill(
  ThreadSidebar(
    threads: threads,
    selectedId: threads.first.id,
    onSelect: (_) {},
    onNewThread: () {},
    housekeeping: ThreadHousekeeping(
      repository: HermesChatRepository(FakeHermesServer().client().raw),
      threads: () => threads,
      profile: () => null,
      changed: () {},
      report: (_) {},
      removed: (_) {},
      history: (thread, {cancelled}) async => const [],
    ),
  ),
  width: 300,
);

Widget _sidebarUseCase(
  TargetPlatform platform,
  Widget Function() build, {
  bool Function(FocusNode node)? where,
  bool hover = false,
}) => _onPlatform(
  platform,
  _SidebarHost(
    child: _KeyboardFocus(
      focusIndex: 0,
      where: where,
      hover: hover,
      child: build(),
    ),
  ),
);

WidgetbookUseCase _sidebarCase(
  String name,
  TargetPlatform platform,
  Widget Function() build, {
  bool Function(FocusNode node)? where,
  bool hover = false,
}) => WidgetbookUseCase(
  name: 'Sidebar row: $name',
  builder: (_) => _sidebarUseCase(platform, build, where: where, hover: hover),
);

Widget _sidebarActions() => fill(
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        SidebarAction(icon: AppIcons.add, label: 'New chat', onTap: () {}),
        SidebarAction(
          icon: AppIcons.settings,
          label: 'Settings',
          selected: true,
          onTap: () {},
        ),
      ],
    ),
  ),
  width: 300,
);

Widget _searchHits() => fill(
  ThreadSearchResults(
    query: 'backup',
    status: ThreadSearchStatus.done,
    hits: searchHits,
    selectedId: 'thread-2',
    onOpen: (_) {},
  ),
  width: 300,
);

Widget _macSearchResults({List<String> recent = const []}) => fill(
  MacSearchResults(
    query: recent.isEmpty ? 'backup' : '',
    status: ThreadSearchStatus.done,
    hits: recent.isEmpty ? searchHits : const [],
    scope: ThreadSearchScope.profile,
    recent: recent,
    selectedId: 'thread-2',
    onOpen: (_) {},
    onPickRecent: (_) {},
  ),
  width: 300,
);

Widget _macThreadRow() => frame(
  SizedBox(
    width: 260,
    child: MacThreadRow(
      title: 'Plan the release',
      selected: true,
      onTap: () {},
      onArchive: () {},
      menuItems: (context) =>
          macThreadMenuItems(context.l10n, pinned: false, manageable: true),
      onAction: (_) {},
    ),
  ),
);

Widget _macDestination() => frame(
  SizedBox(
    width: 260,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          MacSourceListRow(
            icon: AppIcons.settings,
            label: 'Profiles',
            caption: '3',
            selected: true,
            onTap: () {},
          ),
          MacSourceListRow(icon: AppIcons.add, label: 'Skills', onTap: () {}),
        ],
      ),
    ),
  ),
);

/// The sidebar rows that take the ring inside their own edge, because the list
/// clips them (F.427, table A). Each is the real widget on its platform's own
/// theme, with the keyboard on the row. A row with buttons of its own (the
/// thread row's More, the Mac thread row's Archive and More) also has a state
/// with a button focused, where the row draws no ring.
List<WidgetbookUseCase> _sidebarRowUseCases() => [
  for (final MapEntry(key: name, value: platform) in _sidebarPlatforms.entries)
    _sidebarCase(
      'Thread row ($name)',
      platform,
      _threadSidebar,
      where: _sidebarRowItself,
    ),
  for (final MapEntry(key: name, value: platform) in _inlineMoreRows.entries)
    _sidebarCase(
      'Thread row, inline More focused ($name)',
      platform,
      _threadSidebar,
      where: _sidebarRowButton,
    ),
  for (final MapEntry(key: name, value: platform) in _sidebarPlatforms.entries)
    _sidebarCase(
      'Search hit row ($name)',
      platform,
      _searchHits,
      where: _inSidebarRow,
    ),
  for (final MapEntry(key: name, value: platform) in _sidebarPlatforms.entries)
    _sidebarCase(
      'Action row ($name)',
      platform,
      _sidebarActions,
      where: _inSidebarAction,
    ),
  _sidebarCase(
    'Mac thread row',
    TargetPlatform.macOS,
    _macThreadRow,
    where: _macTileItself,
  ),
  _sidebarCase(
    'Mac thread row, inline Archive focused',
    TargetPlatform.macOS,
    _macThreadRow,
    where: _macTileButton,
    hover: true,
  ),
  _sidebarCase(
    'Mac destination row',
    TargetPlatform.macOS,
    _macDestination,
    where: _macTileItself,
  ),
  _sidebarCase(
    'Mac recent search row',
    TargetPlatform.macOS,
    () => _macSearchResults(recent: const ['backup', 'release notes']),
    where: _macTileItself,
  ),
  _sidebarCase(
    'Mac search hit row',
    TargetPlatform.macOS,
    _macSearchResults,
    where: _inMacHit,
  ),
];

bool _inPopupTrigger(FocusNode node) =>
    _inside<AdaptivePopupMenuButton<Object?>>(node);

/// The iPhone pull-down trigger of [AdaptivePopupMenuButton] with a custom
/// child, with the keyboard on it (F.441): the ring sits outside the control
/// (pill, subtitle, account footer) or inside it (value row, filter chip).
Widget _popupTrigger(
  Widget Function() build, {
  double textScale = 1,
  bool sidebar = false,
}) {
  final scaled = textScale == 1
      ? build()
      : Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: build(),
          ),
        );
  final focused = _KeyboardFocus(
    focusIndex: 0,
    where: _inPopupTrigger,
    child: scaled,
  );
  return _on(
    TargetPlatform.iOS,
    sidebar ? _SidebarHost(child: focused) : frame(focused),
  );
}

Widget _logLevelPill() => const Padding(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Align(
    alignment: Alignment.centerLeft,
    child: LogLevelMenuButton(
      value: LogLevelFilter.warnings,
      onChanged: _ignoreLevel,
    ),
  ),
);

void _ignoreLevel(LogLevelFilter _) {}

Widget _subtitleMenu() => SizedBox(
  height: 260,
  child: SettingsScaffold(
    title: 'Server logs',
    subtitle: 'work profile',
    subtitleMenu: SettingsSubtitleMenu<String>(
      label: 'Profile',
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'work', child: Text('work')),
        PopupMenuItem(value: 'home', child: Text('home')),
      ],
      onSelected: (_) {},
    ),
    body: const SizedBox.shrink(),
  ),
);

Widget _valueRow() => GroupedSection(
  header: 'Model',
  children: [
    GroupedMenuRow<String>(
      title: 'Provider',
      options: const ['anthropic', 'openrouter'],
      labelOf: (o) => o,
      selected: 'anthropic',
      onSelected: (_) {},
    ),
    GroupedMenuRow<String>(
      title: 'Effort',
      options: const ['low', 'high'],
      labelOf: (o) => o,
      selected: 'high',
      onSelected: (_) {},
    ),
  ],
);

Widget _filterChips() => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      KanbanFilterMenu(
        label: 'All assignees',
        all: 'All assignees',
        options: const ['ada', 'grace'],
        onSelected: (_) {},
      ),
      const SizedBox(width: 8),
      FilterChip(label: const Text('Archived'), onSelected: (_) {}),
    ],
  ),
);

/// F.441: the pull-down trigger of the five callers that pass a custom child,
/// on iPhone, with the keyboard on the trigger. The account footer is in the
/// real thread sidebar.
List<WidgetbookUseCase> _popupTriggerUseCases() => [
  WidgetbookUseCase(
    name: 'Popup trigger: Log level pill (iPhone)',
    builder: (_) => _popupTrigger(_logLevelPill),
  ),
  WidgetbookUseCase(
    name: 'Popup trigger: Log level pill, text 3x (iPhone)',
    builder: (_) => _popupTrigger(_logLevelPill, textScale: 3),
  ),
  WidgetbookUseCase(
    name: 'Popup trigger: Settings subtitle (iPhone)',
    builder: (_) => _popupTrigger(_subtitleMenu),
  ),
  WidgetbookUseCase(
    name: 'Popup trigger: Grouped value row (iPhone)',
    builder: (_) => _popupTrigger(_valueRow),
  ),
  WidgetbookUseCase(
    name: 'Popup trigger: Kanban filter chip (iPhone)',
    builder: (_) => _popupTrigger(_filterChips),
  ),
  WidgetbookUseCase(
    name: 'Popup trigger: Kanban filter chip, text 3x (iPhone)',
    builder: (_) => _popupTrigger(_filterChips, textScale: 3),
  ),
  WidgetbookUseCase(
    name: 'Popup trigger: Account footer (iPhone)',
    builder: (_) => _popupTrigger(_threadSidebar, sidebar: true),
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
    ..._outsideTapTargetUseCases(),
    ..._insideRowUseCases(),
    ..._sidebarRowUseCases(),
    ..._popupTriggerUseCases(),
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
