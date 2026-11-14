import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../api/hermes_repositories.dart';
import '../app_lock/app_lock_controller.dart';
import '../telemetry/breadcrumbs.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/adaptive_dialog.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart';
import 'care_result.dart';
import 'secure_window.dart';
import 'server_care_controller.dart';
import 'server_care_repository.dart';
import 'server_logs_controller.dart';
import 'widgets/private_surface.dart';
import 'widgets/server_logs_body.dart';

/// The tabs, left to right: Errors first, as it is what a person in trouble
/// wants.
const _tabOrder = [CareLogFile.errors, CareLogFile.agent, CareLogFile.gateway];

/// "What did Hermes say just before something went wrong?": the lines of
/// one log file, newest first, with a level and a search.
///
/// Log lines can hold anything, so the page keeps them in memory only,
/// marks the Android window secure while it is on screen, draws a blank
/// surface while the app is inactive on a phone, and drops the lines when
/// App Lock covers the app.
class ServerLogsPage extends StatefulWidget {
  const ServerLogsPage({super.key, this.initialFile = CareLogFile.errors});

  /// The file shown first.
  final CareLogFile initialFile;

  @override
  State<ServerLogsPage> createState() => _ServerLogsPageState();
}

class _ServerLogsPageState extends State<ServerLogsPage>
    with SingleTickerProviderStateMixin {
  late final ServerCareController _care;
  late final ServerLogsController _controller;
  late final TabController _tabs;
  AppLockController? _appLock;
  void Function()? _releaseSecure;
  String? _careProfile;

  @override
  void initState() {
    super.initState();
    _care = context.read<ServerCareController>();
    _careProfile = _care.profile;
    _appLock = _maybeRead<AppLockController>();
    _controller = ServerLogsController(
      repository: HermesRepositories.of(context).serverCare,
      profile: _careProfile,
      file: widget.initialFile,
      covered: () => _appLock?.covered ?? false,
      onUnsupported: _logsMissing,
      lookupFailed: () => _care.profileLookupFailed,
    );
    _tabs = TabController(
      length: _tabOrder.length,
      vsync: this,
      initialIndex: _tabOrder.indexOf(widget.initialFile),
    )..addListener(_tabChanged);
    _care.addListener(_followChatProfile);
    _appLock?.addListener(_lockChanged);
    _releaseSecure = SecureWindow.instance.hold();
    // Only the file: no profile, no lines, no search.
    (_maybeRead<Breadcrumbs>() ?? Breadcrumbs.none)('server_care.logs.opened', {
      'file': widget.initialFile.name,
    });
    if (_appLock?.covered ?? false) {
      _controller.cover();
    } else {
      _controller.load();
    }
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The server has no logs route: a page opened from the Server screen
  /// closes rather than explain a missing part.
  void _logsMissing() {
    _care.reportUnsupported(CarePart.logs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _tabChanged() {
    _controller.setFile(_tabOrder[_tabs.index]);
  }

  void _lockChanged() {
    if (_appLock?.covered ?? false) {
      _controller.cover();
    } else {
      _controller.uncover();
    }
  }

  /// The chat switched profile while the page was open.
  void _followChatProfile() {
    if (_care.profile == _careProfile) {
      if (_care.profile == null && _care.profileLookupFailed) {
        _controller.load();
      }
      return;
    }
    _careProfile = _care.profile;
    _controller.setProfile(_careProfile);
  }

  @override
  void dispose() {
    _releaseSecure?.call();
    _appLock?.removeListener(_lockChanged);
    _care.removeListener(_followChatProfile);
    _tabs
      ..removeListener(_tabChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.serverCareLogsCopyTitle,
      message: l10n.serverCareLogsCopyMessage,
      confirmLabel: l10n.serverCareLogsCopyConfirm,
      cancelLabel: l10n.serverCareCancel,
      cancelIsDefault: true,
    );
    if (!confirmed || !mounted) return;
    // Exactly the lines on screen, in the order shown.
    final text = [
      for (final entry in _controller.entries) ...[
        entry.raw,
        ...entry.continuation,
      ],
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(SnackBar(content: Text(l10n.serverCareLogsCopied)));
  }

  SettingsSubtitleMenu<String>? _profileMenu(AppLocalizations l10n) {
    final profile = _controller.profile;
    final profiles = _care.status?.profiles ?? const <String>[];
    if (profile == null || profiles.length < 2) return null;
    return SettingsSubtitleMenu<String>(
      label: l10n.serverCareProfile,
      onSelected: _controller.setProfile,
      itemBuilder: (_) => [
        for (final p in profiles)
          CheckedPopupMenuItem(value: p, checked: p == profile, child: Text(p)),
      ],
    );
  }

  ServerLogsStatus _status(ServerLogsController c) {
    final failure = c.failure;
    if (failure != null) {
      return switch (failure) {
        CareFailureKind.offline => ServerLogsStatus.offline,
        CareFailureKind.refused => ServerLogsStatus.refused,
        _ => ServerLogsStatus.failed,
      };
    }
    if (!c.answered) return ServerLogsStatus.loading;
    if (c.entries.isEmpty) {
      return c.filtered ? ServerLogsStatus.noMatch : ServerLogsStatus.empty;
    }
    return ServerLogsStatus.ready;
  }

  @override
  Widget build(BuildContext context) => PrivateSurface(
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _scaffold(context),
    ),
  );

  Widget _scaffold(BuildContext context) {
    final l10n = context.l10n;
    final c = _controller;
    final profile = c.profile;
    final canCopy = c.entries.isNotEmpty;
    final body = ServerLogsBody(
      status: _status(c),
      entries: c.entries,
      level: c.level,
      onLevel: c.setLevel,
      refusedMessage: c.failureMessage,
      canShowOlder: c.canShowOlder,
      lastLinesCount: c.reachedLimit ? ServerLogsController.olderLines : null,
      onShowOlder: c.showOlder,
      onClearFilters: c.clearFilters,
      onRetry: profile == null ? _care.refresh : c.load,
    );
    return SettingsScaffold(
      title: l10n.serverCareLogsTitle,
      subtitle: profile == null ? null : l10n.serverCareLogsSubtitle(profile),
      subtitleMenu: _profileMenu(l10n),
      previousTitle: l10n.serverCareTitle,
      tabController: _tabs,
      tabs: [
        l10n.serverCareLogsFileErrors,
        l10n.serverCareLogsFileAgent,
        l10n.serverCareLogsFileGateway,
      ],
      search: SettingsSearch(
        query: c.search,
        onChanged: c.setSearch,
        hint: l10n.serverCareLogsSearchHint,
      ),
      actions: [
        SettingsBarAction(
          key: const Key('logs-refresh'),
          label: l10n.serverCareRefresh,
          icon: AppIcons.refresh,
          onPressed: c.loading ? null : c.load,
        ),
        SettingsBarAction.menu(
          key: const Key('logs-more'),
          label: l10n.serverCareLogsMore,
          icon: AppIcons.more,
          menu: (_) => [
            PopupMenuItem<void>(
              enabled: canCopy,
              onTap: _copy,
              child: Text(l10n.serverCareLogsCopy),
            ),
          ],
        ),
      ],
      // The Mac has the Refresh button; a pull is for touch.
      body: platformChromeOf(context) == PlatformChrome.macos
          ? body
          : RefreshIndicator(onRefresh: c.load, child: body),
    );
  }
}
