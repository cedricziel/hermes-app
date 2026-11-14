import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../chat/media/media_store.dart';
import '../chat/widgets/quick_look_target.dart';
import '../drag_out/drag_out_item.dart';
import '../drag_out/drag_out_source.dart';
import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../theme/platform_chrome.dart';
import '../widgets/settings_scaffold.dart';
import 'files_controller.dart';
import 'files_models.dart';
import 'files_platform_policy.dart';
import 'files_preview_page.dart';
import 'files_source.dart';
import 'files_state.dart';
import 'files_telemetry.dart';
import 'files_view_models.dart';
import 'server_path.dart';
import 'widgets/file_path_bar.dart';
import 'widgets/file_row.dart';
import 'widgets/files_browser_view.dart';
import 'widgets/files_page_menu.dart';
import 'widgets/files_questions.dart';

/// Shares a file with the system's share sheet; [origin] is where an iPad
/// anchors its popover.
typedef ShareFile = Future<void> Function(File file, Rect? origin);

/// The Files page of one chat: its working folder, a path bar, the list and
/// the preview. On a phone the list is a page and the preview is pushed over
/// it; from 700 pt on an iPad and 900 pt elsewhere they sit side by side.
///
/// It belongs to one chat, one profile and one connection. It ends itself,
/// cancelling its requests and downloads, when [closeWhen] says the chat or
/// its profile changed, when the session or server changes, and when App
/// Lock locks. Every control here is a widget of `widgets/`; the controller's
/// state reaches them through `files_view_models.dart`.
class FilesScreen extends StatefulWidget {
  const FilesScreen({
    super.key,
    required this.source,
    required this.media,
    required this.profile,
    this.cwd,
    this.from = FilesOpenedFrom.activity,
    this.telemetry,
    this.closeWhen,
    this.shouldClose,
    this.share,
    this.policy,
    this.previousTitle,
  });

  final FilesSource source;
  final MediaStore media;
  final String profile;

  /// The chat's stored folder; without one the page starts at the server's
  /// `default-cwd` for [profile].
  final ServerPath? cwd;
  final FilesOpenedFrom from;
  final FilesTelemetry? telemetry;

  /// Changes when the chat in front may have changed; with [shouldClose] it
  /// ends the page.
  final Listenable? closeWhen;
  final bool Function()? shouldClose;

  /// Null where the platform has no share sheet (desktop).
  final ShareFile? share;
  final FilesPlatformPolicy? policy;
  final String? previousTitle;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late final FilesController _controller;
  AuthController? _auth;
  int? _ownerGeneration;
  String? _server;
  AppLockController? _lock;
  Route<void>? _previewRoute;
  int? _askedSerial;
  var _wide = false;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = FilesController(
      source: widget.source,
      media: widget.media,
      profile: widget.profile,
      cwd: widget.cwd,
      openedFrom: widget.from,
      telemetry: widget.telemetry,
      policy: widget.policy ?? const FilesPlatformPolicy.none(),
      share: widget.share == null
          ? null
          : (file) => widget.share!(file, _shareOrigin()),
    )..addListener(_onController);
    widget.closeWhen?.addListener(_checkClose);
    _auth = _maybe<AuthController>();
    _ownerGeneration = _auth?.ownerGeneration;
    _server = _auth?.baseUrl;
    _auth?.addListener(_checkSession);
    _lock = _maybe<AppLockController>();
    _lock?.addListener(_checkLock);
    unawaited(_controller.start());
  }

  T? _maybe<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    widget.closeWhen?.removeListener(_checkClose);
    _auth?.removeListener(_checkSession);
    _lock?.removeListener(_checkLock);
    _controller
      ..removeListener(_onController)
      ..dispose();
    super.dispose();
  }

  // -- Ending the page --------------------------------------------------------

  void _checkClose() {
    if (widget.shouldClose?.call() ?? false) _close();
  }

  void _checkSession() {
    final auth = _auth;
    if (auth == null) return;
    if (auth.ownerGeneration != _ownerGeneration ||
        auth.baseUrl != _server ||
        !auth.protectedRequestsAllowed) {
      _close();
    }
  }

  void _checkLock() {
    if (_lock?.locked ?? false) _close();
  }

  /// Cancels everything at once and removes the page, and the preview over
  /// it, once the current frame is done: a listener may fire while the tree is
  /// building.
  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _controller.cancelAll();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final preview = _previewRoute;
    _previewRoute = null;
    scheduleMicrotask(() {
      if (route == null || !route.isActive) return;
      // What is open above the page (a question, the … menu, the preview) goes
      // first; a dialog then answers as dismissed.
      navigator.popUntil((r) => identical(r, route) || !r.isActive);
      if (preview != null && preview.isActive) navigator.removeRoute(preview);
      if (route.isActive) navigator.removeRoute(route);
    });
  }

  // -- The controller's side effects -----------------------------------------

  void _onController() {
    final preview = _controller.preview;
    // Each question has its own serial: the same const state asked twice is
    // two questions.
    final serial = _controller.questionSerial;
    if (serial != _askedSerial) {
      if (preview is PreviewConfirmSecret) {
        _askedSerial = serial;
        unawaited(_askSecret());
      } else if (preview is PreviewConfirmSize) {
        _askedSerial = serial;
        unawaited(_askSize(preview.bytes));
      }
    }
    _syncPreviewPage();
  }

  Future<void> _askSecret() async {
    final entry = _controller.selected;
    if (entry == null || !mounted) return;
    final ok = await askOpenSecretFile(context, entry.path.name);
    if (!mounted) return;
    if (ok) {
      unawaited(_controller.confirmSecret());
    } else {
      _controller.declineSecret();
    }
  }

  Future<void> _askSize(int bytes) async {
    if (!mounted) return;
    final ok = await askDownloadLargeFile(context, bytes);
    if (!mounted) return;
    if (ok) {
      unawaited(_controller.confirmSize());
    } else {
      _controller.declineSize();
    }
  }

  /// On a phone the preview is a page over the list: pushed once a file is
  /// being shown, removed when none is selected.
  void _syncPreviewPage() {
    if (!mounted || _closing) return;
    final preview = _controller.preview;
    final wants =
        !_wide &&
        _controller.selected != null &&
        preview is! PreviewIdle &&
        preview is! PreviewConfirmSecret;
    final route = _previewRoute;
    if (wants && route == null) {
      _pushPreview();
    } else if ((!wants && _controller.selected == null || _wide) &&
        route != null) {
      _previewRoute = null;
      if (route.isActive) Navigator.of(context).removeRoute(route);
    }
  }

  void _pushPreview() {
    Widget page(BuildContext _) => FilesPreviewPage(
      controller: _controller,
      actions: _actions(),
      platformActions: _platformActions(),
      previousTitle: folderTitleOf(_controller, context.l10n.filesEntryLabel),
    );
    // Reduced motion: no transition from the list to the preview.
    final Route<void> route = MediaQuery.disableAnimationsOf(context)
        ? PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => page(context),
          )
        : MaterialPageRoute<void>(builder: page);
    _previewRoute = route;
    unawaited(
      Navigator.of(context).push(route).then((_) {
        // Back from the preview: a file fetched after the secret question
        // goes, and the list is the page again.
        if (identical(_previewRoute, route)) {
          _previewRoute = null;
          _controller.closePreview();
        }
      }),
    );
  }

  // -- Actions ---------------------------------------------------------------

  bool get _ios => Theme.of(context).platform == TargetPlatform.iOS;

  bool get _mac => platformChromeOf(context) == PlatformChrome.macos;

  FilesPlatformActions _platformActions() {
    final entry = _controller.selected;
    return FilesPlatformActions(
      share: widget.share != null,
      openWith: !_ios && entry != null && _controller.canOpenWith(entry),
    );
  }

  FilesPreviewActions _actions() {
    final platform = _platformActions();
    return FilesPreviewActions(
      save: () => unawaited(_save()),
      reload: () => unawaited(_controller.reload()),
      tryAgain: () => unawaited(_controller.retry()),
      cancelDownload: _controller.cancelDownload,
      downloadFull: () => unawaited(_save()),
      open: () => unawaited(_openPrimary()),
      share: platform.share ? () => unawaited(_controller.shareFile()) : null,
      openWith: platform.openWith
          ? () => unawaited(_controller.openWith())
          : null,
      quickLook: _mac
          ? () => unawaited(_controller.quickLook(toggle: true))
          : null,
    );
  }

  /// A PDF's Open: Quick Look on a Mac, the system's app elsewhere, and Save
  /// where the app may not be opened (a type Windows would run).
  Future<void> _openPrimary() {
    if (_mac) return _controller.quickLook();
    final entry = _controller.selected;
    if (entry != null && !_controller.canOpenWith(entry)) return _save();
    return _controller.openWith();
  }

  Future<void> _save() async {
    await _controller.save();
    final name = _controller.takeSavedName();
    if (name != null && mounted) showFilesSaved(context, name);
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset(box.size.width - 56, 0));
    return origin & const Size(44, 44);
  }

  void _menuChoice(FilesMenuChoice choice) {
    switch (choice) {
      case FilesMenuChoice.copyPath:
        final folder = _controller.folder;
        if (folder != null) {
          unawaited(Clipboard.setData(ClipboardData(text: folder.value)));
        }
      case FilesMenuChoice.toggleHidden:
        _controller.toggleHidden();
      case FilesMenuChoice.refresh:
        unawaited(_controller.refresh());
      case FilesMenuChoice.about:
        unawaited(showFilesAboutList(context));
    }
  }

  FsEntry? _entryFor(FileRowModel row) {
    final path = row.path;
    if (path == null) return null;
    for (final entry in _controller.shownEntries) {
      if (entry.path == path) return entry;
    }
    return null;
  }

  void _openRow(FileRowModel row) {
    final entry = _entryFor(row);
    if (entry != null) unawaited(_controller.select(entry));
  }

  /// Space on a Mac row: the file is selected (shown) and then in Quick Look.
  Future<void> _quickLookRow(FsEntry entry) async {
    if (_controller.selected?.path != entry.path) {
      await _controller.select(entry);
    }
    await _controller.quickLook(toggle: true);
  }

  Widget _wrapRow(BuildContext context, FileRowModel row, Widget child) {
    final l10n = context.l10n;
    final entry = _entryFor(row);
    if (entry == null) return child;
    final isFile = !entry.isDirectory;
    return QuickLookTarget(
      onOpen: () => unawaited(_controller.select(entry)),
      onToggle: isFile ? () => unawaited(_quickLookRow(entry)) : null,
      onShow: isFile ? () => unawaited(_quickLookRow(entry)) : null,
      onSave: isFile
          ? () => unawaited(_controller.select(entry).then((_) => _save()))
          : null,
      child: isFile
          ? DragOut(
              kind: DragOutKind.file,
              item: () =>
                  filesDragItem(_controller, entry, l10n.filesDragFallbackName),
              child: child,
            )
          : child,
    );
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final folder = _controller.folder;
        final mac = _mac;
        final scaffold = SettingsScaffold(
          title: folderTitleOf(_controller, l10n.filesEntryLabel),
          previousTitle: widget.previousTitle,
          actions: [
            if (mac)
              SettingsBarAction(
                label: l10n.filesActionRefresh,
                icon: AppIcons.refresh,
                shortcut: '⌘R',
                onPressed: () => unawaited(_controller.refresh()),
              ),
            if (folder != null)
              SettingsBarAction.menu(
                label: l10n.filesMenuMore,
                icon: AppIcons.more,
                menu: (context) => filesPageMenuItems(
                  context,
                  path: folder,
                  showHidden: _controller.showHidden,
                  onChoice: _menuChoice,
                ),
              ),
          ],
          body: _body(context),
        );
        final guarded = PopScope(
          // Android's back goes up a folder before it leaves the page.
          canPop:
              platformChromeOf(context) != PlatformChrome.material ||
              !_controller.canGoUp,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_controller.up());
          },
          child: scaffold,
        );
        if (!mac) return guarded;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () =>
                unawaited(_controller.up()),
            const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
                unawaited(_controller.refresh()),
          },
          child: guarded,
        );
      },
    );
  }

  Widget _body(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = isWideLayout(context, width: box.maxWidth);
      if (wide != _wide) {
        _wide = wide;
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreviewPage());
      }
      final folder = _controller.folder;
      final listWidth = (box.maxWidth * 0.4).clamp(300.0, 420.0);
      return Column(
        children: [
          if (folder != null)
            FilePathBar(
              current: folder,
              highest: _controller.root,
              showUp: wide,
              onUp: _controller.canGoUp
                  ? () => unawaited(_controller.up())
                  : null,
              onOpen: (path) => unawaited(_controller.openPath(path)),
            ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      SizedBox(width: listWidth, child: _list()),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: FilesPreviewPane(
                          controller: _controller,
                          actions: _actions(),
                          platformActions: _platformActions(),
                        ),
                      ),
                    ],
                  )
                : _list(),
          ),
        ],
      );
    },
  );

  Widget _list() {
    final browser = FilesBrowserView(
      state: folderViewStateOf(_controller),
      selected: _controller.selected?.path,
      onOpen: _openRow,
      onTryAgain: () => unawaited(_controller.refresh()),
      onRefresh: () => unawaited(_controller.refresh()),
      onShowHidden: _controller.toggleHidden,
      onUp: () => unawaited(_controller.up()),
      onGoBack: () {
        final root = _controller.root;
        if (root != null) unawaited(_controller.openPath(root));
      },
      wrapRow: quickLookTargetsAt(context) ? _wrapRow : null,
    );
    if (_mac) return browser;
    return RefreshIndicator.adaptive(
      onRefresh: _controller.refresh,
      child: browser,
    );
  }
}
