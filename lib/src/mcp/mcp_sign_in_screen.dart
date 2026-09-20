import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_servers_controller.dart';

/// Waits while the user approves a sign-in to an OAuth server in the browser.
///
/// Hermes runs the flow and keeps the token; this screen opens the
/// authorization address, watches the flow and says how it ended. It pops
/// `true` once Hermes reports the sign-in approved. Leaving before the flow
/// has ended cancels it, so the server's "already in progress" slot is freed.
class McpSignInScreen extends StatefulWidget {
  const McpSignInScreen({
    super.key,
    required this.controller,
    required this.server,
    required this.flow,
    this.pollInterval = const Duration(seconds: 2),
  });

  final McpServersController controller;
  final HermesMcpServer server;
  final HermesMcpFlow flow;
  final Duration pollInterval;

  @override
  State<McpSignInScreen> createState() => _McpSignInScreenState();
}

enum _Phase { waiting, failed, expired, done }

class _McpSignInScreenState extends State<McpSignInScreen>
    with WidgetsBindingObserver {
  late HermesMcpFlow _flow;
  var _phase = _Phase.waiting;
  String _failure = '';
  bool _browserFailed = false;
  bool _starting = false;
  bool _polling = false;
  Timer? _timer;
  String? _launchedUrl;

  HermesMcpRepository get _repository => widget.controller.repository;

  bool get _settled => _phase != _Phase.waiting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin(widget.flow);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (!_settled) _cancelFlow(_flow);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_settled) _poll();
  }

  void _begin(HermesMcpFlow flow) {
    _flow = flow;
    if (flow.status == McpFlowStatus.error) {
      _phase = _Phase.failed;
      _failure = _reason(flow);
      return;
    }
    _phase = _Phase.waiting;
    _launchedUrl = null;
    _browserFailed = false;
    _openBrowser();
    _schedule();
  }

  String _reason(HermesMcpFlow flow) => flow.error?.isNotEmpty == true
      ? flow.error!
      : 'Signing in to ${widget.server.name} failed.';

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(widget.pollInterval, _poll);
  }

  /// Hermes may not have the address yet when the flow starts, so this is
  /// tried again whenever a poll brings one.
  Future<void> _openBrowser() async {
    final url = _flow.authorizationUrl;
    if (url == null || url == _launchedUrl) return;
    _launchedUrl = url;
    var opened = false;
    try {
      opened = await widget.controller.launchLink(Uri.parse(url));
    } on Object {
      opened = false;
    }
    if (mounted) setState(() => _browserFailed = !opened);
  }

  Future<void> _poll() async {
    if (_polling || _settled) return;
    _polling = true;
    try {
      final flow = await _repository.flowStatus(_flow.flowId);
      if (!mounted || _settled) return;
      switch (flow.status) {
        case McpFlowStatus.approved:
          _phase = _Phase.done;
          Navigator.of(context).pop(true);
          return;
        case McpFlowStatus.error:
          setState(() {
            _phase = _Phase.failed;
            _failure = _reason(flow);
          });
          return;
        case McpFlowStatus.starting ||
            McpFlowStatus.authorizationRequired ||
            McpFlowStatus.unknown:
          _flow = flow;
          await _openBrowser();
      }
    } on Object catch (e) {
      if (!mounted || _settled) return;
      if (isMcpNotFound(e)) {
        setState(() => _phase = _Phase.expired);
        return;
      }
    } finally {
      _polling = false;
    }
    if (mounted && !_settled) _schedule();
  }

  void _cancelFlow(HermesMcpFlow flow) {
    unawaited(_repository.cancelFlow(flow.flowId).catchError((Object _) {}));
  }

  void _cancel() {
    _cancelFlow(_flow);
    _phase = _Phase.done;
    Navigator.of(context).pop(false);
  }

  Future<void> _tryAgain() async {
    if (_starting) return;
    setState(() => _starting = true);
    final start = await widget.controller.startSignIn(widget.server);
    if (!mounted) return;
    setState(() {
      _starting = false;
      switch (start) {
        case McpSignInStarted(:final flow):
          _begin(flow);
        case McpSignInDeclined():
          _failure =
              widget.controller.signInNoteOf(widget.server.name) ??
              'Could not start signing in to ${widget.server.name}';
          _phase = _Phase.failed;
        case McpSignInGone():
          Navigator.of(context).pop(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.server.name;
    return Scaffold(
      appBar: AppBar(title: Text('Sign in to $name')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_phase) {
              _Phase.waiting => _waiting(context),
              _Phase.failed => _ended(
                context,
                title: 'Could not sign in',
                detail: _failure,
              ),
              _Phase.expired => _ended(
                context,
                title: 'The sign-in expired',
                detail: 'Hermes dropped it. Start it again to get a new link.',
              ),
              _Phase.done => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Widget _waiting(BuildContext context) {
    final theme = Theme.of(context);
    final url = _flow.authorizationUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text('Waiting for you to approve', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Approve the sign-in in your browser. It finishes on your Hermes '
          'server, so this screen closes by itself.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (_browserFailed && url != null) ...[
          const SizedBox(height: 16),
          Text(
            'Could not open the browser. Open this address yourself:',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy address'),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: url == null
              ? null
              : () {
                  _launchedUrl = null;
                  _openBrowser();
                },
          child: const Text('Open the browser again'),
        ),
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
      ],
    );
  }

  Widget _ended(
    BuildContext context, {
    required String title,
    required String detail,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _starting ? null : _tryAgain,
          child: _starting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Try again'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
