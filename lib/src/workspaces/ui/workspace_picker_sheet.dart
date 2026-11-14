import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../files/server_path.dart';
import '../../files/widgets/file_row.dart';
import '../../surfaces/surface_snapshot.dart' show kDefaultProfile;
import '../../theme/breakpoints.dart';
import '../../widgets/adaptive_sheet.dart';
import '../widgets/folder_browser_view.dart';
import '../widgets/path_entry_view.dart';
import '../widgets/workspace_picker_view.dart';
import '../workspace_picker_controller.dart';
import 'workspace_guard.dart';

/// Opens the folder picker as a sheet on compact widths and a dialog on wide
/// ones and the Mac, and resolves with the folder that was taken, or null
/// when it was closed.
///
/// [moving] is the stored chat whose folder is being changed (its current
/// folder is marked); without it the pick is for a new chat. [onPick] decides
/// what taking a folder does: true closes the picker, false leaves it open
/// (a move's confirmation was declined). The picker closes by itself when
/// [guard] says so.
Future<FolderPick?> showWorkspacePicker(
  BuildContext context, {
  required ChatController chat,
  required WorkspaceGuard guard,
  required Future<bool> Function(FolderPick pick) onPick,
  ChatThread? moving,
}) {
  final repository = chat.workspaces;
  final loader = chat.workspaceCatalog();
  if (repository == null || loader == null) return Future.value();
  final profile = chat.profile ?? kDefaultProfile;
  final current = moving?.workingDirectory ?? moving?.folderPath;
  final picked = moving == null ? chat.workspaceChoice?.path : null;
  return showAdaptiveSheet<FolderPick>(
    context,
    builder: (sheet) {
      final platform = Theme.of(sheet).platform;
      final dialog =
          platform == TargetPlatform.macOS ||
          isWideLayout(sheet) ||
          MediaQuery.sizeOf(sheet).width > 640;
      final height = MediaQuery.sizeOf(sheet).height;
      return SizedBox(
        height: dialog
            ? (height - 96).clamp(320, 640).toDouble()
            : height * .94,
        child: _PickerSheet(
          create: () => WorkspacePickerController(
            repository: repository,
            loader: loader,
            profile: profile,
            current: current,
            picked: picked,
            telemetry: repository.telemetry,
          ),
          guard: guard,
          onPick: onPick,
        ),
      );
    },
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.create,
    required this.guard,
    required this.onPick,
  });

  /// Makes the controller once: a sheet's builder may run again.
  final WorkspacePickerController Function() create;
  final WorkspaceGuard guard;
  final Future<bool> Function(FolderPick pick) onPick;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _navigator = GlobalKey<NavigatorState>();
  var _taking = false;

  late final WorkspacePickerController _picker = widget.create();

  @override
  void initState() {
    super.initState();
    widget.guard.closed.addListener(_guardChanged);
  }

  @override
  void dispose() {
    widget.guard.closed.removeListener(_guardChanged);
    // The picker closes first, so an answer on its way is dropped.
    _picker
      ..close()
      ..dispose();
    super.dispose();
  }

  void _guardChanged() {
    if (!widget.guard.closed.value) return;
    _picker.close();
    _close();
  }

  void _close([FolderPick? result]) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _take(FolderPick? pick) async {
    if (pick == null || _taking) return;
    _taking = true;
    final close = await widget.onPick(pick);
    _taking = false;
    if (close) _close(pick);
  }

  void _push(WidgetBuilder builder) {
    _picker.clearScanOutcome();
    unawaited(
      _navigator.currentState?.push(MaterialPageRoute<void>(builder: builder)),
    );
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler(
    onPopWithResult: (_) => _navigator.currentState?.maybePop(),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => PopScope(
          // The first page has nothing to go back to: leaving it closes the
          // whole sheet.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: ListenableBuilder(
            listenable: _picker,
            builder: (context, _) => _pickerPage(context),
          ),
        ),
      ),
    ),
  );

  Widget _pickerPage(BuildContext context) {
    final picker = _picker;
    final l10n = context.l10n;
    final status = picker.status;
    return WorkspacePickerView(
      selectedId: picker.selectedId,
      serverDefault:
          picker.serverDefault ??
          WorkspacePickerRow(
            id: kPickerDefaultId,
            title: l10n.workspacesPickerDefaultUnknown,
            path: '',
          ),
      projects: picker.projects,
      recent: picker.recent,
      catalog: switch (status) {
        WorkspacePickerStatus.loading => WorkspacePickerCatalog.loading,
        WorkspacePickerStatus.partial ||
        WorkspacePickerStatus.failed => WorkspacePickerCatalog.projectsFailed,
        WorkspacePickerStatus.unknownProfile =>
          WorkspacePickerCatalog.unknownProfile,
        _ => WorkspacePickerCatalog.ready,
      },
      offline: picker.offline,
      browseLocked: picker.browseLocked,
      query: picker.query,
      scanAvailable: picker.scanAvailable,
      scanning: picker.scanning,
      scanOutcome: picker.scanOutcome,
      scanFound: picker.scanFound,
      onPick: (id) => unawaited(_take(picker.pick(id))),
      onBrowse: () {
        picker.startBrowse();
        _push((_) => _BrowsePage(picker: picker, onTake: _take));
      },
      onType: () => _push((_) => _TypePage(picker: picker, onTake: _take)),
      onTryAgain: picker.retryCatalog,
      onQueryChanged: picker.setQuery,
      onScan: () => unawaited(picker.scan()),
      onCancel: _close,
    );
  }
}

class _BrowsePage extends StatefulWidget {
  const _BrowsePage({required this.picker, required this.onTake});

  final WorkspacePickerController picker;
  final Future<void> Function(FolderPick? pick) onTake;

  @override
  State<_BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<_BrowsePage> {
  var _left = false;

  @override
  void initState() {
    super.initState();
    widget.picker.addListener(_changed);
  }

  @override
  void dispose() {
    widget.picker.removeListener(_changed);
    super.dispose();
  }

  /// The server only lets the app browse its own folders: Browse hides
  /// itself, so the page goes back to the list.
  void _changed() {
    if (_left || !widget.picker.browseLocked || !mounted) return;
    _left = true;
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.picker,
    builder: (context, _) {
      final picker = widget.picker;
      final current = picker.browsePath ?? ServerPath.tryParse('/')!;
      return FolderBrowserView(
        current: current,
        level: picker.browseLevel,
        rows: [
          for (final folder in picker.browseFolders)
            FileRowModel(
              name: folder.name,
              isFolder: true,
              path: ServerPath.tryParse(folder.path),
            ),
        ],
        onOpen: (row) {
          if (row.path != null) picker.openFolder(row.path!);
        },
        onOpenPath: picker.openFolder,
        onUp: picker.browseUp,
        onUse: () => unawaited(widget.onTake(picker.useBrowsed())),
        onTryAgain: picker.retryBrowse,
      );
    },
  );
}

class _TypePage extends StatelessWidget {
  const _TypePage({required this.picker, required this.onTake});

  final WorkspacePickerController picker;
  final Future<void> Function(FolderPick? pick) onTake;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: picker,
    builder: (context, _) => PathEntryView(
      text: picker.typedText,
      suggestions: picker.suggestions,
      capped: picker.suggestionsCapped,
      check: picker.check,
      autofocus: true,
      onChanged: picker.setTyped,
      onPickSuggestion: picker.takeSuggestion,
      onUse: () => unawaited(onTake(picker.useTyped())),
      onCheckAgain: picker.checkAgain,
    ),
  );
}
