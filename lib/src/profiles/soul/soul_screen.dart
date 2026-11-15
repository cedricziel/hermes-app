import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../l10n/l10n.dart';
import '../../api/hermes_repositories.dart';
import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../macos/mac_commands.dart';
import '../../macos/mac_window.dart';
import '../../server_care/connection_guard.dart';
import '../../server_care/widgets/private_surface.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../theme/breakpoints.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../tools/widgets/tools_target.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/motion_spinner.dart';
import '../../widgets/route_dismissal.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/state_message.dart';
import 'soul_availability.dart';
import 'soul_controller.dart';
import 'soul_repository.dart';
import 'soul_telemetry.dart';
import 'widgets/soul_changed_sheet.dart';
import 'widgets/soul_editor.dart';
import 'widgets/soul_questions.dart';
import 'widgets/soul_save_actions.dart';
import 'widgets/soul_status_line.dart';

/// The Personality page of one profile: the text of its SOUL.md, edited in one
/// field and replaced only after a question.
///
/// It is bound to [profile] when it opens: the name is in every request and in
/// the bar, and neither the chat's profile nor the server's active one
/// changes it. A [SoulController] it owns does the reading and the guarded
/// save; this widget only composes the plain widgets of `widgets/` from its
/// state and asks the questions:
///
/// - Save asks "Replace the personality of NAME?" and nothing is sent before
///   Replace; Cancel sends nothing.
/// - Revert, the bar's back, the Mac's View > Back and File > Close Window ask
///   "Discard changes?" while the text differs from the server's, with Keep
///   editing as the default.
/// - The editor is read-only while a read, the save or a Check runs.
/// - App Lock covering the app drops the text at once (the page shows its
///   loading state, no editor) and unlocking reads the file again; while the
///   app is inactive on a phone a blank surface stands in for the page.
/// - When the connection ends the app removes every pushed page (see
///   `navigation/connection_pages.dart`); [ConnectionGuard] only makes the
///   page drop its text a frame earlier.
///
/// On the Mac the page offers File > Save through its `MacCommandScope`,
/// enabled only while there is something to save and nothing runs.
class SoulScreen extends StatefulWidget {
  const SoulScreen({
    super.key,
    required this.profile,
    this.from = SoulOpenedFrom.sidebar,
  });

  /// The profile this page is bound to.
  final String profile;

  /// Where it was opened from, as the `profile_soul.opened` breadcrumb says.
  final SoulOpenedFrom from;

  @override
  State<SoulScreen> createState() => _SoulScreenState();
}

class _SoulScreenState extends State<SoulScreen> {
  late final SoulController _controller;
  final _text = SoulTextController();
  AppLockController? _lock;
  ConnectionGuard? _connection;
  var _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    final repositories = HermesRepositories.of(context);
    final availability = _maybe<SoulAvailability?>();
    _controller = SoulController(
      repository: SoulRepository(repositories.api.raw),
      profile: widget.profile,
      openedFrom: widget.from,
      telemetry: SoulTelemetry(
        repositories.telemetry,
        _maybe<Breadcrumbs>() ?? Breadcrumbs.none,
      ),
      onUnsupported: availability?.markUnsupported,
    )..addListener(_onController);
    _lock = _maybe<AppLockController>()?..addListener(_lockChanged);
    _connection = ConnectionGuard(_maybe<AuthController>(), _connectionEnded);
    if (_isCovered()) {
      _controller.cover();
    } else {
      unawaited(_controller.start());
    }
  }

  T? _maybe<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// A lock that cannot tell counts as covering: nothing is shown then.
  bool _isCovered() {
    try {
      return _lock?.covered ?? false;
    } on Object {
      return true;
    }
  }

  @override
  void dispose() {
    _connection?.dispose();
    _lock?.removeListener(_lockChanged);
    _controller
      ..removeListener(_onController)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  // -- What ends or hides the text --------------------------------------------

  void _lockChanged() {
    if (_isCovered()) {
      _closeAbove();
      _controller.cover();
    } else {
      _controller.uncover();
    }
  }

  void _connectionEnded() {
    _closeAbove();
    _controller.clear();
  }

  /// Closes what this page opened (a question, the changed sheet) without
  /// answering it: each answers as Cancel or Keep editing, which send
  /// nothing. The page itself stays; the app removes it when the connection
  /// ends.
  void _closeAbove() => scheduleMicrotask(() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive || route.isCurrent) return;
    Navigator.of(context).popUntil((r) => identical(r, route) || !r.isActive);
  });

  // -- The controller's side effects ------------------------------------------

  void _onController() {
    final text = _controller.text;
    if (_text.text != text) {
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (_controller.status == SoulStatus.changedOnServer && !_sheetOpen) {
      unawaited(_showChanged());
    }
  }

  Future<void> _showChanged() async {
    _sheetOpen = true;
    try {
      final choice = await showSoulChangedSheet(
        context,
        serverText: _controller.serverText ?? '',
        serverGone: _controller.serverExists == false,
        onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
      );
      // A cover, a sign-out or a reload may have moved the controller on: the
      // calls below do nothing unless the question is still open.
      if (!mounted) return;
      switch (choice) {
        case SoulChangedChoice.keepEditing:
          _controller.keepEditing();
        case SoulChangedChoice.replaceAnyway:
          await _controller.replaceAnyway();
      }
    } finally {
      _sheetOpen = false;
    }
  }

  // -- Asking -----------------------------------------------------------------

  Future<void> _save() async {
    final question = _controller.requestSave();
    if (question == null) return;
    final replace = await askReplaceSoul(
      context,
      profile: question.profile,
      empty: question.empty,
      pendingSaveNote: question.pendingSaveNote,
    );
    // Both calls do nothing unless the question is still the open one.
    if (!mounted) return;
    if (replace) {
      await _controller.confirmSave();
    } else {
      _controller.cancelSave();
    }
  }

  Future<bool> _discard() async {
    final discard = await askDiscardSoul(context, profile: widget.profile);
    return discard && mounted;
  }

  Future<void> _revert() async {
    if (_controller.dirty && !await _discard()) return;
    _controller.revert();
  }

  Future<void> _leave() async {
    if (await _discard() && mounted) dismissRoute(context);
  }

  /// File > Close Window while the text is unsaved: the window is hidden, not
  /// released, so a discarded text must really go.
  Future<void> _closeWindow() async {
    if (_controller.dirty && !await _discard()) return;
    _controller.revert();
    await MacWindow.close();
  }

  // -- Building ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final dirty = c.dirty;
      return PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_leave());
        },
        child: MacCommandScope(
          commands: {
            MacCommand.save: MacCommandHandler(c.canSave ? _save : null),
            if (dirty) MacCommand.closeWindow: MacCommandHandler(_closeWindow),
          },
          child: PrivateSurface(child: _scaffold(context)),
        ),
      );
    },
  );

  Widget _scaffold(BuildContext context) {
    final l10n = context.l10n;
    final c = _controller;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final wide = mac || isWideLayout(context);
    return SettingsScaffold(
      title: l10n.profilesSoulTitle,
      subtitle: widget.profile,
      formAction: wide || !c.showsEditor
          ? null
          : SoulSaveActions.barAction(
              context,
              dirty: c.dirty,
              busy: c.busy,
              onSave: _save,
            ),
      body: _body(context, wide: wide),
    );
  }

  Widget _body(BuildContext context, {required bool wide}) {
    final l10n = context.l10n;
    final c = _controller;
    Widget message(SoulBannerKind kind) => GroupedListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SoulStatusBanner(kind: kind, onAction: c.reload),
        ),
      ],
    );
    if (c.closed || c.covered) return const _Loading();
    switch (c.load) {
      case SoulLoad.loading:
        return const _Loading();
      case SoulLoad.offline:
        return message(SoulBannerKind.offline);
      case SoulLoad.failed:
        return message(SoulBannerKind.readFailed);
      case SoulLoad.profileGone:
        return StateMessage(
          title: l10n.profilesSoulGoneTitle,
          detail: l10n.profilesSoulGoneDetail,
        );
      case SoulLoad.unsupported:
        return StateMessage(
          title: l10n.profilesSoulUnsupportedTitle,
          detail: l10n.profilesSoulUnsupportedDetail,
          action: OutlinedButton(
            onPressed: () => dismissRoute(context),
            // The platform's minimum target: 44 pt, 48 dp, 28 pt on a Mac.
            style: toolsButtonStyle(context),
            child: Text(l10n.profilesSoulUnsupportedBack),
          ),
        );
      case SoulLoad.loaded:
      case SoulLoad.notSet:
        return _editorPage(context, wide: wide);
    }
  }

  SoulBannerKind? _banner() => switch (_controller.status) {
    SoulStatus.saveFailed => SoulBannerKind.saveFailed,
    SoulStatus.lostAnswer => SoulBannerKind.lostAnswer,
    SoulStatus.checking => SoulBannerKind.checking,
    SoulStatus.lostCheckFailed => SoulBannerKind.checkFailed,
    SoulStatus.saveCheckFailed => SoulBannerKind.saveCheckFailed,
    _ => null,
  };

  VoidCallback? _bannerAction() => switch (_controller.status) {
    SoulStatus.lostAnswer || SoulStatus.lostCheckFailed => _controller.check,
    SoulStatus.saveCheckFailed => () => unawaited(_controller.confirmSave()),
    _ => null,
  };

  SoulStatusKind? _statusLine() => switch (_controller.status) {
    SoulStatus.saved => SoulStatusKind.saved,
    SoulStatus.earlierText => SoulStatusKind.earlierText,
    SoulStatus.verifying || SoulStatus.saving => SoulStatusKind.saving,
    _ => null,
  };

  Widget _editorPage(BuildContext context, {required bool wide}) {
    final l10n = context.l10n;
    final c = _controller;
    final metrics = GroupedMetrics.of(context);
    final banner = _banner();
    final status = _statusLine();
    return GroupedListView(
      children: [
        if (banner != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SoulStatusBanner(kind: banner, onAction: _bannerAction()),
          ),
        const SizedBox(height: 8),
        SoulEditor(
          controller: _text,
          profile: widget.profile,
          fileExists: c.exists,
          readOnly: c.readOnly,
          maxLines: 30,
          onChanged: c.setText,
        ),
        if (status != null) SoulStatusLine(kind: status),
        const SizedBox(height: 8),
        if (wide)
          SoulSaveActions(
            dirty: c.dirty,
            busy: c.busy,
            onSave: _save,
            onRevert: () => unawaited(_revert()),
          )
        else
          SoulSaveActions.revertRow(
            dirty: c.dirty,
            busy: c.busy,
            onRevert: () => unawaited(_revert()),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            16,
            metrics.rowPadding,
            16,
          ),
          child: Text(
            l10n.profilesSoulFootnote,
            style: TextStyle(
              fontSize: metrics.footerSize,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ],
    );
  }
}

/// A centred spinner with "Loading personality…": no editor yet.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.profilesSoulLoading,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MotionSpinner(),
            const SizedBox(height: 12),
            Text(
              context.l10n.profilesSoulLoading,
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          ],
        ),
      ),
    ),
  );
}
