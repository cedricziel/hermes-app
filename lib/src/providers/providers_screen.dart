import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../auth/auth_controller.dart';
import '../theme/app_icons.dart';
import '../theme/breakpoints.dart';
import '../theme/platform_chrome.dart';
import '../telemetry/breadcrumbs.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart' show SettingsSearch;
import 'provider_detail_pane.dart';
import 'provider_endpoint_sheet.dart';
import 'provider_flow.dart';
import 'provider_key_sheet.dart';
import 'provider_models.dart';
import 'provider_setup_controller.dart';
import 'provider_sign_in.dart' show SignInPhase;
import 'provider_sign_in_sheet.dart';
import 'provider_view_mapper.dart';
import 'providers_repository.dart';
import 'widgets/provider_alerts.dart';
import 'widgets/provider_detail_frame.dart';
import 'widgets/provider_detail_view.dart' show providerDetailBarActions;
import 'widgets/provider_list_view.dart';
import 'widgets/provider_view_models.dart';

/// Where the Model providers screen was opened from, for the
/// `providers.opened` breadcrumb. The welcome card and the composer have
/// their own values, added with those entry points.
enum ProvidersEntry {
  sidebar('sidebar'),
  drawer('drawer'),
  profiles('profiles');

  const ProvidersEntry(this.wire);
  final String wire;
}

Future<bool> _openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The model providers of one profile: what it can chat with, how each
/// provider is connected, and the ways to connect, change or remove one. The
/// list sits beside the selected provider's detail from 900 points (a Mac
/// window from [kMacSplitBreakpoint], and a full-screen iPad), and below
/// that a provider opens as a page.
///
/// [ProviderSetupController] holds the state; this screen only words it, owns
/// the dialogs and sheets, and clears nothing it does not own. Every
/// request names [profile]. Signing out or changing the server closes the
/// screen and everything over it; a sign-in being followed stops polling
/// without being cancelled.
class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({
    super.key,
    required this.repository,
    required this.profile,
    this.entry = ProvidersEntry.sidebar,
    this.onChanged,
    this.launchLink,
    this.platform,
  });

  final ProvidersRepository repository;

  /// The profile the screen is for; null for a server without profiles.
  final String? profile;
  final ProvidersEntry entry;

  /// A provider, a sign-in or the default model changed: pickers elsewhere
  /// read their options again.
  final VoidCallback? onChanged;

  /// Opens an address that passed the link check; the browser by default.
  final ProviderLinkLauncher? launchLink;

  /// Overrides the platform the sign-in follower pauses on (tests).
  final TargetPlatform? platform;

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  late final ProviderSetupController _controller;
  final _scroll = ScrollController();
  final _addKey = GlobalKey();
  String? _selected;
  var _search = '';
  var _sheets = 0;
  var _stepQueued = false;
  var _changes = 0;
  var _left = false;
  Timer? _stepRetry;

  AuthController? _auth;
  AppLockController? _appLock;
  ModalRoute<dynamic>? _route;
  String? _server;
  int? _userGeneration;
  int? _ownerGeneration;
  late Breadcrumbs _crumbs = Breadcrumbs.none;

  /// The name the screen shows for the profile; Hermes calls the one of a
  /// server without profiles `default`.
  String get _profileLabel => widget.profile ?? 'default';

  @override
  void initState() {
    super.initState();
    _controller = ProviderSetupController(
      repository: widget.repository,
      profile: widget.profile,
      platform: widget.platform,
    );
    _controller.addListener(_changed);
    unawaited(_controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
    if (_auth == null) {
      try {
        final auth = context.read<AuthController>();
        _auth = auth;
        _server = auth.baseUrl;
        _userGeneration = auth.userGeneration;
        _ownerGeneration = auth.ownerGeneration;
        auth.addListener(_authChanged);
      } on ProviderNotFoundException {
        // No connection above (a catalog or a test): nothing to follow.
      }
      try {
        _appLock = context.read<AppLockController>();
      } on ProviderNotFoundException {
        _appLock = null;
      }
      try {
        _crumbs = context.read<Breadcrumbs>();
      } on ProviderNotFoundException {
        _crumbs = Breadcrumbs.none;
      }
      _crumbs('providers.opened', {'source': widget.entry.wire});
    }
  }

  @override
  void dispose() {
    _stepRetry?.cancel();
    _auth?.removeListener(_authChanged);
    _controller
      ..removeListener(_changed)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Signing out, a server change or another account closes the screen and
  /// what is over it. The controller then stops following sign-ins without
  /// cancelling them, and the sheets clear the keys typed in them.
  void _authChanged() {
    final auth = _auth;
    if (auth == null || _left) return;
    final gone =
        auth.state != HermesConnectionState.ready ||
        auth.baseUrl != _server ||
        auth.userGeneration != _userGeneration ||
        auth.ownerGeneration != _ownerGeneration;
    if (gone) _leave();
  }

  void _leave() {
    if (_left) return;
    _left = true;
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    navigator.popUntil((r) => r == route);
    navigator.removeRoute(route);
  }

  void _changed() {
    if (_controller.changes != _changes) {
      _changes = _controller.changes;
      widget.onChanged?.call();
    }
    _maybeOpenStep();
  }

  // ---- sheets ----

  ProviderFlowServices get _services => ProviderFlowServices(
    controller: _controller,
    profileLabel: _profileLabel,
    openLink: _openLink,
    startChatting: _startChatting,
    appLock: _appLock,
  );

  Future<void> _openLink(Uri uri) async {
    final opened = await (widget.launchLink ?? _openInBrowser)(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.providersLinkFailed)),
      );
    }
  }

  /// "Start chatting": the sheet goes, and so does the screen when it came
  /// from the chat.
  void _startChatting() {
    final navigator = Navigator.of(context);
    final route = _route;
    if (route != null && route.isActive) {
      navigator.popUntil((r) => r == route);
    }
    if (widget.entry != ProvidersEntry.profiles && navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<ProviderSheetResult?> _sheet(WidgetBuilder builder) async {
    _sheets++;
    try {
      return await showProviderSheet(context, builder: builder);
    } finally {
      _sheets--;
    }
  }

  /// A step that began while no sheet was open (a sign-in approved while the
  /// person was elsewhere) opens on its own.
  void _maybeOpenStep() {
    if (_sheets > 0 || _stepQueued || _controller.step == null) return;
    _stepQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _stepQueued = false;
      if (!mounted || _sheets > 0 || _controller.step == null) return;
      // Something else is over the screen (the model picker, a question such
      // as "Stop signing in?", a detail page): the step waits until it is
      // closed instead of opening on top of it.
      if (_route?.isCurrent != true) {
        _stepRetry?.cancel();
        _stepRetry = Timer(const Duration(milliseconds: 300), _maybeOpenStep);
        return;
      }
      await _sheet((_) => ProviderStepSheet(services: _services));
      _controller.dismissStep();
      _maybeOpenStep();
    });
  }

  void _afterSheet() {
    if (mounted) _maybeOpenStep();
  }

  Future<void> _connectKey(ProviderEntry entry) async {
    _controller.openKeyForm(entry.id);
    final result = await _sheet(
      (_) => ProviderKeySheet(services: _services, providerId: entry.id),
    );
    _controller.closeKeyForm();
    if (stepIsFor(_controller, entry.id)) _controller.dismissStep();
    if (!mounted) return;
    if (result == ProviderSheetResult.useAccount) {
      _crumbs('providers.connect.started', {'method': 'server'});
      await _serverCommand(entry);
      return;
    }
    _afterSheet();
  }

  Future<void> _signIn(ProviderEntry entry) async {
    _controller.startSignIn(entry.id);
    await _sheet(
      (_) => ProviderSignInSheet(services: _services, providerId: entry.id),
    );
    final signIn = _controller.signInFor(entry.id);
    if (signIn != null &&
        !signIn.pending &&
        signIn.phase != SignInPhase.approved) {
      _controller.dismissSignIn(entry.id);
    }
    if (stepIsFor(_controller, entry.id)) _controller.dismissStep();
    _afterSheet();
  }

  Future<void> _serverCommand(ProviderEntry entry) async {
    await _sheet(
      (_) => ProviderServerSheet(services: _services, providerId: entry.id),
    );
    _afterSheet();
  }

  Future<void> _endpointForm({ProviderEntry? entry}) async {
    _controller.resetEndpointForm();
    await _sheet(
      (_) => ProviderEndpointSheet(services: _services, entry: entry),
    );
    _controller.resetEndpointForm();
    if (_controller.step?.providerId.startsWith('custom:') ?? false) {
      _controller.dismissStep();
    }
    _afterSheet();
  }

  // ---- what the list and the detail do ----

  void _add(String id) {
    final entry = _controller.catalog?.byId(id);
    if (entry == null) return;
    switch (entry.method) {
      case ConnectMethod.key:
        _crumbs('providers.connect.started', {'method': 'key'});
        unawaited(_connectKey(entry));
      case ConnectMethod.account:
        _crumbs('providers.connect.started', {'method': 'account'});
        unawaited(_signIn(entry));
      case ConnectMethod.onServer || ConnectMethod.endpoint:
        _crumbs('providers.connect.started', {'method': 'server'});
        unawaited(_serverCommand(entry));
    }
  }

  void _addEndpoint() {
    _crumbs('providers.connect.started', {'method': 'endpoint'});
    unawaited(_endpointForm());
  }

  Future<void> _continueSignIn(String id) async {
    final entry = _controller.catalog?.byId(id);
    if (entry != null) await _signIn(entry);
  }

  Future<void> _stopSignIn(String id) async {
    final name = _controller.catalog?.byId(id)?.name ?? id;
    final confirmed = await confirmStopSignIn(context, provider: name);
    if (!confirmed || !mounted) return;
    await _controller.cancelSignIn(id);
    _controller.dismissSignIn(id);
  }

  Future<void> _chooseDefault() => chooseDefaultModel(context, _controller);

  Future<void> _remove(ProviderEntry entry, ProviderRemovalData removal) async {
    final l10n = context.l10n;
    final servesDefault = entry.isDefault;
    final bool confirmed;
    final RemovalAction action;
    switch (removal.kind) {
      case ProviderRemovalKind.removeKey:
        action = RemoveKeyAction(removal.id);
        confirmed = await confirmRemoveKey(
          context,
          provider: entry.name,
          profile: _profileLabel,
          servesDefault: servesDefault,
        );
      case ProviderRemovalKind.signOut:
        action = const SignOutAction();
        confirmed = await confirmSignOut(
          context,
          provider: entry.name,
          profile: _profileLabel,
          servesDefault: servesDefault,
        );
      case ProviderRemovalKind.deleteEndpoint:
        action = const DeleteEndpointAction();
        confirmed = await confirmDeleteEndpoint(
          context,
          name: entry.name,
          profile: _profileLabel,
          hasKey: entry.endpoint?.hasApiKey ?? false,
          servesDefault: servesDefault,
        );
    }
    if (!confirmed || !mounted) return;
    _crumbs('providers.remove.confirmed', {'kind': action.kind!.name});
    final result = await _controller.remove(entry, action);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (result.status) {
      case RemovalStatus.refused:
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? l10n.providersRemoveRefusedFallback,
            ),
          ),
        );
      case RemovalStatus.unknown:
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.providersRemoveUnknown)),
        );
      case RemovalStatus.removed || RemovalStatus.alreadyGone:
        break;
    }
  }

  ProviderDetailActions get _actions => ProviderDetailActions(
    changeDefault: _chooseDefault,
    replaceKey: (entry) => unawaited(_connectKey(entry)),
    remove: (entry, removal) => unawaited(_remove(entry, removal)),
    edit: (entry) => unawaited(_endpointForm(entry: entry)),
  );

  void _select(String id, {required bool wide}) {
    if (wide) {
      setState(() => _selected = id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderDetailPage(
          controller: _controller,
          providerId: id,
          profile: _profileLabel,
          actions: _actions,
        ),
      ),
    );
  }

  void _scrollToAdd() {
    final target = _addKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  // ---- layout ----

  bool _pullsToRefresh(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  String? _selectedFor(ProviderListData data) {
    final rows = [
      for (final r in data.connected)
        if (!r.isPending) r.id,
    ];
    if (_selected != null && rows.contains(_selected)) return _selected;
    return rows.firstOrNull;
  }

  Widget _list(
    BuildContext context,
    ProviderListData data, {
    required bool wide,
    String? selectedId,
  }) {
    final pull = _pullsToRefresh(context);
    final view = ProviderListView(
      data: data,
      selectedId: wide ? selectedId : null,
      searchQuery: _search,
      onSearchChanged: (value) => setState(() => _search = value),
      onSelect: (id) => _select(id, wide: wide),
      onAdd: _add,
      onAddEndpoint: _addEndpoint,
      onOpenDefaultModel: _chooseDefault,
      onContinueSignIn: (id) => unawaited(_continueSignIn(id)),
      onStopSignIn: (id) => unawaited(_stopSignIn(id)),
      onRetry: _controller.load,
      onRetryKeys: _controller.load,
      onRetryAccounts: _controller.load,
      onRetryEndpoints: _controller.load,
      scrollController: _scroll,
      scrollPhysics: pull ? const AlwaysScrollableScrollPhysics() : null,
      addHeadingKey: _addKey,
    );
    if (!pull || data.status != ProviderListStatus.loaded) return view;
    return RefreshIndicator(onRefresh: _controller.load, child: view);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    Widget screen = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final data = providerListData(
          _controller,
          profile: _profileLabel,
          restartReason: l10n.providersRestartTitle,
        );
        final loaded = data.status == ProviderListStatus.loaded;
        return LayoutBuilder(
          builder: (context, box) {
            final wide = mac
                ? box.maxWidth >= kMacSplitBreakpoint
                : isWideLayout(context, width: box.maxWidth);
            final selectedId = wide ? _selectedFor(data) : null;
            final selectedEntry = selectedId == null
                ? null
                : _controller.catalog?.byId(selectedId);
            final detailData = selectedEntry == null
                ? null
                : providerDetailData(
                    selectedEntry,
                    _controller,
                    profile: _profileLabel,
                  );
            final searchable =
                loaded && data.addableCount > kProviderSearchThreshold;
            return SettingsScaffold(
              title: l10n.providersListTitle,
              subtitle: providerListSubtitle(
                l10n,
                _profileLabel,
                loaded ? data.connectedCount : 0,
              ),
              search: mac && searchable
                  ? SettingsSearch(
                      query: _search,
                      hint: l10n.providersSearchHint,
                      onChanged: (value) => setState(() => _search = value),
                    )
                  : null,
              actions: [
                if (wide && loaded)
                  SettingsBarAction(
                    label: mac
                        ? l10n.providersAddActionMac
                        : l10n.providersAddAction,
                    icon: AppIcons.add,
                    onPressed: _scrollToAdd,
                  ),
                if (detailData != null && selectedEntry != null)
                  ...providerDetailBarActions(
                    l10n,
                    detailData,
                    onEdit: () =>
                        unawaited(_endpointForm(entry: selectedEntry)),
                  ),
              ],
              body: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: (box.maxWidth * .45)
                              .clamp(280, 360)
                              .toDouble(),
                          child: _list(
                            context,
                            data,
                            wide: true,
                            selectedId: selectedId,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selectedId == null
                              ? (loaded
                                    ? const ProviderDetailPlaceholder()
                                    : const SizedBox.shrink())
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ProviderDetailHeader(
                                      name: selectedEntry?.name ?? '',
                                    ),
                                    Expanded(
                                      child: ProviderDetailPane(
                                        key: ValueKey(selectedId),
                                        controller: _controller,
                                        providerId: selectedId,
                                        profile: _profileLabel,
                                        actions: _actions,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    )
                  : _list(context, data, wide: false),
            );
          },
        );
      },
    );
    if (mac) {
      screen = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
              _controller.load,
        },
        child: Focus(autofocus: true, child: screen),
      );
    }
    return screen;
  }
}
