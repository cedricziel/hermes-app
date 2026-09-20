import 'dart:convert';

import 'package:flutter/material.dart';

import 'mcp_banner.dart';
import 'mcp_command_review.dart';
import 'mcp_command_review_items.dart';
import 'mcp_json_check.dart';
import 'mcp_servers_controller.dart';

/// Edits the profile's whole `mcp_servers` map as JSON and replaces it on
/// Save. Pops with true once Hermes has saved.
///
/// The text is the profile's real configuration, secrets included. It lives
/// in this screen's state only: it is not logged, stored or sent anywhere but
/// to Hermes on Save, and it is dropped when the screen closes. Every save
/// goes through [McpServersController.replaceServers], which has the command
/// servers that are new or changed reviewed before anything is sent.
class McpJsonEditorScreen extends StatefulWidget {
  const McpJsonEditorScreen({super.key, required this.servers});

  final McpServersController servers;

  @override
  State<McpJsonEditorScreen> createState() => _McpJsonEditorScreenState();
}

class _McpJsonEditorScreenState extends State<McpJsonEditorScreen> {
  static const _indent = JsonEncoder.withIndent('  ');

  final _text = TextEditingController();
  Map<String, Object?> _loaded = {};
  String _original = '';
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;
  bool _asking = false;
  McpJsonCheck _check = const McpJsonValid({});
  List<String> _problems = const [];
  String? _failure;

  @override
  void initState() {
    super.initState();
    _text.addListener(_edited);
    _load();
  }

  @override
  void dispose() {
    _text.removeListener(_edited);
    _text.clear();
    _text.dispose();
    _loaded = {};
    _original = '';
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final loaded = await widget.servers.loadRawServers();
      if (!mounted) return;
      _loaded = loaded;
      _original = _indent.convert(loaded);
      _text.text = _original;
      setState(() => _loading = false);
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _edited() {
    setState(() {
      _check = checkMcpServersJson(_text.text);
      _problems = const [];
      _failure = null;
    });
  }

  bool get _dirty => !_loading && !_loadFailed && _text.text != _original;

  bool get _canSave => _dirty && _check is McpJsonValid && !_busy;

  Future<bool> _ask({
    required String title,
    required String body,
    required String confirm,
    String cancel = 'Cancel',
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return answer == true;
  }

  Future<bool> _review(List<McpCommandReviewItem> commands) async {
    if (!mounted) return false;
    setState(() => _asking = true);
    try {
      return await showMcpCommandReview(
        context,
        commands,
        confirmLabel: 'Save and run on server',
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave || _check is! McpJsonValid) return;
    final edited = (_check as McpJsonValid).servers;
    _busy = true;
    setState(() {
      _problems = const [];
      _failure = null;
    });
    try {
      final removed = _loaded.keys.where((name) => !edited.containsKey(name));
      if (removed.isNotEmpty) {
        setState(() => _asking = true);
        final ok = await _ask(
          title: 'Delete ${removed.length == 1 ? 'a server' : 'servers'}?',
          body:
              '${removed.map((n) => '"$n"').join(', ')} will be deleted, not '
              'just switched off.',
          confirm: 'Delete and save',
        );
        if (mounted) setState(() => _asking = false);
        if (!ok || !mounted) return;
      }
      final outcome = await widget.servers.replaceServers(
        _loaded,
        edited,
        review: _review,
      );
      if (!mounted) return;
      switch (outcome) {
        case McpReplaced():
          Navigator.of(context).pop(true);
        case McpReplaceRefused(:final problems) when problems.isNotEmpty:
          setState(() => _problems = problems);
        case McpReplaceRefused() || McpReplaceFailed():
          setState(() => _failure = 'Could not save');
        case McpReplaceCancelled():
      }
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final discard = await _ask(
      title: 'Discard changes?',
      body: 'Your edits have not been saved.',
      confirm: 'Discard',
      cancel: 'Keep editing',
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.servers.profile;
    final sending = _busy && !_asking;
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit as JSON'),
              Text(
                profile == null
                    ? 'mcp_servers'
                    : 'Profile: $profile · mcp_servers',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const ValueKey('mcp-json-save'),
                onPressed: _canSave ? _save : null,
                child: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
        body: _body(theme),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load the configuration'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final check = _check;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const McpBanner(
            tone: McpTone.warning,
            icon: Icons.warning_amber_outlined,
            title: 'Replaces all servers of this profile.',
            detail:
                'Anything you remove here is deleted, not just switched off. '
                "This is the profile's real configuration, including secrets "
                'such as environment values and bearer tokens. It is not saved on '
                'this device.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('mcp-json-text'),
              controller: _text,
              readOnly: _busy,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              smartQuotesType: SmartQuotesType.disabled,
              smartDashesType: SmartDashesType.disabled,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          if (check is McpJsonInvalid) ...[
            const SizedBox(height: 8),
            Text(
              check.message,
              key: const ValueKey('mcp-json-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (_problems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              key: const ValueKey('mcp-json-problems'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final problem in _problems)
                  Text(
                    problem,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ],
          if (_failure case final failure?) ...[
            const SizedBox(height: 8),
            Text(failure, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
