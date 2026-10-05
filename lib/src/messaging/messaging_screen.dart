import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../widgets/adaptive_back_button.dart';
import '../api/hermes_repositories.dart';

import '../widgets/content_column.dart';
import 'messaging_setup_screen.dart';
import 'hermes_messaging_repository.dart';
import 'widgets/messaging_introduction.dart';

/// Lists the messaging platforms Hermes can run as platforms and switches them
/// on or off. A platform that lacks credentials shows "Needs setup" and
/// can't be switched on until its row is opened and they are saved.
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
    return Scaffold(
      appBar: AppBar(
        leading: const AdaptiveBackButton(previousTitle: 'Chat'),
        leadingWidth: adaptiveBackLeadingWidth(context),
        title: const Text('Messaging'),
      ),
      body: ContentColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MessagingIntroduction(),
            Expanded(child: _body()),
          ],
        ),
      ),
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
    return ListView(
      children: [
        for (final platform in platforms)
          ListTile(
            leading: const AppIcon(AppIcons.bot),
            title: Text(platform.name),
            subtitle: _subtitle(platform),
            onTap: () => _setUp(platform),
            trailing: Switch.adaptive(
              value: platform.enabled,
              onChanged: platform.configured || platform.enabled
                  ? (v) => _toggle(platform, v)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _subtitle(HermesMessagingPlatform platform) {
    final lines = [
      if (platform.description.isNotEmpty) platform.description,
      if (!platform.configured) 'Needs setup',
      if (platform.errorMessage != null) platform.errorMessage!,
    ];
    return Text(lines.join('\n'));
  }
}
