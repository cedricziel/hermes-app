import 'package:flutter/cupertino.dart' show CupertinoMenuAnchor;
import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/chat_workspace_state.dart';
import 'package:hermes_app/src/chat/widgets/thread_grouping_controls.dart';
import 'package:hermes_app/src/chat/thread_list_preferences.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/server_path_text.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/workspaces/widgets/change_folder_confirmation.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_browser_view.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_mismatch_notice.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_toolbar_button.dart';
import 'package:hermes_app/src/workspaces/widgets/path_entry_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_details.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_row.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';

// Everything here is invented: a made-up server, folders, projects and chats.

const _demo = '/home/me/code/demo';
const _api = '/home/me/code/demo/api';

const _longPath =
    '/srv/workspaces/research-group-north/field-campaign-2026/soil-moisture-survey/analysis-scripts-and-notebooks';
const _longName = 'soil-moisture-survey-analysis-scripts-and-notebooks-2026';

WidgetbookUseCase _case(String name, Widget Function(BuildContext) builder) =>
    WidgetbookUseCase(name: name, builder: builder);

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _on(TargetPlatform platform, Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: platform),
    child: child,
  ),
);

Widget _reducedMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// An iPad in portrait: regular width, Apple chrome.
Widget _ipad(Widget child) => _on(
  TargetPlatform.iOS,
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: const Size(820, 1180)),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 820, child: child),
      ),
    ),
  ),
);

ServerPath _path(String text) => ServerPath.tryParse(text)!;

// -- The row above a new chat's composer --------------------------------------

/// The row with a stand-in composer under it, as it sits in a new chat.
Widget _composerColumn(Widget row, {double maxWidth = 560}) => Builder(
  builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(kHermesRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Message Hermes',
                style: TextStyle(color: context.hermesColors.subtleText),
              ),
            ),
          ),
        ],
      ),
      maxWidth: maxWidth,
    );
  },
);

Widget _row({
  WorkingDirectoryRowState state = WorkingDirectoryRowState.ready,
  String? name = 'demo',
  String? path = _demo,
  String? branch = 'main',
  String? project,
  bool serverDefault = false,
  bool home = false,
  bool offline = false,
}) => _composerColumn(
  WorkingDirectoryRow(
    state: state,
    folderName: name,
    path: path,
    branch: branch,
    projectName: project,
    serverDefault: serverDefault,
    homeFolder: home,
    offline: offline,
    onTap: () {},
  ),
);

WidgetbookComponent _rowComponent() => WidgetbookComponent(
  name: 'WorkingDirectoryRow',
  useCases: [
    _case('Server default', (_) => _row(serverDefault: true)),
    _case(
      'Project picked',
      (_) => _row(name: 'api', path: _api, project: 'Demo'),
    ),
    _case(
      'Recent folder without a branch',
      (_) => _row(
        name: 'field-notes',
        path: '/srv/field/field-notes',
        branch: null,
      ),
    ),
    _case(
      'Home folder',
      (_) => _row(name: 'me', path: '/home/me', branch: null, home: true),
    ),
    _case(
      'Looking up',
      (_) => _row(
        state: WorkingDirectoryRowState.lookingUp,
        name: null,
        path: null,
      ),
    ),
    _case(
      'Looked up too long (server default wording)',
      (_) =>
          _row(state: WorkingDirectoryRowState.stalled, name: null, path: null),
    ),
    _case('Offline', (_) => _row(serverDefault: true, offline: true)),
    _case(
      'Long names',
      (_) => _row(
        name: _longName,
        path: _longPath,
        branch: 'feature/improve-the-soil-moisture-survey-analysis-pipeline',
        project: 'Soil moisture survey of the north district',
      ),
    ),
    _case(
      'Mac density (36 pt)',
      (_) => _on(
        TargetPlatform.macOS,
        _row(name: 'api', path: _api, project: 'Demo'),
      ),
    ),
    ...onEachPlatform('Server default', (_) => _row(serverDefault: true)),
    ...onEachPlatform(
      'Home folder',
      (_) => _row(name: 'me', path: '/home/me', branch: null, home: true),
    ),
    _case('iPad', (_) => _ipad(_row(name: 'api', path: _api, project: 'Demo'))),
    _case(
      'German',
      (_) => _german(_row(name: 'api', path: _api, project: 'Demo')),
    ),
    _case(
      'German, looking up and offline',
      (_) => _german(
        Column(
          children: [
            _row(
              state: WorkingDirectoryRowState.lookingUp,
              name: null,
              path: null,
            ),
            _row(serverDefault: true, offline: true),
          ],
        ),
      ),
    ),
    _case(
      'Text 2x',
      (_) => _scaled(2, _row(name: 'api', path: _api, project: 'Demo')),
    ),
    _case(
      'Largest text (3x), chips stack and the path wraps',
      (_) => _scaled(3, _row(name: 'api', path: _api, project: 'Demo')),
    ),
    _case(
      'Largest text (3x), home folder',
      (_) => _scaled(
        3,
        _row(name: 'me', path: '/home/me', branch: null, home: true),
      ),
    ),
    _case(
      'Largest text (3x), long names',
      (_) => _scaled(
        3,
        _row(
          name: _longName,
          path: _longPath,
          branch: 'feature/improve-the-soil-moisture-survey',
          project: 'Soil moisture survey',
        ),
      ),
    ),
    _case(
      'Largest text (3x), looking up',
      (_) => _scaled(
        3,
        _row(state: WorkingDirectoryRowState.lookingUp, name: null, path: null),
      ),
    ),
    _case(
      'Reduced motion, looking up',
      (_) => _reducedMotion(
        _row(state: WorkingDirectoryRowState.lookingUp, name: null, path: null),
      ),
    ),
  ],
);

// -- The line under an open chat's title -------------------------------------

/// A stand-in for the chat's bar with the line in it.
Widget _barWithLine(
  BuildContext context, {
  String folder = 'api',
  String? branch = 'main',
  bool offline = false,
  bool mac = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final below = workingDirectoryLineBelowBar(context);
  return fill(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: below
              ? Text(
                  'Weekly planning',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mac ? 13 : 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                )
              : WorkingDirectoryLine(
                  title: 'Weekly planning',
                  folderName: folder,
                  branch: branch,
                  offline: offline,
                  onTap: () {},
                ),
        ),
        if (below)
          WorkingDirectoryLine(
            folderName: folder,
            branch: branch,
            offline: offline,
            onTap: () {},
          ),
      ],
    ),
  );
}

WidgetbookComponent _lineComponent() => WidgetbookComponent(
  name: 'WorkingDirectoryLine',
  useCases: [
    _case('Folder and branch', (c) => _barWithLine(c)),
    _case('Folder only', (c) => _barWithLine(c, branch: null)),
    _case('Offline', (c) => _barWithLine(c, offline: true)),
    _case(
      'Long names',
      (c) => _barWithLine(
        c,
        folder: _longName,
        branch: 'feature/improve-the-soil-moisture-survey-analysis',
      ),
    ),
    ...onEachPlatform('Folder and branch', (c) => _barWithLine(c)),
    _case('iPad', (_) => _ipad(Builder(builder: (c) => _barWithLine(c)))),
    _case(
      'German, offline',
      (_) => _german(Builder(builder: (c) => _barWithLine(c, offline: true))),
    ),
    _case(
      'Text 2x',
      (_) => _scaled(2, Builder(builder: (c) => _barWithLine(c))),
    ),
    _case(
      'Largest text (3x): a full-width row under the bar',
      (_) => _scaled(3, Builder(builder: (c) => _barWithLine(c))),
    ),
    _case(
      'Largest text (3x), offline',
      (_) =>
          _scaled(3, Builder(builder: (c) => _barWithLine(c, offline: true))),
    ),
  ],
);

// -- Details -------------------------------------------------------------------

Widget _details({
  String name = 'api',
  String path = _api,
  String? branch = 'main',
  String? project = 'Demo',
  bool home = false,
  bool replying = false,
  bool offline = false,
  bool canChange = true,
  bool window = false,
  WorkspaceMoveState move = WorkspaceMoveState.idle,
  String? target,
  bool timedOut = false,
}) => fill(
  WorkingDirectoryDetails(
    folderName: name,
    path: path,
    branch: branch,
    projectName: project,
    homeFolder: home,
    replying: replying,
    offline: offline,
    canChange: canChange,
    conversationWindow: window,
    move: move,
    moveTarget: target,
    moveTimedOut: timedOut,
    onChange: () {},
    onTryAgain: () {},
    onCheckAgain: () {},
    onClose: () {},
  ),
  width: 480,
);

WorkspaceMoveState _phase(WorkspaceMovePhase phase, {String? folder}) =>
    WorkspaceMoveState(phase, folder: folder);

/// Selects the whole path on show, as a Mac shows it after a click and ⌘A.
class _SelectPathOnShow extends StatefulWidget {
  const _SelectPathOnShow({required this.child});

  final Widget child;

  @override
  State<_SelectPathOnShow> createState() => _SelectPathOnShowState();
}

class _SelectPathOnShowState extends State<_SelectPathOnShow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _select());
    });
  }

  void _select() {
    if (!mounted) return;
    void visit(Element element) {
      if (element is StatefulElement &&
          element.state is SelectableRegionState) {
        (element.state as SelectableRegionState).selectAll();
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

WidgetbookComponent _detailsComponent() => WidgetbookComponent(
  name: 'WorkingDirectoryDetails',
  useCases: [
    _case('Normal', (_) => _details()),
    _case(
      'Home folder',
      (_) => _details(
        name: 'me',
        path: '/home/me',
        branch: null,
        project: null,
        home: true,
      ),
    ),
    _case('Replying', (_) => _details(replying: true)),
    _case('Offline', (_) => _details(offline: true)),
    _case('Old server (no button)', (_) => _details(canChange: false)),
    _case(
      'Conversation window',
      (_) => _details(window: true, canChange: false),
    ),
    _case(
      'Changing',
      (_) => _details(
        move: _phase(WorkspaceMovePhase.moving),
        target: '/home/me/code/other',
      ),
    ),
    _case(
      'Changed (from the answer or the re-read)',
      (_) => _details(
        name: 'other',
        path: '/home/me/code/other',
        move: _phase(WorkspaceMovePhase.changed, folder: '/home/me/code/other'),
        target: '/home/me/code/other',
      ),
    ),
    _case(
      'Not changed (5007, or a re-read that shows the old folder)',
      (_) => _details(
        move: _phase(WorkspaceMovePhase.unchanged),
        target: '/home/me/code/other',
      ),
    ),
    _case(
      'Refused (the folder is missing, 4017)',
      (_) => _details(
        move: _phase(WorkspaceMovePhase.folderMissing),
        target: '/home/me/code/other',
      ),
    ),
    _case(
      'No answer in 10 s, checking',
      (_) => _details(
        move: _phase(WorkspaceMovePhase.checking),
        target: '/home/me/code/other',
        timedOut: true,
      ),
    ),
    _case(
      'Lost answer, checking',
      (_) => _details(
        move: _phase(WorkspaceMovePhase.checking),
        target: '/home/me/code/other',
      ),
    ),
    _case(
      'Could not confirm',
      (_) => _details(
        move: _phase(WorkspaceMovePhase.couldNotConfirm),
        target: '/home/me/code/other',
      ),
    ),
    _case(
      'Chat gone (4007)',
      (_) => _details(move: _phase(WorkspaceMovePhase.chatGone)),
    ),
    _case(
      'Profile gone (4064)',
      (_) => _details(move: _phase(WorkspaceMovePhase.profileGone)),
    ),
    _case(
      'Path selected (desktop)',
      (_) => _on(TargetPlatform.macOS, _SelectPathOnShow(child: _details())),
    ),
    _case(
      'Long names',
      (_) => _details(
        name: _longName,
        path: _longPath,
        branch: 'feature/improve-the-soil-moisture-survey-analysis',
        project: 'Soil moisture survey of the north district',
      ),
    ),
    ...onEachPlatform('Normal', (_) => _details()),
    ...onEachPlatform('Replying', (_) => _details(replying: true)),
    _case('iPad', (_) => _ipad(_details())),
    _case('German', (_) => _german(_details())),
    _case(
      'German, could not confirm',
      (_) => _german(
        _details(
          move: _phase(WorkspaceMovePhase.couldNotConfirm),
          target: '/home/me/code/other',
        ),
      ),
    ),
    _case('Text 2x', (_) => _scaled(2, _details(replying: true))),
    _case('Largest text (3x), rows stack', (_) => _scaled(3, _details())),
    _case(
      'Largest text (3x), home folder and replying',
      (_) => _scaled(
        3,
        _details(
          name: 'me',
          path: '/home/me',
          branch: null,
          project: null,
          home: true,
          replying: true,
        ),
      ),
    ),
    _case(
      'Largest text (3x), checking',
      (_) => _scaled(
        3,
        _details(
          move: _phase(WorkspaceMovePhase.checking),
          target: '/home/me/code/other',
          timedOut: true,
        ),
      ),
    ),
  ],
);

// -- ServerPathText ------------------------------------------------------------

Widget _serverPath(
  String path, {
  double width = 320,
  bool? wrap,
  bool selectable = false,
}) => frame(
  SizedBox(
    width: width,
    child: ServerPathText(_path(path), wrap: wrap, selectable: selectable),
  ),
  maxWidth: width + 32,
);

WidgetbookComponent _pathTextComponent() => WidgetbookComponent(
  name: 'ServerPathText',
  useCases: [
    _case('Short', (_) => _serverPath(_demo)),
    _case(
      'Long, cut in the middle (long press shows it all)',
      (_) => _serverPath(_longPath),
    ),
    _case('Long, wrapped in full', (_) => _serverPath(_longPath, wrap: true)),
    _case(
      'Selectable (desktop), wrapped',
      (_) => _on(
        TargetPlatform.macOS,
        _serverPath(_longPath, wrap: true, selectable: true),
      ),
    ),
    _case(
      'Narrow, the suffix stays',
      (_) => _serverPath(_longPath, width: 200),
    ),
    _case('German', (_) => _german(_serverPath(_longPath))),
    _case('Text 2x', (_) => _scaled(2, _serverPath(_longPath, width: 340))),
    _case(
      'Largest text (3x), wrapped, suffix on its own line',
      (_) => _scaled(3, _serverPath(_longPath, width: 340)),
    ),
  ],
);

// -- Picker --------------------------------------------------------------------

const _defaultRow = WorkspacePickerRow(
  id: 'default',
  title: 'demo',
  path: _demo,
  projectName: 'Demo',
);

const _projects = [
  WorkspacePickerRow(id: 'demo-api', title: 'Demo', label: 'api', path: _api),
  WorkspacePickerRow(
    id: 'demo-web',
    title: 'Demo',
    label: 'web',
    path: '/home/me/code/demo/web',
  ),
  WorkspacePickerRow(
    id: 'notes',
    title: 'Field notes',
    path: '/srv/field/field-notes',
  ),
];

const _recent = [
  WorkspacePickerRow(
    id: 'sandbox',
    title: 'sandbox',
    path: '/home/me/sandbox',
    chatCount: 12,
  ),
  WorkspacePickerRow(
    id: 'dotfiles',
    title: 'dotfiles',
    path: '/home/me/dotfiles',
    chatCount: 1,
  ),
];

final List<WorkspacePickerRow> _manyRecent = [
  for (var i = 1; i <= 9; i++)
    WorkspacePickerRow(
      id: 'repo-$i',
      title: 'repo-${i.toString().padLeft(2, '0')}',
      path: '/home/me/code/repo-${i.toString().padLeft(2, '0')}',
      chatCount: i,
    ),
];

Widget _picker({
  String selected = 'default',
  List<WorkspacePickerRow> projects = _projects,
  List<WorkspacePickerRow> recent = _recent,
  WorkspacePickerCatalog catalog = WorkspacePickerCatalog.ready,
  bool offline = false,
  bool locked = false,
  String query = '',
  bool scan = false,
  bool scanning = false,
  WorkspacePickerScanOutcome? outcome,
  int found = 0,
  WorkspacePickerRow? serverDefault = _defaultRow,
  double? width,
}) => Align(
  alignment: Alignment.topLeft,
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width ?? double.infinity),
    child: WorkspacePickerView(
      selectedId: selected,
      serverDefault: serverDefault,
      projects: projects,
      recent: recent,
      catalog: catalog,
      offline: offline,
      browseLocked: locked,
      query: query,
      scanAvailable: scan,
      scanning: scanning,
      scanOutcome: outcome,
      scanFound: found,
      onPick: (_) {},
      onBrowse: () {},
      onType: () {},
      onTryAgain: () {},
      onQueryChanged: (_) {},
      onScan: () {},
      onCancel: () {},
    ),
  ),
);

/// Opens the first popup menu on show, so the catalog and a screenshot show it.
class _OpenMenuOnShow extends StatefulWidget {
  const _OpenMenuOnShow({required this.child});

  final Widget child;

  @override
  State<_OpenMenuOnShow> createState() => _OpenMenuOnShowState();
}

class _OpenMenuOnShowState extends State<_OpenMenuOnShow> {
  @override
  void initState() {
    super.initState();
    // Two frames: the menu's button exists after the first, and its route can
    // open once the page is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    });
  }

  void _open() {
    if (!mounted) return;
    var opened = false;
    void visit(Element element) {
      if (opened) return;
      final widget = element.widget;
      // iOS draws a pull-down menu, elsewhere a popup menu.
      if (widget is CupertinoMenuAnchor && widget.controller != null) {
        widget.controller!.open();
        opened = true;
        return;
      }
      if (element is StatefulElement && element.state is PopupMenuButtonState) {
        (element.state as PopupMenuButtonState<dynamic>).showButtonMenu();
        opened = true;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

WidgetbookComponent _pickerComponent() => WidgetbookComponent(
  name: 'WorkspacePickerView',
  useCases: [
    _case('Ready', (_) => _picker(scan: true)),
    _case(
      'Default folder unknown (a new chat)',
      (_) => _picker(
        catalog: WorkspacePickerCatalog.projectsFailed,
        projects: const [],
        recent: const [],
        serverDefault: const WorkspacePickerRow(
          id: 'default',
          title: "Your server's default folder",
          path: '',
        ),
      ),
    ),
    _case(
      'Move, default folder unknown (no default row)',
      (_) => _picker(
        catalog: WorkspacePickerCatalog.projectsFailed,
        projects: const [],
        recent: const [],
        serverDefault: null,
      ),
    ),
    _case(
      'More than eight rows (search shows)',
      (_) => _picker(recent: _manyRecent, scan: true),
    ),
    _case(
      'Search',
      (_) => _picker(
        projects: [_projects.first, _projects[1]],
        recent: const [],
        query: 'demo',
      ),
    ),
    _case(
      'No match',
      (_) => _picker(projects: const [], recent: const [], query: 'zzz'),
    ),
    _case(
      'Loading',
      (_) => _picker(
        catalog: WorkspacePickerCatalog.loading,
        projects: const [],
        recent: const [],
      ),
    ),
    _case('Empty', (_) => _picker(projects: const [], recent: const [])),
    _case(
      'Projects failed',
      (_) => _picker(
        catalog: WorkspacePickerCatalog.projectsFailed,
        projects: const [],
        recent: const [],
      ),
    ),
    _case(
      'Offline',
      (_) => _picker(offline: true, projects: const [], recent: const []),
    ),
    _case(
      'Unknown profile',
      (_) => _picker(
        catalog: WorkspacePickerCatalog.unknownProfile,
        projects: const [],
        recent: const [],
      ),
    ),
    _case('Browsing locked', (_) => _picker(locked: true)),
    _case('More menu', (_) => _OpenMenuOnShow(child: _picker(scan: true))),
    _case('Scanning', (_) => _picker(scan: true, scanning: true)),
    _case(
      'Found',
      (_) => _picker(
        scan: true,
        outcome: WorkspacePickerScanOutcome.found,
        found: 3,
        recent: const [
          WorkspacePickerRow(
            id: 'new-1',
            title: 'ledger',
            path: '/home/me/code/ledger',
            isNew: true,
          ),
          WorkspacePickerRow(
            id: 'new-2',
            title: 'garden',
            path: '/home/me/code/garden',
            isNew: true,
          ),
          WorkspacePickerRow(
            id: 'new-3',
            title: 'recipes',
            path: '/home/me/code/recipes',
            isNew: true,
          ),
          ..._recent,
        ],
      ),
    ),
    _case(
      'Found one',
      (_) => _picker(
        scan: true,
        outcome: WorkspacePickerScanOutcome.found,
        found: 1,
        recent: const [
          WorkspacePickerRow(
            id: 'new-1',
            title: 'ledger',
            path: '/home/me/code/ledger',
            isNew: true,
          ),
          ..._recent,
        ],
      ),
    ),
    _case(
      'Nothing new',
      (_) =>
          _picker(scan: true, outcome: WorkspacePickerScanOutcome.nothingNew),
    ),
    _case(
      'Nothing to scan',
      (_) => _picker(
        scan: true,
        outcome: WorkspacePickerScanOutcome.nothingToScan,
      ),
    ),
    _case(
      'Scan too slow',
      (_) => _picker(scan: true, outcome: WorkspacePickerScanOutcome.tooSlow),
    ),
    _case(
      'Move, with Current',
      (_) => _picker(
        selected: 'current',
        scan: true,
        projects: const [
          WorkspacePickerRow(
            id: 'current',
            title: 'Demo',
            label: 'api',
            path: _api,
            isCurrent: true,
          ),
          WorkspacePickerRow(
            id: 'demo-web',
            title: 'Demo',
            label: 'web',
            path: '/home/me/code/demo/web',
          ),
        ],
      ),
    ),
    _case(
      'Long names',
      (_) => _picker(
        projects: const [
          WorkspacePickerRow(
            id: 'long',
            title: 'Soil moisture survey of the north district',
            label: 'analysis-scripts-and-notebooks',
            path: _longPath,
          ),
        ],
        recent: const [
          WorkspacePickerRow(
            id: 'long-recent',
            title: _longName,
            path: _longPath,
            chatCount: 128,
          ),
        ],
        serverDefault: const WorkspacePickerRow(
          id: 'default',
          title: _longName,
          path: _longPath,
          projectName: 'Soil moisture survey of the north district',
        ),
        selected: 'long-recent',
      ),
    ),
    // The dialog's own width on a Mac and a wide window.
    ...onEachPlatform('Ready', (_) => _picker(scan: true, width: 480)),
    ...onEachPlatform(
      'Offline',
      (_) => _picker(offline: true, projects: const [], recent: const []),
    ),
    _case(
      'iPad dialog (480 pt)',
      (_) => _ipad(_picker(scan: true, width: 480)),
    ),
    _case('German', (_) => _german(_picker(scan: true))),
    _case(
      'German, found one',
      (_) => _german(
        _picker(
          scan: true,
          outcome: WorkspacePickerScanOutcome.found,
          found: 1,
        ),
      ),
    ),
    _case(
      'German, offline',
      (_) =>
          _german(_picker(offline: true, projects: const [], recent: const [])),
    ),
    _case('Text 2x', (_) => _scaled(2, _picker(scan: true))),
    _case('Largest text (3x)', (_) => _scaled(3, _picker(scan: true))),
    _case(
      'Largest text (3x), offline',
      (_) => _scaled(
        3,
        _picker(offline: true, projects: const [], recent: const []),
      ),
    ),
    _case(
      'Largest text (3x), loading',
      (_) => _scaled(
        3,
        _picker(
          catalog: WorkspacePickerCatalog.loading,
          projects: const [],
          recent: const [],
        ),
      ),
    ),
  ],
);

// -- Browse --------------------------------------------------------------------

FileRowModel _folder(String name, {String dir = '/home/me/code'}) =>
    FileRowModel(name: name, isFolder: true, path: _path('$dir/$name'));

final _folders = [
  _folder('demo'),
  _folder('field-notes'),
  _folder('ledger'),
  _folder('sandbox'),
];

Widget _browse(
  String current, {
  FolderBrowserLevel level = FolderBrowserLevel.ready,
  List<FileRowModel>? rows,
}) => pushed(
  FolderBrowserView(
    current: _path(current),
    level: level,
    rows: rows ?? _folders,
    onOpen: (_) {},
    onOpenPath: (_) {},
    onUp: () {},
    onUse: () {},
    onTryAgain: () {},
  ),
);

WidgetbookComponent _browseComponent() => WidgetbookComponent(
  name: 'FolderBrowserView',
  useCases: [
    _case('A level', (_) => _browse('/home/me/code')),
    _case(
      'The root',
      (_) => _browse(
        '/',
        rows: [
          _folder('home', dir: ''),
          _folder('srv', dir: ''),
          _folder('opt', dir: ''),
        ],
      ),
    ),
    _case(
      'Opening',
      (_) => _browse('/home/me/code', level: FolderBrowserLevel.opening),
    ),
    _case('Empty', (_) => _browse('/home/me/code/ledger', rows: const [])),
    _case(
      'Not allowed (Use enabled, with its note)',
      (_) => _browse('/home/me/private', level: FolderBrowserLevel.notAllowed),
    ),
    _case(
      'Outside the boundary (Use disabled)',
      (_) => _browse('/home/me', level: FolderBrowserLevel.outside),
    ),
    _case(
      'Missing (Use disabled)',
      (_) => _browse('/home/me/code/old', level: FolderBrowserLevel.missing),
    ),
    _case(
      'Connection lost',
      (_) => _browse('/home/me/code', level: FolderBrowserLevel.unreachable),
    ),
    _case(
      'Long names',
      (_) => _browse(
        _longPath,
        rows: [
          _folder(_longName, dir: _longPath),
          _folder('notebooks', dir: _longPath),
        ],
      ),
    ),
    ...onEachPlatform('A level', (_) => _browse('/home/me/code')),
    ...onEachPlatform(
      'Not allowed',
      (_) => _browse('/home/me/private', level: FolderBrowserLevel.notAllowed),
    ),
    _case('iPad', (_) => _ipad(_browse('/home/me/code'))),
    _case('German', (_) => _german(_browse('/home/me/code'))),
    _case(
      'German, outside',
      (_) => _german(_browse('/home/me', level: FolderBrowserLevel.outside)),
    ),
    _case('Text 2x', (_) => _scaled(2, _browse('/home/me/code'))),
    _case('Largest text (3x)', (_) => _scaled(3, _browse('/home/me/code'))),
    _case(
      'Largest text (3x), not allowed',
      (_) => _scaled(
        3,
        _browse('/home/me/private', level: FolderBrowserLevel.notAllowed),
      ),
    ),
    _case(
      'Largest text (3x), opening',
      (_) => _scaled(
        3,
        _browse('/home/me/code', level: FolderBrowserLevel.opening),
      ),
    ),
  ],
);

// -- Type a path ---------------------------------------------------------------

const _suggestions = [
  PathEntrySuggestion(name: 'demo', path: '/home/me/code/demo/'),
  PathEntrySuggestion(name: 'ledger', path: '/home/me/code/ledger/'),
  PathEntrySuggestion(name: 'sandbox', path: '/home/me/code/sandbox/'),
];

Widget _type(
  String text, {
  List<PathEntrySuggestion> suggestions = const [],
  bool capped = false,
  PathEntryCheck check = PathEntryCheck.idle,
}) => pushed(
  _TypeHarness(
    text: text,
    suggestions: suggestions,
    capped: capped,
    check: check,
  ),
);

/// Holds the field's text for the catalog, so typing, the clear button and a
/// tapped suggestion work; `PathEntryView` itself stays model-only. The
/// suggestions and the check are fixed by the use case.
class _TypeHarness extends StatefulWidget {
  const _TypeHarness({
    required this.text,
    required this.suggestions,
    required this.capped,
    required this.check,
  });

  final String text;
  final List<PathEntrySuggestion> suggestions;
  final bool capped;
  final PathEntryCheck check;

  @override
  State<_TypeHarness> createState() => _TypeHarnessState();
}

class _TypeHarnessState extends State<_TypeHarness> {
  late String _text = widget.text;
  late PathEntryCheck _check = widget.check;
  String? _used;

  Future<void> _checkAgain() async {
    setState(() => _check = PathEntryCheck.checking);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _check = PathEntryCheck.found);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: PathEntryView(
          text: _text,
          suggestions: widget.suggestions,
          capped: widget.capped,
          check: _check,
          onChanged: (value) => setState(() => _text = value),
          onPickSuggestion: (pick) => setState(() => _text = pick.path),
          onUse: () => setState(() => _used = _text),
          onCheckAgain: _checkAgain,
        ),
      ),
      if (_used != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Catalog: would use $_used'),
        ),
    ],
  );
}

final List<PathEntrySuggestion> _thirty = [
  for (var i = 1; i <= 30; i++)
    PathEntrySuggestion(
      name: 'project-${i.toString().padLeft(2, '0')}',
      path: '/home/me/code/project-${i.toString().padLeft(2, '0')}/',
    ),
];

WidgetbookComponent _typeComponent() => WidgetbookComponent(
  name: 'PathEntryView',
  useCases: [
    _case(
      'Suggestions',
      (_) => _type('/home/me/code/', suggestions: _suggestions),
    ),
    _case('Empty field', (_) => _type('')),
    _case(
      'Relative path',
      (_) => _type('code/demo', check: PathEntryCheck.relative),
    ),
    _case(
      'Checking',
      (_) => _type('/home/me/code/demo', check: PathEntryCheck.checking),
    ),
    _case(
      'Check too slow',
      (_) => _type('/home/me/code/demo', check: PathEntryCheck.tooSlow),
    ),
    _case(
      'Missing',
      (_) => _type('/home/me/code/old', check: PathEntryCheck.missing),
    ),
    _case(
      'Not allowed (Use enabled, with its note)',
      (_) => _type('/home/me/private', check: PathEntryCheck.notAllowed),
    ),
    _case(
      '30 suggestions',
      (_) => _type('/home/me/code/', suggestions: _thirty, capped: true),
    ),
    _case('30 items, no folder', (_) => _type('/home/me/code/', capped: true)),
    _case('No suggestions', (_) => _type('/home/me/code/zz')),
    _case(
      'Server cannot check',
      (_) => _type('/home/me/code/demo', check: PathEntryCheck.cannotCheck),
    ),
    _case(
      'Found',
      (_) => _type('/home/me/code/demo', check: PathEntryCheck.found),
    ),
    ...onEachPlatform(
      'Found',
      (_) => _type('/home/me/code/demo', check: PathEntryCheck.found),
    ),
    ...onEachPlatform(
      'Missing',
      (_) => _type('/home/me/code/old', check: PathEntryCheck.missing),
    ),
    _case(
      'iPad',
      (_) => _ipad(_type('/home/me/code/', suggestions: _suggestions)),
    ),
    _case(
      'German',
      (_) => _german(_type('/home/me/code/', suggestions: _suggestions)),
    ),
    _case(
      'German, cannot check',
      (_) => _german(
        _type('/home/me/code/demo', check: PathEntryCheck.cannotCheck),
      ),
    ),
    _case(
      'Text 2x',
      (_) => _scaled(2, _type('/home/me/code/', suggestions: _suggestions)),
    ),
    _case(
      'Largest text (3x)',
      (_) => _scaled(3, _type('/home/me/code/', suggestions: _suggestions)),
    ),
    _case(
      'Largest text (3x), not allowed',
      (_) => _scaled(
        3,
        _type('/home/me/private', check: PathEntryCheck.notAllowed),
      ),
    ),
  ],
);

// -- Confirmation -------------------------------------------------------------

WidgetbookUseCase _confirm(
  String name, {
  double scale = 1,
  bool german = false,
}) => _case(name, (_) {
  Widget page = openOnShow(
    (context) => showChangeFolderConfirmation(
      context,
      folderName: 'other',
      path: '/home/me/code/other',
    ),
  );
  if (german) page = _german(page);
  return scale == 1 ? page : _scaled(scale, page);
});

WidgetbookComponent _confirmComponent() => WidgetbookComponent(
  name: 'ChangeFolderConfirmation',
  useCases: [
    ...onEachPlatform(
      'Confirmation',
      (_) => openOnShow(
        (context) => showChangeFolderConfirmation(
          context,
          folderName: 'other',
          path: '/home/me/code/other',
        ),
      ),
    ),
    _confirm('German', german: true),
    _confirm('Text 2x', scale: 2),
    _confirm('Largest text (3x)', scale: 3),
  ],
);

// -- Mismatch notice ----------------------------------------------------------

Widget _mismatch({bool profile = false}) => frame(
  FolderMismatchNotice(
    startedIn: 'me',
    picked: 'other',
    profileMayUseOwnFolder: profile,
    onChoose: () {},
  ),
  maxWidth: 560,
);

WidgetbookComponent _mismatchComponent() => WidgetbookComponent(
  name: 'FolderMismatchNotice',
  useCases: [
    _case('Default', (_) => _mismatch()),
    _case(
      'After the retry without cwd_explicit',
      (_) => _mismatch(profile: true),
    ),
    ...onEachPlatform('Default', (_) => _mismatch()),
    _case('German', (_) => _german(_mismatch(profile: true))),
    _case('Text 2x', (_) => _scaled(2, _mismatch(profile: true))),
    _case('Largest text (3x)', (_) => _scaled(3, _mismatch())),
    _case(
      'Long names',
      (_) => frame(
        const FolderMismatchNotice(
          startedIn: _longName,
          picked: 'soil-moisture-survey-north',
        ),
        maxWidth: 560,
      ),
    ),
  ],
);

// -- Mac toolbar button -------------------------------------------------------

Widget _toolbar({
  bool subtitle = true,
  String name = 'demo',
  String path = _demo,
  String? branch = 'main',
  bool enabled = true,
}) => _on(
  TargetPlatform.macOS,
  Align(
    alignment: Alignment.topCenter,
    child: MacToolbar(
      title: 'Weekly planning',
      subtitle: subtitle ? 'work · model' : null,
      actions: [
        FolderToolbarButton(
          folderName: name,
          path: path,
          branch: branch,
          onPressed: enabled ? () {} : null,
        ),
        const SizedBox(width: 4),
        MacToolbarButton(
          label: 'New Chat',
          shortcut: '⌘N',
          icon: AppIcons.compose,
          onPressed: () {},
        ),
      ],
    ),
  ),
);

WidgetbookComponent _toolbarComponent() => WidgetbookComponent(
  name: 'FolderToolbarButton',
  useCases: [
    _case('New chat', (_) => _toolbar()),
    _case('Open chat', (_) => _toolbar(name: 'api', path: _api)),
    _case('Long name', (_) => _toolbar(name: _longName, path: _longPath)),
    _case('Disabled', (_) => _toolbar(enabled: false)),
    _case('German', (_) => _german(_toolbar())),
    _case(
      'Text 2x',
      (_) => _scaled(2, _toolbar(name: 'api', path: _api, subtitle: false)),
    ),
  ],
);

// -- Chat list heading --------------------------------------------------------

Widget _heading(String label, {double width = 240, bool mac = false}) => _on(
  mac ? TargetPlatform.macOS : TargetPlatform.iOS,
  frame(
    ThreadSectionHeading(
      label: label,
      grouping: ThreadGrouping.folder,
      onToggle: () {},
      count: 12,
    ),
    maxWidth: width,
  ),
);

WidgetbookComponent _headingComponent() => WidgetbookComponent(
  name: 'ThreadSectionHeading (folder path)',
  useCases: [
    _case('Folder name', (_) => _heading('demo')),
    _case(
      'Path, cut in the middle (two folders named api)',
      (_) => _heading('/home/me/code/demo/api'),
    ),
    _case(
      'Path, cut in the middle (Mac)',
      (_) => _heading('/home/me/code/demo/api', mac: true),
    ),
    _case(
      'Long path',
      (_) => _heading('/srv/workspaces/research-group-north/analysis'),
    ),
    _case(
      'Text 2x',
      (_) => _scaled(2, _heading('/home/me/code/demo/api', width: 320)),
    ),
  ],
);

WidgetbookNode workspacesNode() => WidgetbookFolder(
  name: 'Working folder',
  children: [
    _rowComponent(),
    _lineComponent(),
    _detailsComponent(),
    _pathTextComponent(),
    _pickerComponent(),
    _browseComponent(),
    _typeComponent(),
    _confirmComponent(),
    _mismatchComponent(),
    _toolbarComponent(),
    _headingComponent(),
  ],
);
