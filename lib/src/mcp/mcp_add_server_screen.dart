import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../widgets/settings_scaffold.dart';
import 'widgets/mcp_server_fields.dart';
import 'hermes_mcp_repository.dart';
import 'mcp_banner.dart';
import 'mcp_command_review.dart';
import 'mcp_command_review_items.dart';
import 'mcp_servers_controller.dart';

import '../widgets/route_dismissal.dart';

final _envName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

class _EnvRow {
  _EnvRow(this._listener) {
    name.addListener(_listener);
    value.addListener(_listener);
  }

  final VoidCallback _listener;
  final name = TextEditingController();
  final value = TextEditingController();

  void dispose() {
    // The screen is going away; clearing must not rebuild it.
    value
      ..removeListener(_listener)
      ..clear();
    name.dispose();
    value.dispose();
  }
}

/// The "Add server" form: a remote server (a URL and how it signs in) or a
/// command server (a command, its arguments and environment). Pops with the
/// new server's name once Hermes has added it.
///
/// A command server goes through [McpServersController.addServer], which
/// asks for the review of what it will run before anything is sent, whichever
/// way the form is submitted. The bearer token and the environment values live
/// in this screen's text fields only and are cleared once the request has
/// finished.
class McpAddServerScreen extends StatefulWidget {
  const McpAddServerScreen({super.key, required this.servers});

  final McpServersController servers;

  @override
  State<McpAddServerScreen> createState() => _McpAddServerScreenState();
}

class _McpAddServerScreenState extends State<McpAddServerScreen> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _command = TextEditingController();
  final _args = TextEditingController();
  late final _fields = [_name, _url, _token, _command, _args];
  final _env = <_EnvRow>[];
  bool _remote = true;
  McpRemoteAuth _auth = McpRemoteAuth.none;
  bool _nameTaken = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in _fields) {
      c.addListener(_changed);
    }
    widget.servers.addListener(_changed);
  }

  @override
  void dispose() {
    widget.servers.removeListener(_changed);
    // Clearing must not rebuild a screen that is being disposed.
    _token
      ..removeListener(_changed)
      ..clear();
    for (final c in _fields) {
      c.dispose();
    }
    for (final row in _env) {
      row.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _addRow() {
    setState(() => _env.add(_EnvRow(_changed)));
  }

  void _removeRow(_EnvRow row) {
    setState(() => _env.remove(row));
    row.dispose();
  }

  bool get _saving => widget.servers.isSaving;

  bool get _validUrl {
    final uri = Uri.tryParse(_url.text.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String? _envError(_EnvRow row) {
    final name = row.name.text.trim();
    if (name.isEmpty) return 'Enter a name';
    if (!_envName.hasMatch(name)) {
      return 'Use letters, digits and underscores, not starting with a digit';
    }
    final earlier = _env.takeWhile((r) => r != row);
    if (earlier.any((r) => r.name.text.trim() == name)) {
      return 'Already used above';
    }
    return null;
  }

  bool get _canAdd {
    if (_saving || _name.text.trim().isEmpty) return false;
    if (_remote) {
      return _validUrl &&
          (_auth != McpRemoteAuth.bearerToken || _token.text.trim().isNotEmpty);
    }
    return _command.text.trim().isNotEmpty &&
        _env.every((row) => _envError(row) == null);
  }

  McpNewServer _server() {
    final name = _name.text.trim();
    if (_remote) {
      return McpNewRemoteServer(
        name: name,
        url: _url.text.trim(),
        auth: _auth,
        bearerToken: _token.text.trim(),
      );
    }
    return McpNewCommandServer(
      name: name,
      command: _command.text.trim(),
      args: [
        for (final line in _args.text.split('\n'))
          if (line.trim().isNotEmpty) line.replaceAll('\r', ''),
      ],
      env: {for (final row in _env) row.name.text.trim(): row.value.text},
    );
  }

  Future<bool> _review(List<McpCommandReviewItem> commands) async =>
      mounted &&
      await showMcpCommandReview(
        context,
        commands,
        confirmLabel: 'Add and run on server',
      );

  void _clearSecrets() {
    _token.clear();
    for (final row in _env) {
      row.value.clear();
    }
  }

  Future<void> _submit() async {
    if (!_canAdd) return;
    final server = _server();
    setState(() {
      _error = null;
      _nameTaken = false;
    });
    McpAddOutcome? outcome;
    try {
      outcome = await widget.servers.addServer(server, review: _review);
    } finally {
      if (mounted && outcome is! McpAddCancelled) _clearSecrets();
    }
    if (!mounted) return;
    switch (outcome) {
      case McpAdded(:final name):
        dismissRoute(context, name);
      case McpAddDuplicate():
        setState(() => _nameTaken = true);
      case McpAddRefused(:final reason) when reason.isNotEmpty:
        setState(() => _error = reason);
      case McpAddRefused() || McpAddFailed():
        setState(() => _error = 'Could not add ${server.name}');
      case McpAddCancelled():
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Add server',
      subtitle: widget.servers.profile,
      previousTitle: 'MCP servers',
      formAction: SettingsFormAction(
        key: const ValueKey('mcp-add-server-button'),
        label: 'Add',
        busy: _saving && !widget.servers.isReviewing,
        onPressed: _canAdd ? _submit : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              McpServerFields(
                name: _name,
                url: _url,
                token: _token,
                command: _command,
                args: _args,
                remote: _remote,
                auth: _auth,
                saving: _saving,
                nameError: _nameTaken
                    ? 'A server with this name already exists'
                    : null,
                urlError: _url.text.trim().isNotEmpty && !_validUrl
                    ? 'Enter an http or https address'
                    : null,
                onNameChanged: (_) => setState(() => _nameTaken = false),
                onRemoteChanged: (choice) => setState(() => _remote = choice),
                onAuthChanged: (choice) => setState(() => _auth = choice),
                onSubmit: _submit,
                onAddVariable: _addRow,
                environment: [
                  for (final row in _env)
                    McpEnvironmentField(
                      name: row.name,
                      value: row.value,
                      error: _envError(row),
                      onRemove: () => _removeRow(row),
                    ),
                ],
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                McpBanner(
                  tone: McpTone.error,
                  icon: AppIcons.error,
                  title: error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
