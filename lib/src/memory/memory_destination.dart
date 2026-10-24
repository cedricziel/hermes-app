import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';
import '../auth/auth_controller.dart';
import '../auth/verified_session_owner.dart';
import '../chat/chat_transport.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../plugins/plugins_screen.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../telemetry/breadcrumbs.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'memory_controller.dart';
import 'memory_proposal_session.dart';
import 'memory_proposals_controller.dart';
import 'memory_proposals_repository.dart';
import 'memory_repository.dart';
import 'memory_screen.dart';
import 'memory_settings_controller.dart';
import 'memory_settings_repository.dart';

/// Where Memory was opened from, for the `nav.memory` breadcrumb.
enum MemoryEntryPoint {
  sidebar('sidebar'),
  profilesPage('profiles_page');

  const MemoryEntryPoint(this.wire);
  final String wire;
}

/// Pushes Memory for [profile] and notes how the user got there.
Future<void> openMemory(
  BuildContext context, {
  required MemoryEntryPoint from,
  required String? profile,
  ChatTransport? transport,
}) {
  Breadcrumbs breadcrumbs;
  try {
    breadcrumbs = context.read<Breadcrumbs>();
  } on ProviderNotFoundException {
    breadcrumbs = Breadcrumbs.none;
  }
  breadcrumbs('nav.memory', {'from': from.wire});
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MemoryDestination(profile: profile, transport: transport),
    ),
  );
}

/// Memory of one profile. [profile] is the one its entry point names, which
/// the server's active profile never replaces; without one the screen opens
/// on the active profile.
class MemoryDestination extends StatefulWidget {
  const MemoryDestination({super.key, this.profile, this.transport});

  final String? profile;

  /// Runs the commands that list and decide staged changes. Without one the
  /// destination opens its own gateway socket when it can.
  final ChatTransport? transport;

  @override
  State<MemoryDestination> createState() => _MemoryDestinationState();
}

class _MemoryDestinationState extends State<MemoryDestination> {
  late final MemoryController _controller;
  late final MemorySettingsController _settings;
  late final MemoryProposalsController _proposals;
  HermesGatewayTransport? _ownedTransport;
  MemoryProposalsRepository? _proposalsRepository;
  HermesRepositories? _repositories;
  MemoryRepository? _memory;
  MemorySettingsRepository? _settingsRepository;
  Map<String, String> _profiles = const {};
  MemoryFailure? _failure;
  bool _loading = false;
  int _generation = 0;
  AuthController? _auth;
  int? _ownerGeneration;
  VerifiedSessionOwner? _owner;
  String? _server;
  bool _retired = false;

  bool _sameOwner(AuthController auth) =>
      identical(_auth, auth) &&
      auth.ownerGeneration == _ownerGeneration &&
      auth.verifiedOwner == _owner &&
      auth.baseUrl == _server;

  void _authorizationChanged() {
    final auth = _auth;
    if (auth == null) return;
    if (!_sameOwner(auth)) _retired = true;
    if (!_retired &&
        auth.protectedRequestsAllowed &&
        auth.state == HermesConnectionState.ready &&
        identical(_repositories?.api, auth.api)) {
      return;
    }
    _generation++;
    _repositories = null;
    _memory = null;
    _settingsRepository = null;
    _proposalsRepository = null;
    _closeTransport();
    _profiles = const {};
    _loading = false;
    _failure = null;
    _controller.bind(null, null);
    _settings.bind(null, null);
    _proposals.bind(null, null);
  }

  void _closeTransport() {
    _ownedTransport?.close();
    _ownedTransport = null;
  }

  @override
  void initState() {
    super.initState();
    Breadcrumbs breadcrumbs = Breadcrumbs.none;
    try {
      breadcrumbs = context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      breadcrumbs = Breadcrumbs.none;
    }
    _controller = MemoryController(breadcrumbs: breadcrumbs);
    _proposals = MemoryProposalsController(breadcrumbs: breadcrumbs);
    _settings = MemorySettingsController(
      breadcrumbs: breadcrumbs,
      onReset: _controller.load,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    HermesRepositories? repositories;
    AuthController? watched;
    try {
      final auth = watched = context.watch<AuthController>();
      if (_auth == null) {
        _auth = auth;
        _ownerGeneration = auth.ownerGeneration;
        _owner = auth.verifiedOwner;
        _server = auth.baseUrl;
        auth.addListener(_authorizationChanged);
      } else if (!_sameOwner(auth)) {
        _retired = true;
      }
      if (!_retired &&
          auth.api != null &&
          auth.protectedRequestsAllowed &&
          auth.state == HermesConnectionState.ready) {
        repositories = HermesRepositories.of(context);
        if (!identical(repositories.api, auth.api)) {
          repositories = HermesRepositories.forAuth(auth, _repositories);
        }
      }
    } on ProviderNotFoundException {
      repositories = context.watch<HermesRepositories?>();
    }
    if (identical(_repositories?.api, repositories?.api)) return;
    _generation++;
    _repositories = repositories;
    _profiles = const {};
    _controller.bind(null, null);
    _settings.bind(null, null);
    _proposals.bind(null, null);
    _closeTransport();
    _memory = repositories == null
        ? null
        : MemoryRepository(
            repositories.api.raw,
            telemetry: repositories.telemetry,
          );
    _settingsRepository = repositories == null
        ? null
        : MemorySettingsRepository(
            repositories.api.raw,
            telemetry: repositories.telemetry,
          );
    final transport = widget.transport ?? _openGateway(watched, repositories);
    _proposalsRepository = transport == null || repositories == null
        ? null
        : MemoryProposalsRepository(
            MemoryProposalSession(transport),
            telemetry: repositories.telemetry,
          );
    if (repositories != null) _loadProfiles();
  }

  /// A socket of this screen's own for the commands that list and decide
  /// staged changes; null without a connection to open it on.
  ChatTransport? _openGateway(
    AuthController? auth,
    HermesRepositories? repositories,
  ) {
    final baseUrl = auth?.baseUrl;
    if (auth == null || repositories == null || baseUrl == null) return null;
    final telemetry = repositories.telemetry.gateway();
    return _ownedTransport = HermesGatewayTransport(
      connect: hermesGatewayConnect(
        baseUrl: baseUrl,
        authRequired: auth.status?.authRequired ?? true,
        api: repositories.api,
        telemetry: telemetry,
      ),
      telemetry: telemetry,
      events: repositories.telemetry.events,
    );
  }

  void _show(String profile) {
    _controller.bind(_memory, profile);
    _settings.bind(_settingsRepository, profile);
    _proposals.bind(_proposalsRepository, profile);
  }

  void _openProviders(String profile) {
    final repositories = _repositories;
    if (repositories == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PluginsScreen(
          repository: repositories.pluginManager.forProfile(profile),
          events: repositories.telemetry.events,
          initialTab: PluginsTab.providers,
        ),
      ),
    );
  }

  Future<void> _loadProfiles() async {
    final repositories = _repositories;
    if (repositories == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final named = widget.profile;
      final ProfilesOverview? overview = named == null
          ? await repositories.profiles.load()
          : null;
      final listed = overview?.profiles ?? await repositories.profiles.list();
      if (!mounted || generation != _generation) return;
      final profiles = {
        for (final profile in listed) profile.name: profile.label,
      };
      final selected =
          named ??
          (profiles.containsKey(overview!.active)
              ? overview.active
              : overview.current);
      if (!profiles.containsKey(selected)) {
        throw MemoryFailure.profileUnavailable;
      }
      setState(() => _profiles = profiles);
      _show(selected);
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _failure = error is MemoryFailure
              ? error
              : MemoryFailure.transport,
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_repositories == null) {
      return SettingsScaffold(
        title: 'Memory',
        body: StateMessage(
          title: _retired
              ? 'Reopen Memory for this account.'
              : 'Sign in to read memories.',
        ),
      );
    }
    if (_loading) {
      return const SettingsScaffold(
        title: 'Memory',
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_failure != null) {
      return SettingsScaffold(
        title: 'Memory',
        body: StateMessage(
          title: _failure!.message,
          action: FilledButton(
            onPressed: _loadProfiles,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    return MemoryScreen(
      controller: _controller,
      settings: _settings,
      proposals: _proposals,
      onOpenProviders: _openProviders,
      profiles: _profiles,
      onProfile: _show,
    );
  }

  @override
  void dispose() {
    _auth?.removeListener(_authorizationChanged);
    _generation++;
    _controller.dispose();
    _settings.dispose();
    _proposals.dispose();
    _closeTransport();
    super.dispose();
  }
}
