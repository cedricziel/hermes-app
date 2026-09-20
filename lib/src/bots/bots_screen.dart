import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'bot_setup_screen.dart';
import 'hermes_bots_repository.dart';
import '../widgets/content_column.dart';

/// Lists the messaging platforms Hermes can run as bots and switches them
/// on or off. A platform that lacks credentials shows "Needs setup" and
/// can't be switched on until its row is opened and they are saved.
class BotsScreen extends StatefulWidget {
  const BotsScreen({super.key, this.repository});

  final HermesBotsRepository? repository;

  @override
  State<BotsScreen> createState() => _BotsScreenState();
}

class _BotsScreenState extends State<BotsScreen> {
  late final HermesBotsRepository _repository;
  List<HermesBot>? _bots;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        HermesBotsRepository(context.read<AuthController>().api!.raw);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final bots = await _repository.load();
      if (!mounted) return;
      setState(() {
        _bots = bots;
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

  Future<void> _toggle(HermesBot bot, bool enabled) async {
    try {
      await _repository.setEnabled(bot.id, enabled);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this bot')),
      );
      return;
    }
    if (mounted) await _load();
  }

  Future<void> _setUp(HermesBot bot) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BotSetupScreen(bot: bot, repository: _repository),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bots')),
      body: ContentColumn(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _bots == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final bots = _bots;
    if (_failed || bots == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load bots'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return ListView(
      children: [
        for (final bot in bots)
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(bot.name),
            subtitle: _subtitle(bot),
            onTap: () => _setUp(bot),
            trailing: Switch(
              value: bot.enabled,
              onChanged: bot.configured || bot.enabled
                  ? (v) => _toggle(bot, v)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _subtitle(HermesBot bot) {
    final lines = [
      if (bot.description.isNotEmpty) bot.description,
      if (!bot.configured) 'Needs setup',
      if (bot.errorMessage != null) bot.errorMessage!,
    ];
    return Text(lines.join('\n'));
  }
}
