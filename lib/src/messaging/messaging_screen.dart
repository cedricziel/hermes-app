import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../chat/invalidation/change_invalidation_binding.dart';
import '../chat/invalidation/change_signal.dart';

import '../api/hermes_repositories.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'hermes_messaging_repository.dart';
import 'messaging_setup_screen.dart';
import '../chat/gateway_connection_transport.dart';
import 'widgets/messaging_platform_row.dart';

/// Lists the messaging platforms Hermes can run as platforms and switches them
/// on or off. A platform that lacks credentials offers "Set Up" in place of
/// its switch until its row is opened and they are saved.
class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key, this.repository, this.changeSource});

  final HermesMessagingRepository? repository;
  final GatewayConnectionTransport? changeSource;

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  late final HermesMessagingRepository _repository;
  List<HermesMessagingPlatform>? _platforms;
  bool _loading = true;
  bool _failed = false;
  ChangeInvalidationBinding? _changes;
  int _generation = 0, _mutations = 0;
  bool get _refreshing =>
      _loading ||
      (_changes?.controller.loading(InvalidationResource.platforms) ?? false);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HermesRepositories.of(context).messaging;
    final source = widget.changeSource;
    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      /* Standalone fixtures may omit authentication. */
    }
    if (source != null && auth != null) {
      final changes = _changes = ChangeInvalidationBinding(
        source: source,
        auth: auth,
        resource: InvalidationResource.platforms,
        profile: () => _repository.profile,
      );
      changes.controller.register<
        ({int generation, List<HermesMessagingPlatform> platforms})
      >(
        InvalidationResource.platforms,
        readSnapshot: (scope) async {
          final generation = _generation;
          final platforms = await _repository.forProfile(scope.profile).load();
          return (generation: generation, platforms: platforms);
        },
        snapshotIsCurrent: (snapshot) =>
            mounted && snapshot.generation == _generation,
        applySnapshot: (snapshot) => setState(() {
          _platforms = snapshot.platforms;
          _failed = false;
        }),
        onFailure: (_) {
          if (mounted) setState(() => _failed = true);
        },
      );
      changes.controller.addListener(_invalidationsChanged);
      changes.sync(active: true);
    }
    _load();
  }

  void _invalidationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _changes?.controller.removeListener(_invalidationsChanged);
    _changes?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final owner = _changes?.ownerPeriod;
    setState(() {
      _loading = true;
      _failed = false;
    });
    _changes?.sync(blocked: true);
    try {
      final platforms = await _repository.load();
      if (!mounted ||
          generation != _generation ||
          (owner != null && !_changes!.ownsPeriod(owner))) {
        return;
      }
      setState(() => _platforms = platforms);
    } on Object {
      if (mounted &&
          generation == _generation &&
          (owner == null || _changes!.ownsPeriod(owner))) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        _changes?.sync(blocked: _mutations > 0);
      }
    }
  }

  Future<void> _toggle(HermesMessagingPlatform platform, bool enabled) async {
    _mutations++;
    _changes?.sync(blocked: true);
    try {
      await _repository.setEnabled(platform.id, enabled);
      if (mounted) await _load();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this messaging platform'),
          ),
        );
      }
    } finally {
      _mutations--;
      if (mounted) _changes?.sync(blocked: _mutations > 0 || _loading);
    }
  }

  Future<void> _setUp(HermesMessagingPlatform platform) async {
    _changes?.sync(active: false);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MessagingSetupScreen(
            platform: platform,
            repository: _repository,
            changeSource: widget.changeSource,
          ),
        ),
      );
      if (saved == true && mounted) await _load();
    } finally {
      if (mounted) _changes?.sync(active: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platforms = _platforms;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return SettingsScaffold(
      title: 'Messaging',
      subtitle: mac && platforms != null
          ? '${platforms.where((p) => p.enabled).length} of '
                '${platforms.length} on'
          : null,
      body: _body(),
    );
  }

  static const _intro =
      'Connect Hermes to Telegram, Discord, and other messaging platforms.';

  Widget _body() {
    if (_refreshing && _platforms == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final platforms = _platforms;
    if (_failed || platforms == null) {
      return StateMessage(
        icon: AppIcons.bot,
        title: 'Could not load messaging platforms',
        detail: _intro,
        action: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    return GroupedListView(
      children: [
        GroupedSection(
          dividerIndent: GroupedMetrics.of(context).indentAfterTile,
          footer: _intro,
          children: [
            for (final platform in platforms)
              MessagingPlatformRow(
                platform: platform,
                onSetUp: () => _setUp(platform),
                onToggle: (enabled) => _toggle(platform, enabled),
              ),
          ],
        ),
      ],
    );
  }
}
