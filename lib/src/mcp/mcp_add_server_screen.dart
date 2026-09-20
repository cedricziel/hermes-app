import 'package:flutter/material.dart';

import 'hermes_mcp_repository.dart';
import 'mcp_banner.dart';
import 'mcp_command_review.dart';
import 'mcp_command_review_items.dart';
import 'mcp_servers_controller.dart';

final _envName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

class _EnvRow {
  _EnvRow(this.id);

  final int id;
  final name = TextEditingController();
  final value = TextEditingController();

  void dispose(VoidCallback listener) {
    name.removeListener(listener);
    value.removeListener(listener);
    value.clear();
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
  final _env = <_EnvRow>[];
  int _nextRow = 0;
  bool _remote = true;
  McpRemoteAuth _auth = McpRemoteAuth.none;
  bool _nameTaken = false;
  bool _reviewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _url, _token, _command, _args]) {
      c.addListener(_changed);
    }
    widget.servers.addListener(_changed);
  }

  @override
  void dispose() {
    widget.servers.removeListener(_changed);
    for (final c in [_name, _url, _token, _command, _args]) {
      c.removeListener(_changed);
    }
    _token.clear();
    for (final c in [_name, _url, _token, _command, _args]) {
      c.dispose();
    }
    for (final row in _env) {
      row.dispose(_changed);
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _addRow() {
    final row = _EnvRow(_nextRow++);
    row.name.addListener(_changed);
    row.value.addListener(_changed);
    setState(() => _env.add(row));
  }

  void _removeRow(_EnvRow row) {
    setState(() => _env.remove(row));
    row.dispose(_changed);
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

  Future<bool> _review(List<McpCommandReviewItem> commands) async {
    if (!mounted) return false;
    setState(() => _reviewing = true);
    try {
      return await showMcpCommandReview(
        context,
        commands,
        confirmLabel: 'Add and run on server',
      );
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

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
        Navigator.of(context).pop(name);
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
    final theme = Theme.of(context);
    final profile = widget.servers.profile;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add server'),
            if (profile != null)
              Text('Profile: $profile', style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const ValueKey('mcp-add-server-button'),
              onPressed: _canAdd ? _submit : null,
              child: _saving && !_reviewing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Remote (URL)')),
                  ButtonSegment(value: false, label: Text('Command')),
                ],
                selected: {_remote},
                onSelectionChanged: _saving
                    ? null
                    : (choice) => setState(() => _remote = choice.single),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                readOnly: _saving,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _nameTaken = false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: _nameTaken
                      ? 'A server with this name already exists'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (_remote)
                ..._remoteFields(theme)
              else
                ..._commandFields(theme),
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                McpBanner(
                  tone: McpTone.error,
                  icon: Icons.error_outline,
                  title: error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _remoteFields(ThemeData theme) {
    return [
      TextField(
        controller: _url,
        readOnly: _saving,
        keyboardType: TextInputType.url,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'URL',
          hintText: 'https://mcp.example.com/mcp',
          border: const OutlineInputBorder(),
          errorText: _url.text.trim().isNotEmpty && !_validUrl
              ? 'Enter an http or https address'
              : null,
        ),
      ),
      const SizedBox(height: 16),
      Text('Authentication', style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      SegmentedButton<McpRemoteAuth>(
        segments: const [
          ButtonSegment(value: McpRemoteAuth.none, label: Text('None')),
          ButtonSegment(
            value: McpRemoteAuth.bearerToken,
            label: Text('Bearer token'),
          ),
          ButtonSegment(value: McpRemoteAuth.oauth, label: Text('OAuth')),
        ],
        selected: {_auth},
        onSelectionChanged: _saving
            ? null
            : (choice) => setState(() => _auth = choice.single),
      ),
      const SizedBox(height: 12),
      if (_auth == McpRemoteAuth.oauth)
        Text(
          "After adding, you sign in from the server's page.",
          style: theme.textTheme.bodySmall,
        ),
      if (_auth == McpRemoteAuth.bearerToken) ...[
        TextField(
          controller: _token,
          readOnly: _saving,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Bearer token',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kept on your Hermes server. It is never shown again.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    ];
  }

  List<Widget> _commandFields(ThemeData theme) {
    return [
      TextField(
        controller: _command,
        readOnly: _saving,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: const InputDecoration(
          labelText: 'Command',
          hintText: 'npx',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _args,
        readOnly: _saving,
        minLines: 3,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: const InputDecoration(
          labelText: 'Arguments (one per line)',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      Text('Environment variables', style: theme.textTheme.labelLarge),
      for (final row in _env)
        Padding(
          key: ValueKey('mcp-env-row-${row.id}'),
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: row.name,
                  readOnly: _saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Variable name',
                    border: const OutlineInputBorder(),
                    errorText: _envError(row),
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: row.value,
                  readOnly: _saving,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove variable',
                icon: const Icon(Icons.close),
                onPressed: _saving ? null : () => _removeRow(row),
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _saving ? null : _addRow,
          icon: const Icon(Icons.add),
          label: const Text('Add variable'),
        ),
      ),
      Text(
        'Values are sent to your Hermes server once and never shown again.',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }
}
