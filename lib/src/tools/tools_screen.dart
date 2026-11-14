import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../theme/platform_chrome.dart';
import '../widgets/app_banner.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'computer_use_panel.dart';
import 'hermes_tools_repository.dart';
import 'terminal_backends_panel.dart';
import 'toolset_copy.dart';
import 'toolset_installs.dart';
import 'toolset_setup_panel.dart';
import 'tools_asker.dart';
import 'tools_availability.dart';
import 'tools_controller.dart';
import 'tools_models.dart';
import 'tools_panel_env.dart';
import 'tools_row_mapping.dart';
import 'tools_setup_registry.dart';
import 'widgets/toolset_detail_body.dart';
import 'widgets/toolset_row.dart';
import 'widgets/tools_confirmation.dart';
import 'widgets/tools_difference_sheet.dart';
import 'widgets/tools_list_footer.dart';
import 'widgets/tools_target.dart';

export 'tools_panel_env.dart'
    show ToolsBotScreenLink, ToolsLinkLauncher, toolsOnDesktop;

/// The width of the list when the detail sits beside it.
const double _listPaneWidth = 420;

/// Lists the toolsets of one profile, switches them on and off, and shows a
/// toolset's details. Below [kWideLayoutBreakpoint] a tapped row opens its
/// details as a page; from there up they sit beside the list.
///
/// The profile is [repository]'s, named in the header and sent with every
/// call; opening the screen never changes the server's active profile. When
/// [availability] has rows for that profile they are the first data, and the
/// list is still read again. A switch that asks first (a risky toolset, or
/// one that can start an installer) sends nothing until the question is
/// answered, and App Lock engaging cancels an open question.
///
/// The details of a toolset hold its setup (providers, keys, install, model),
/// and Terminal and Computer use add their own sections; see
/// `toolset_setup_panel.dart`, `terminal_backends_panel.dart` and
/// `computer_use_panel.dart`. Keys typed there are cleared when the screen
/// closes, App Lock locks and the profile changes. The install step runs on the connection's
/// [ToolsetInstalls] (provided by the shell; the screen makes its own when
/// there is none) and survives leaving the screen.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.repository,
    this.availability,
    this.onProfileGone,
    this.installs,
    this.botScreen,
    this.launchLink = launchToolsLink,
  });

  final HermesToolsRepository repository;

  /// Where the shell's first read of this profile's list comes from.
  final ToolsAvailability? availability;

  /// Called once when the server says the profile no longer exists, so the
  /// caller reads the profile list again.
  final VoidCallback? onProfileGone;

  /// The connection's install follower; null reads it from the provider, and
  /// when there is none the screen makes its own.
  final ToolsetInstalls? installs;

  /// The profile's Bot Screen, for "Open the bot's screen" in the Computer
  /// use details. Null where the caller has none: the row is then absent.
  final ToolsBotScreenLink? botScreen;

  /// Opens a "Get a key" page in the system browser.
  final ToolsLinkLauncher launchLink;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late ToolsController _controller;
  AppLockController? _lock;
  String? _selected;
  var _asking = false;

  /// The open question's route and the navigator it is on, to take it down
  /// when the screen goes or the question is cancelled from outside.
  Route<dynamic>? _questionRoute;
  NavigatorState? _questionNavigator;
  var _goneReported = false;
  late ToolsetInstalls _installs;
  var _ownsInstalls = false;
  late ToolsAsker _asker;
  final _panelRefresh = ToolsRefresh();
  late final ToolsSetupRegistry _registry;
  final _pages = <Route<void>>[];
  AuthController? _auth;
  int? _authGeneration;
  String? _followedInstall;

  @override
  void initState() {
    super.initState();
    _controller = _newController();
    unawaited(_controller.load());
    _lock = _maybeRead<AppLockController>()?..addListener(_onLock);
    _watchAuth();
    final provided = widget.installs ?? _maybeRead<ToolsetInstalls>();
    _ownsInstalls = provided == null;
    _installs =
        provided ??
        ToolsetInstalls(
          requestReread: (_) => unawaited(_controller.load()),
          telemetry: widget.repository.telemetry,
        );
    _asker = ToolsAsker(context: () => context, lock: _lock);
    _registry = ToolsSetupRegistry(
      repository: widget.repository,
      confirmLocal: () => _asker.ask(toolsetLocalBackendQuestion(context.l10n)),
      confirmGrant: () => _asker.ask(toolsetAllowAccessQuestion(context.l10n)),
      onWritten: () => unawaited(_controller.load()),
      onBusyChanged: (name, {required busy}) =>
          _controller.setSetupBusy(name, busy: busy),
    );
  }

  ToolsController _newController() => ToolsController(
    widget.repository,
    telemetry: widget.repository.telemetry,
    initial:
        widget.availability?.rowsFor(widget.repository.profile) ?? const [],
  )..addListener(_onChanged);

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void didUpdateWidget(ToolsScreen old) {
    super.didUpdateWidget(old);
    if (old.repository.profile != widget.repository.profile) {
      // Answers on their way for the old profile are dropped, and an open
      // question for it is cancelled.
      _selected = null;
      _goneReported = false;
      // Cancel first, so the question for the old profile goes with it.
      _controller.cancel();
      // A setup question and the details pages for the old profile go with it.
      _asker.cancel();
      _closePages();
      // Building now: the listeners (the details page above this screen
      // included) are told, and the list read, after the frame.
      _controller.switchProfile(widget.repository, notify: false);
      _followedInstall = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // The setup controllers notify their panels, so not while building.
        _registry.switchProfile(widget.repository);
        _controller.announce();
        unawaited(_controller.load());
      });
    }
  }

  /// Signing out or moving to another server drops every typed key of the
  /// open details. Closing the screen is not this screen's job.
  void _watchAuth() {
    final auth = _maybeRead<AuthController>();
    if (auth == null) return;
    _auth = auth;
    _authGeneration = auth.ownerGeneration;
    auth.addListener(_onAuth);
  }

  void _onAuth() {
    final auth = _auth;
    if (auth == null) return;
    if (auth.state != HermesConnectionState.ready ||
        auth.ownerGeneration != _authGeneration) {
      _panelRefresh.clearAll();
      _registry.clearKeys();
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuth);
    _lock?.removeListener(_onLock);
    _takeQuestionDown();
    _asker.dispose();
    _registry.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    if (_ownsInstalls) _installs.dispose();
    super.dispose();
  }

  /// App Lock covering the app dismisses an open question as cancelled.
  void _onLock() {
    if (_lock?.covered ?? false) _controller.cancel();
  }

  void _onChanged() {
    if (!mounted) return;
    final question = _controller.confirmation;
    if (question != null && !_asking) {
      if (_lock?.covered ?? false) {
        // App Lock came while the setup was being read: nothing is asked
        // behind the lock screen.
        _controller.cancel();
      } else {
        unawaited(_ask(question));
      }
    } else if (question == null && _asking) {
      // Cancelled from outside (App Lock, a profile switch): take the dialog
      // down too.
      _takeQuestionDown();
    }
    if (_controller.loadState == ToolsLoadState.profileGone && !_goneReported) {
      _goneReported = true;
      widget.onProfileGone?.call();
    }
    _followSwitchStarted();
  }

  /// An installer Hermes started because a switch turned a toolset on is
  /// followed from the moment the answer arrives, whether or not the user
  /// taps Show.
  void _followSwitchStarted() {
    final key = _controller.postSetupStarted;
    if (key == null) {
      _followedInstall = null;
      return;
    }
    final toolset = _controller.postSetupToolset;
    final id = '$toolset/$key';
    if (_followedInstall == id) return;
    // Only remembered when the follow started: while another install runs it
    // did not, and a later change may try again.
    if (_installs.followSwitchStarted(
      widget.repository,
      key,
      toolset: toolset,
    )) {
      _followedInstall = id;
    }
  }

  /// Removes the open question's route, after the frame: the caller may be
  /// building or unmounting, where the navigator cannot change.
  void _takeQuestionDown() {
    final route = _questionRoute;
    final navigator = _questionNavigator;
    _questionRoute = null;
    _questionNavigator = null;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  Future<void> _ask(ToolsConfirmation question) async {
    final l10n = context.l10n;
    final toolset = question.toolset;
    final text =
        toolsetConfirmQuestion(
          l10n,
          toolset.name,
          _controller.profile,
          installsSoftware: question.installsSoftware,
        ) ??
        toolsetInstallQuestion(l10n, toolsetName(l10n, toolset));
    _asking = true;
    _questionNavigator = Navigator.of(context, rootNavigator: true);
    final confirmed = await showToolsetConfirmation(
      context,
      text,
      onRoute: (route) => _questionRoute = route,
    );
    _asking = false;
    _questionRoute = null;
    _questionNavigator = null;
    if (!mounted) return;
    if (confirmed) {
      unawaited(_controller.confirm());
    } else {
      _controller.cancel();
    }
  }

  void _switch(String name, bool on) {
    if (_controller.toolVanished) _controller.dismissVanished();
    unawaited(_controller.requestSwitch(name, enabled: on));
  }

  Future<void> _refresh() {
    if (_controller.toolVanished) _controller.dismissVanished();
    return _controller.load();
  }

  void _open(Toolset toolset) {
    if (isWideLayout(context)) {
      setState(() => _selected = toolset.name);
      return;
    }
    // The page keeps the profile it was opened for, so it goes when the
    // profile changes; a page for another profile would show (and keep typed
    // keys of) the old one.
    final route = MaterialPageRoute<void>(
      builder: (_) => _ToolsetPage(
        controller: _controller,
        name: toolset.name,
        onSwitch: _switch,
        env: _env(),
      ),
    );
    _pages.add(route);
    unawaited(
      Navigator.of(context)
          .push(route)
          .whenComplete(() => _pages.remove(route)),
    );
  }

  /// Closes the details pages that are open, after the frame.
  void _closePages() {
    final routes = [..._pages];
    _pages.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        if (route.isActive && route.navigator != null) {
          route.navigator!.removeRoute(route);
        }
      }
    });
  }

  /// What the details' panels share, for the profile the screen shows now.
  ToolsPanelEnv _env() => ToolsPanelEnv(
    repository: widget.repository,
    installs: _installs,
    ask: _asker.ask,
    launchLink: widget.launchLink,
    refresh: _panelRefresh,
    botScreen: widget.botScreen,
    lock: _lock,
    registry: _registry,
    onWritten: () => unawaited(_controller.load()),
  );

  /// "Show" on the installer banner: the details of the toolset whose switch
  /// started it.
  void _showInstalling() {
    final name = _controller.postSetupToolset;
    final toolset = _controller.toolsets
        .where((t) => t.name == name)
        .firstOrNull;
    _controller.clearPostSetupStarted();
    if (toolset != null) _open(toolset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final on = _controller.toolsets.where((t) => t.enabled).length;
        // What a server without the routes, or a deleted profile, once
        // listed is not counted any more.
        final counted =
            _controller.hasLoaded &&
            _controller.loadState != ToolsLoadState.unsupported &&
            _controller.loadState != ToolsLoadState.profileGone;
        return SettingsScaffold(
          title: l10n.toolsTitle,
          subtitle: counted
              ? l10n.toolsSubtitle(_controller.profile, on)
              : _controller.profile,
          body: _body(context),
        );
      },
    );
  }

  Widget _back(BuildContext context) => OutlinedButton(
    onPressed: () => Navigator.of(context).maybePop(),
    style: toolsButtonStyle(context),
    child: Text(MaterialLocalizations.of(context).backButtonTooltip),
  );

  Widget _tryAgain(BuildContext context) => TextButton(
    onPressed: _controller.load,
    child: Text(context.l10n.toolsTryAgain),
  );

  Widget _tryAgainOutlined(BuildContext context) => OutlinedButton(
    onPressed: _controller.load,
    style: toolsButtonStyle(context),
    child: Text(context.l10n.toolsTryAgain),
  );

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final state = _controller.loadState;
    if (state == ToolsLoadState.unsupported) {
      return StateMessage(
        title: l10n.toolsOldServerTitle,
        detail: l10n.toolsOldServerDetail,
        action: _back(context),
      );
    }
    if (state == ToolsLoadState.profileGone) {
      return StateMessage(title: l10n.toolsProfileGone, action: _back(context));
    }
    if (!_controller.hasLoaded) {
      return switch (state) {
        ToolsLoadState.offline => StateMessage(
          icon: AppIcons.cloud,
          title: l10n.toolsBannerOfflineTitle,
          detail: l10n.toolsBannerOfflineDetail,
          action: _tryAgainOutlined(context),
        ),
        ToolsLoadState.failed || ToolsLoadState.unauthorized => StateMessage(
          title: l10n.toolsBannerLoadFailedTitle,
          action: _tryAgainOutlined(context),
        ),
        _ => Center(
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                const CircularProgressIndicator.adaptive(),
                Text(l10n.toolsLoading),
              ],
            ),
          ),
        ),
      };
    }
    if (_controller.toolsets.isEmpty) {
      return StateMessage(
        title: l10n.toolsEmptyTitle,
        detail: l10n.toolsEmptyDetail,
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final wide = isWideLayout(context, width: box.maxWidth);
        final groups = _controller.groups;
        final ordered = [...groups.needsSetup, ...groups.on, ...groups.off];
        final selected =
            ordered.where((t) => t.name == _selected).firstOrNull ??
            ordered.first;
        final list = _list(context, selected: wide ? selected.name : null);
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: _listPaneWidth, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: _ToolsetDetail(
                key: ValueKey(selected.name),
                controller: _controller,
                name: selected.name,
                onSwitch: _switch,
                env: _env(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget? _banner(BuildContext context) {
    final l10n = context.l10n;
    final load = switch (_controller.loadState) {
      ToolsLoadState.offline => AppBanner(
        tone: AppBannerTone.warning,
        icon: AppIcons.cloud,
        title: l10n.toolsBannerOfflineTitle,
        detail: l10n.toolsBannerOfflineDetail,
        action: _tryAgain(context),
      ),
      ToolsLoadState.failed || ToolsLoadState.unauthorized => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.toolsBannerLoadFailedTitle,
        detail: l10n.toolsBannerLoadFailedDetail,
        action: _tryAgain(context),
      ),
      _ => null,
    };
    final banners = <Widget>[
      ?load,
      if (_controller.toolVanished)
        AppBanner(tone: AppBannerTone.warning, title: l10n.toolsVanished),
      if (_controller.postSetupStarted != null)
        AppBanner(
          tone: AppBannerTone.success,
          title: l10n.toolsBannerInstallerTitle(
            _startedName(context) ?? l10n.toolsTitle,
          ),
          detail: l10n.toolsBannerInstallerDetail,
          action: TextButton(
            onPressed: _showInstalling,
            style: toolsButtonStyle(context),
            child: Text(l10n.toolsBannerShow),
          ),
        )
      else if (_controller.changedSinceOpen)
        AppBanner(
          tone: AppBannerTone.success,
          title: l10n.toolsAppliedTitle,
          detail: l10n.toolsAppliedDetail,
        ),
    ];
    if (banners.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: banners,
      ),
    );
  }

  String? _startedName(BuildContext context) {
    final name = _controller.postSetupToolset;
    final toolset = _controller.toolsets
        .where((t) => t.name == name)
        .firstOrNull;
    return toolset == null ? null : toolsetName(context.l10n, toolset);
  }

  Widget _list(BuildContext context, {required String? selected}) {
    final l10n = context.l10n;
    final groups = _controller.groups;
    final desktop = toolsOnDesktop(context);
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    Widget section(String header, List<Toolset> toolsets) => GroupedSection(
      header: header,
      children: [
        for (final toolset in toolsets)
          ToolsetRow(
            key: ValueKey('tool-row-${toolset.name}'),
            view: toolsetRowView(
              l10n,
              toolset,
              _controller.rowState(toolset.name),
              selected: toolset.name == selected,
              desktop: desktop,
              locked: _controller.switchLocked(toolset.name),
            ),
            onOpen: () => _open(toolset),
            onChanged: (on) => _switch(toolset.name, on),
            onTryAgain: _controller.load,
          ),
      ],
    );
    final banner = _banner(context);
    final view = GroupedListView(
      key: const Key('tools-list'),
      physics: mac ? null : const AlwaysScrollableScrollPhysics(),
      children: [
        ?banner,
        if (groups.needsSetup.isNotEmpty)
          section(l10n.toolsNeedsSetup, groups.needsSetup),
        if (groups.on.isNotEmpty) section(l10n.commonOn, groups.on),
        if (groups.off.isNotEmpty) section(l10n.commonOff, groups.off),
        ToolsListFooter(
          onWhatsTheDifference: () => showToolsDifferenceSheet(context),
        ),
      ],
    );
    return mac ? view : RefreshIndicator(onRefresh: _refresh, child: view);
  }
}

/// A toolset's details, rebuilt with the controller.
class _ToolsetDetail extends StatefulWidget {
  const _ToolsetDetail({
    super.key,
    required this.controller,
    required this.name,
    required this.onSwitch,
    required this.env,
    this.showNote = false,
  });

  final ToolsController controller;
  final String name;
  final void Function(String name, bool on) onSwitch;
  final ToolsPanelEnv env;

  /// Whether the details carry the "Applies from your next chat" note; beside
  /// the list it already shows it.
  final bool showNote;

  @override
  State<_ToolsetDetail> createState() => _ToolsetDetailState();
}

class _ToolsetDetailState extends State<_ToolsetDetail> {
  Future<void> _refresh() =>
      Future.wait([widget.controller.load(), widget.env.refresh.run()]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final name = widget.name;
      final toolset = controller.toolsets
          .where((t) => t.name == name)
          .firstOrNull;
      if (toolset == null) return const SizedBox.shrink();
      final l10n = context.l10n;
      final desktop = toolsOnDesktop(context);
      final mac = platformChromeOf(context) == PlatformChrome.macos;
      final started = controller.postSetupStarted != null;
      final env = widget.env.withSwitchBusy(
        busy: controller.rowState(name).busy,
      );
      final body = ToolsetDetailBody(
        physics: mac ? null : const AlwaysScrollableScrollPhysics(),
        view: toolsetDetailView(
          l10n,
          toolset,
          controller.rowState(name),
          desktop: desktop,
          locked: controller.switchLocked(name),
        ),
        onChanged: (on) => widget.onSwitch(name, on),
        onTryAgain: controller.load,
        note: widget.showNote && controller.changedToolset(name) && !started
            ? AppBanner(
                tone: AppBannerTone.success,
                title: l10n.toolsAppliedTitle,
                detail: l10n.toolsAppliedDetail,
              )
            : null,
        setup: [
          ToolsetSetupPanel(
            key: ValueKey('setup-$name'),
            toolset: toolset,
            env: env,
          ),
          if (name == 'terminal')
            TerminalBackendsPanel(
              key: const Key('terminal-backends'),
              env: env,
            ),
          if (name == 'computer_use')
            ComputerUsePanel(key: const Key('computer-use'), env: env),
        ],
      );
      return mac ? body : RefreshIndicator(onRefresh: _refresh, child: body);
    },
  );
}

/// A toolset's details as a page of their own, below the wide breakpoint.
/// It closes when the toolset leaves the server.
class _ToolsetPage extends StatelessWidget {
  const _ToolsetPage({
    required this.controller,
    required this.name,
    required this.onSwitch,
    required this.env,
  });

  final ToolsController controller;
  final String name;
  final void Function(String name, bool on) onSwitch;
  final ToolsPanelEnv env;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final toolset = controller.toolsets
            .where((t) => t.name == name)
            .firstOrNull;
        if (toolset == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
        }
        return SettingsScaffold(
          title: toolset == null ? '' : toolsetName(l10n, toolset),
          subtitle: controller.profile,
          previousTitle: l10n.toolsTitle,
          body: _ToolsetDetail(
            controller: controller,
            name: name,
            onSwitch: onSwitch,
            env: env,
            showNote: true,
          ),
        );
      },
    );
  }
}
