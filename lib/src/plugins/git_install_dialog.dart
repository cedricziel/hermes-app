import 'package:flutter/material.dart';

import 'plugin_install_result.dart';

/// Runs an install from [identifier]; [enable] and [force] are the user's
/// choices.
typedef SourceInstaller = Future<PluginInstallResult> Function(
  String identifier, {
  required bool enable,
  required bool force,
});

/// The one way to install code the Hermes catalog has not reviewed.
///
/// The dialog owns the typed address. It is trimmed and handed to [install],
/// and is gone when the dialog closes: it can carry a token, so nothing here
/// stores it, logs it or puts it in a message. The dialog closes with the
/// install's result, or with nothing when the user cancels.
class GitInstallDialog extends StatefulWidget {
  const GitInstallDialog({super.key, required this.install});

  final SourceInstaller install;

  @override
  State<GitInstallDialog> createState() => _GitInstallDialogState();
}

class _GitInstallDialogState extends State<GitInstallDialog> {
  final _url = TextEditingController();
  bool _trust = false;
  bool _enable = true;
  bool _force = false;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  bool get _ready => !_busy && _trust && _url.text.trim().isNotEmpty;

  Future<void> _run() async {
    final identifier = _url.text.trim();
    setState(() => _busy = true);
    final result = await widget.install(
      identifier,
      enable: _enable,
      force: _force,
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Install from Git URL'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('git-url-field'),
                controller: _url,
                enabled: !_busy,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Git URL or owner/repo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.onSurface),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gpp_maybe_outlined, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unreviewed code. This plugin is not from the Hermes catalog. It runs on your server with full access.',
                      ),
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                key: const Key('git-trust-checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I trust this source'),
                value: _trust,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _trust = value ?? false),
              ),
              SwitchListTile(
                key: const Key('git-enable-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable after install'),
                value: _enable,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _enable = value),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Advanced'),
                children: [
                  SwitchListTile(
                    key: const Key('git-force-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Overwrite existing (force)'),
                    value: _force,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _force = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('git-install'),
            onPressed: _ready ? _run : null,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Install'),
          ),
        ],
      ),
    );
  }
}
