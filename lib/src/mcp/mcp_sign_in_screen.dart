import 'dart:async';

import '../widgets/grouped_list.dart';
import 'widgets/mcp_sign_in_status.dart';
import '../widgets/settings_scaffold.dart';

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
  bool _addressRefused = false;
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
    if (!_settled) widget.controller.cancelSignIn(_flow);
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
    _addressRefused = false;
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
    final uri = Uri.tryParse(url);
    if (uri == null || !_isWebAddress(uri)) {
      if (mounted) setState(() => _addressRefused = true);
      return;
    }
    var opened = false;
    try {
      opened = await widget.controller.launchLink(uri);
    } on Object {
      opened = false;
    }
    if (mounted) {
      setState(() {
        _addressRefused = false;
        _browserFailed = !opened;
      });
    }
  }

  /// Hermes hands over the address, but only a web address is opened: https,
  /// or http on this device for a provider running beside it.
  static bool _isWebAddress(Uri uri) =>
      uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          const {'localhost', '127.0.0.1', '::1'}.contains(uri.host));

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

  void _cancel() {
    widget.controller.cancelSignIn(_flow);
    _phase = _Phase.done;
    Navigator.of(context).pop(false);
  }

  Future<void> _tryAgain() async {
    if (_starting) return;
    setState(() => _starting = true);
    final start = await widget.controller.startSignIn(widget.server);
    if (!mounted) {
      if (start is McpSignInStarted) widget.controller.cancelSignIn(start.flow);
      return;
    }
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
    return PopScope(
      canPop: !_starting,
      child: SettingsScaffold(
        title: 'Sign in to $name',
        subtitle: widget.controller.profile,
        previousTitle: 'MCP servers',
        body: GroupedListView(
          children: [
            switch (_phase) {
              _Phase.waiting => _waiting(),
              _Phase.failed => _ended(
                title: 'Could not sign in',
                detail: _failure,
              ),
              _Phase.expired => _ended(
                title: 'The sign-in expired',
                detail: 'Hermes dropped it. Start it again to get a new link.',
              ),
              _Phase.done => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }

  Widget _waiting() {
    final url = _flow.authorizationUrl;
    return McpSignInStatus(
      title: 'Waiting for you to approve',
      detail:
          'Approve the sign-in in your browser. It finishes on your Hermes '
          'server, so this screen closes by itself.',
      waiting: true,
      addressRefused: _addressRefused,
      address: !_addressRefused && _browserFailed ? url : null,
      onCopyAddress: url == null
          ? null
          : () => Clipboard.setData(ClipboardData(text: url)),
      onOpenBrowser: url == null || _addressRefused
          ? null
          : () {
              _launchedUrl = null;
              _openBrowser();
            },
      onClose: _cancel,
    );
  }

  Widget _ended({required String title, required String detail}) =>
      McpSignInStatus(
        title: title,
        detail: detail,
        waiting: false,
        starting: _starting,
        onRetry: _tryAgain,
        onClose: () => Navigator.of(context).pop(false),
      );
}
