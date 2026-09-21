import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hermes_bots_repository.dart';
import '../widgets/content_column.dart';

typedef LinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLaunchLink(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Pairs a Telegram bot without the user creating one by hand: the dashboard
/// has its setup service make a bot, the user claims it by opening a link in
/// Telegram, and then says which Telegram accounts may talk to it. The bot's
/// token goes from the setup service to the dashboard and never to the app.
///
/// Pops `true` once the dashboard saved the setup.
class TelegramPairingScreen extends StatefulWidget {
  const TelegramPairingScreen({
    super.key,
    required this.repository,
    this.pollInterval = const Duration(seconds: 3),
    this.launchLink = _defaultLaunchLink,
  });

  final HermesBotsRepository repository;
  final Duration pollInterval;
  final LinkLauncher launchLink;

  @override
  State<TelegramPairingScreen> createState() => _TelegramPairingScreenState();
}

enum _Phase { starting, waiting, claimed, failed }

class _TelegramPairingScreenState extends State<TelegramPairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _users = TextEditingController();
  _Phase _phase = _Phase.starting;
  TelegramPairing? _pairing;
  TelegramPairingStatus? _claim;
  Timer? _poll;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cancelPairing();
    _users.dispose();
    super.dispose();
  }

  void _cancelPairing() {
    final pairing = _pairing;
    if (pairing == null) return;
    _pairing = null;
    _discard(pairing);
  }

  /// Best effort: an unclaimed pairing expires on its own anyway.
  void _discard(TelegramPairing pairing) {
    unawaited(
      widget.repository.cancelTelegramPairing(pairing.id).catchError((_) {}),
    );
  }

  Future<void> _start() async {
    _cancelPairing();
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    try {
      final pairing = await widget.repository.startTelegramPairing();
      if (!mounted) {
        _discard(pairing);
        return;
      }
      setState(() {
        _pairing = pairing;
        _phase = _Phase.waiting;
      });
      _scheduleNextPoll();
    } on Object catch (e) {
      _fail(e);
    }
  }

  void _scheduleNextPoll() {
    _poll = Timer(widget.pollInterval, _pollOnce);
  }

  Future<void> _pollOnce() async {
    final pairing = _pairing;
    if (pairing == null) return;
    try {
      final status = await widget.repository.telegramPairingStatus(pairing.id);
      if (!mounted) return;
      if (!status.ready) {
        _scheduleNextPoll();
        return;
      }
      _users.text = status.ownerUserId ?? '';
      setState(() {
        _claim = status;
        _phase = _Phase.claimed;
      });
    } on Object catch (e) {
      _fail(e);
    }
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = explainSetupError(error, 'Could not reach the Telegram setup');
    });
  }

  List<String> get _userIds => [
    for (final id in _users.text.split(','))
      if (id.trim().isNotEmpty) id.trim(),
  ];

  String? _validateUsers(String? _) {
    final ids = _userIds;
    if (ids.isEmpty) return 'Add at least one Telegram user ID';
    if (!ids.every(RegExp(r'^\d+$').hasMatch)) {
      return 'Use numeric Telegram user IDs, separated by commas';
    }
    return null;
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.applyTelegramPairing(_pairing!.id, _userIds);
      _pairing = null;
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = explainSetupError(e, 'Could not save the setup');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up with Telegram')),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _content(),
        ),
      ),
    );
  }

  List<Widget> _content() => switch (_phase) {
    _Phase.starting => const [Center(child: CircularProgressIndicator())],
    _Phase.waiting => _waiting(),
    _Phase.claimed => _claimed(),
    _Phase.failed => [
      Text(_error ?? '', style: _errorStyle),
      const SizedBox(height: 16),
      FilledButton(onPressed: _start, child: const Text('Start again')),
    ],
  };

  TextStyle get _errorStyle =>
      TextStyle(color: Theme.of(context).colorScheme.error);

  List<Widget> _waiting() {
    final link = _pairing!.deepLink;
    return [
      const Text(
        'Open this link on a device with Telegram and tap Start. '
        'Hermes gets a new bot that only you can use.',
      ),
      const SizedBox(height: 16),
      SelectableText(link),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => widget.launchLink(Uri.parse(link)),
            icon: const Icon(Icons.send),
            label: const Text('Open Telegram'),
          ),
          OutlinedButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: link)),
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Flexible(child: Text('Waiting for you in Telegram')),
        ],
      ),
    ];
  }

  List<Widget> _claimed() {
    final name = _claim?.botUsername;
    return [
      Text(
        name == null
            ? 'Your bot is ready.'
            : 'Your bot @$name is ready. Which Telegram accounts may talk to it?',
      ),
      const SizedBox(height: 16),
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _users,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Allowed Telegram user IDs',
            helperText:
                'Comma-separated numeric IDs. Yours is filled in if Telegram '
                'reported it.',
            helperMaxLines: 3,
          ),
          validator: _validateUsers,
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: _errorStyle),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _saving ? null : _finish,
        child: const Text('Finish setup'),
      ),
    ];
  }
}
