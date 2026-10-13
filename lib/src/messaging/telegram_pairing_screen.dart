import 'dart:async';

import '../theme/app_icons.dart';
import '../widgets/adaptive_back_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../chat/gateway_connection_transport.dart';
import '../chat/invalidation/change_invalidation_binding.dart';
import '../chat/invalidation/change_signal.dart';

import 'package:url_launcher/url_launcher.dart';

import '../widgets/content_column.dart';
import 'hermes_messaging_repository.dart';
import '../widgets/route_dismissal.dart';

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
    this.changeSource,
    this.pollInterval = const Duration(seconds: 3),
    this.launchLink = _defaultLaunchLink,
  });

  final HermesMessagingRepository repository;
  final GatewayConnectionTransport? changeSource;
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
  bool _checking = false;
  int _generation = 0;
  ChangeInvalidationBinding? _changes;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      /* Injected standalone screens need no auth provider. */
    }
    final source = widget.changeSource;
    if (source != null && auth != null) {
      final changes = _changes = ChangeInvalidationBinding(
        source: source,
        auth: auth,
        resource: InvalidationResource.pairing,
        profile: () => widget.repository.profile,
      );
      changes.controller.register<
        ({
          int generation,
          TelegramPairing pairing,
          TelegramPairingStatus status,
        })
      >(
        InvalidationResource.pairing,
        readSnapshot: (_) async {
          final pairing = _pairing!;
          final generation = _generation;
          final status = await widget.repository.telegramPairingStatus(
            pairing.id,
          );
          return (generation: generation, pairing: pairing, status: status);
        },
        snapshotIsCurrent: (snapshot) =>
            mounted &&
            _phase == _Phase.waiting &&
            snapshot.generation == _generation &&
            identical(snapshot.pairing, _pairing),
        applySnapshot: (snapshot) => _applyStatus(snapshot.status),
        onFailure: _fail,
      );
      changes.controller.addListener(_invalidationsChanged);
    }
    _start();
  }

  @override
  void dispose() {
    _changes?.controller.removeListener(_invalidationsChanged);
    _changes?.dispose();
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
    final generation = ++_generation;
    final owner = _changes?.ownerPeriod;
    _poll?.cancel();
    _poll = null;
    _cancelPairing();
    setState(() {
      _phase = _Phase.starting;
      _error = null;
    });
    _syncChanges();
    try {
      final pairing = await widget.repository.startTelegramPairing();
      if (!mounted ||
          generation != _generation ||
          (owner != null && !_changes!.ownsPeriod(owner))) {
        _discard(pairing);
        return;
      }
      setState(() {
        _pairing = pairing;
        _phase = _Phase.waiting;
      });
      _syncChanges();
      _scheduleNextPoll();
    } on Object catch (e) {
      if (generation == _generation &&
          (owner == null || _changes!.ownsPeriod(owner))) {
        _fail(e);
      }
    }
  }

  void _syncChanges() => _changes?.sync(
    active:
        _pairing != null &&
        _pairing!.id.trim().isNotEmpty &&
        _phase == _Phase.waiting,
    blocked: _saving || _checking,
  );

  void _invalidationsChanged() {
    if (!mounted) return;
    if (_changes!.foreground && _changes!.ownsPeriod(_changes!.ownerPeriod)) {
      if (_pairing != null &&
          _phase == _Phase.waiting &&
          _poll == null &&
          !_checking) {
        _scheduleNextPoll();
      }
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _applyStatus(TelegramPairingStatus status) {
    if (!mounted || _phase != _Phase.waiting || !status.ready) return;
    _poll?.cancel();
    _poll = null;
    if (_users.text.isEmpty) _users.text = status.ownerUserId ?? '';
    setState(() {
      _claim = status;
      _phase = _Phase.claimed;
    });
    _syncChanges();
  }

  void _scheduleNextPoll() {
    if (_pairing == null ||
        _phase != _Phase.waiting ||
        (_changes != null &&
            (!_changes!.foreground ||
                !_changes!.ownsPeriod(_changes!.ownerPeriod)))) {
      return;
    }
    _poll?.cancel();
    _poll = Timer(widget.pollInterval, _pollOnce);
  }

  Future<void> _pollOnce() async {
    _poll = null;
    final pairing = _pairing,
        generation = _generation,
        owner = _changes?.ownerPeriod;
    if (pairing == null ||
        _phase != _Phase.waiting ||
        (_changes != null &&
            (!_changes!.foreground || !_changes!.ownsPeriod(owner!)))) {
      return;
    }
    _checking = true;
    _syncChanges();
    try {
      final status = await widget.repository.telegramPairingStatus(pairing.id);
      if (!mounted ||
          generation != _generation ||
          !identical(pairing, _pairing) ||
          (owner != null && !_changes!.ownsPeriod(owner))) {
        return;
      }
      _applyStatus(status);
    } on Object catch (e) {
      if (mounted &&
          generation == _generation &&
          (owner == null || _changes!.ownsPeriod(owner))) {
        _fail(e);
      }
    } finally {
      _checking = false;
      if (mounted) {
        _syncChanges();
        _scheduleNextPoll();
      }
    }
  }

  void _fail(Object error) {
    if (!mounted) return;
    _poll?.cancel();
    _poll = null;
    setState(() {
      _phase = _Phase.failed;
      _error = explainSetupError(error, 'Could not reach the Telegram setup');
    });
    _syncChanges();
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
    _syncChanges();
    try {
      await widget.repository.applyTelegramPairing(_pairing!.id, _userIds);
      _pairing = null;
      if (mounted) dismissRoute(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = explainSetupError(e, 'Could not save the setup');
      });
      _syncChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AdaptiveBackButton(previousTitle: 'Messaging'),
        leadingWidth: adaptiveBackLeadingWidth(context),
        title: const Text('Set up with Telegram'),
      ),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _content(),
        ),
      ),
    );
  }

  List<Widget> _content() => switch (_phase) {
    _Phase.starting => const [
      Center(child: CircularProgressIndicator.adaptive()),
    ],
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
            icon: const AppIcon(AppIcons.send),
            label: const Text('Open Telegram'),
          ),
          OutlinedButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: link)),
            icon: const AppIcon(AppIcons.copy),
            label: const Text('Copy link'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
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
