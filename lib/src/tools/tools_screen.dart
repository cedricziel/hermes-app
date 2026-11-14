import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../theme/platform_chrome.dart';
import '../widgets/app_banner.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'hermes_tools_repository.dart';
import 'toolset_copy.dart';
import 'tools_availability.dart';
import 'tools_controller.dart';
import 'tools_models.dart';
import 'tools_row_mapping.dart';
import 'widgets/toolset_detail_body.dart';
import 'widgets/toolset_row.dart';
import 'widgets/tools_confirmation.dart';
import 'widgets/tools_difference_sheet.dart';
import 'widgets/tools_list_footer.dart';
import 'widgets/tools_target.dart';

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
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({
    super.key,
    required this.repository,
    this.availability,
    this.onProfileGone,
  });

  final HermesToolsRepository repository;

  /// Where the shell's first read of this profile's list comes from.
  final ToolsAvailability? availability;

  /// Called once when the server says the profile no longer exists, so the
  /// caller reads the profile list again.
  final VoidCallback? onProfileGone;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late ToolsController _controller;
  AppLockController? _lock;
  String? _selected;
  var _asking = false;
  var _goneReported = false;

  @override
  void initState() {
    super.initState();
    _controller = _newController();
    unawaited(_controller.load());
    _lock = _maybeRead<AppLockController>()?..addListener(_onLock);
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
      _controller.switchProfile(widget.repository);
      unawaited(_controller.load());
    }
  }

  @override
  void dispose() {
    _lock?.removeListener(_onLock);
    _controller
      ..removeListener(_onChanged)
      ..dispose();
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
      unawaited(_ask(question));
    } else if (question == null && _asking) {
      // Cancelled from outside (App Lock): take the dialog down too.
      Navigator.of(context, rootNavigator: true).pop(false);
    }
    if (_controller.loadState == ToolsLoadState.profileGone && !_goneReported) {
      _goneReported = true;
      widget.onProfileGone?.call();
    }
  }

  Future<void> _ask(ToolsConfirmation question) async {
    final l10n = context.l10n;
    final toolset = question.toolset;
    final text =
        toolsetConfirmQuestion(l10n, toolset.name, _controller.profile) ??
        toolsetInstallQuestion(l10n, toolsetName(l10n, toolset));
    _asking = true;
    final confirmed = await showToolsetConfirmation(context, text);
    _asking = false;
    if (!mounted) return;
    if (confirmed) {
      unawaited(_controller.confirm());
    } else {
      _controller.cancel();
    }
  }

  bool _desktop(BuildContext context) =>
      platformChromeOf(context) == PlatformChrome.macos ||
      isWideLayout(context);

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
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ToolsetPage(
            controller: _controller,
            name: toolset.name,
            onSwitch: _switch,
          ),
        ),
      ),
    );
  }

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

  Widget _tryAgain(BuildContext context, {bool filled = false}) {
    final label = Text(context.l10n.toolsTryAgain);
    return filled
        ? OutlinedButton(
            onPressed: _controller.load,
            style: toolsButtonStyle(context),
            child: label,
          )
        : TextButton(onPressed: _controller.load, child: label);
  }

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
          action: _tryAgain(context, filled: true),
        ),
        ToolsLoadState.failed || ToolsLoadState.unauthorized => StateMessage(
          title: l10n.toolsBannerLoadFailedTitle,
          action: _tryAgain(context, filled: true),
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
    final desktop = _desktop(context);
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
class _ToolsetDetail extends StatelessWidget {
  const _ToolsetDetail({
    super.key,
    required this.controller,
    required this.name,
    required this.onSwitch,
    this.showNote = false,
  });

  final ToolsController controller;
  final String name;
  final void Function(String name, bool on) onSwitch;

  /// Whether the details carry the "Applies from your next chat" note; beside
  /// the list it already shows it.
  final bool showNote;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final toolset = controller.toolsets
          .where((t) => t.name == name)
          .firstOrNull;
      if (toolset == null) return const SizedBox.shrink();
      final l10n = context.l10n;
      final desktop =
          platformChromeOf(context) == PlatformChrome.macos ||
          isWideLayout(context);
      final started = controller.postSetupStarted != null;
      return ToolsetDetailBody(
        view: toolsetDetailView(
          l10n,
          toolset,
          controller.rowState(name),
          desktop: desktop,
        ),
        onChanged: (on) => onSwitch(name, on),
        onTryAgain: controller.load,
        note: showNote && controller.changedSinceOpen && !started
            ? AppBanner(
                tone: AppBannerTone.success,
                title: l10n.toolsAppliedTitle,
                detail: l10n.toolsAppliedDetail,
              )
            : null,
        // The setup sections (providers, keys, install, model, terminal and
        // Computer use) are added here.
        setup: const [],
      );
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
  });

  final ToolsController controller;
  final String name;
  final void Function(String name, bool on) onSwitch;

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
            showNote: true,
          ),
        );
      },
    );
  }
}
