import 'package:flutter/material.dart';

import '../api/hermes_repositories.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import 'hermes_messaging_repository.dart';
import 'messaging_setup_screen.dart';
import 'widgets/messaging_platform_row.dart';

/// Lists the messaging platforms Hermes can run as platforms and switches them
/// on or off. A platform that lacks credentials offers "Set Up" in place of
/// its switch until its row is opened and they are saved.
class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key, this.repository});

  final HermesMessagingRepository? repository;

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  late final HermesMessagingRepository _repository;
  List<HermesMessagingPlatform>? _platforms;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HermesRepositories.of(context).messaging;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final platforms = await _repository.load();
      if (!mounted) return;
      setState(() {
        _platforms = platforms;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggle(HermesMessagingPlatform platform, bool enabled) async {
    try {
      await _repository.setEnabled(platform.id, enabled);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this messaging platform'),
        ),
      );
      return;
    }
    if (mounted) await _load();
  }

  Future<void> _setUp(HermesMessagingPlatform platform) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MessagingSetupScreen(platform: platform, repository: _repository),
      ),
    );
    if (saved == true && mounted) await _load();
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

  Widget _body() {
    if (_loading && _platforms == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final platforms = _platforms;
    if (_failed || platforms == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load messaging platforms'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return GroupedListView(
      children: [
        GroupedSection(
          dividerIndent: GroupedMetrics.of(context).indentAfterTile,
          footer:
              'Connect Hermes to Telegram, Discord, and other messaging '
              'platforms.',
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
