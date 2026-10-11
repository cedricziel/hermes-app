import 'package:flutter/material.dart';

import 'plugin_install_result.dart';

import '../widgets/disclosure_tile.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_form.dart';
import '../widgets/grouped_list.dart';

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
    final metrics = GroupedMetrics.of(context);
    return PopScope(
      canPop: !_busy,
      child: GroupedDialog(
        title: 'Install from Git URL',
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
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('Install'),
          ),
        ],
        children: [
          GroupedSection(
            children: [
              GroupedTextFieldRow(
                key: const Key('git-url-field'),
                label: 'Source',
                hint: 'Git URL or owner/repo',
                controller: _url,
                enabled: !_busy,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const GroupedSection(
            children: [
              GroupedRow(
                title: 'Source warning',
                warning: 'Unreviewed code. This plugin is not from the Hermes catalog. It runs on your server with full access.',
              ),
            ],
          ),
          GroupedSection(
            children: [
              GroupedRow(
                key: const Key('git-trust-checkbox'),
                title: 'I trust this source',
                checked: _trust,
                enabled: !_busy,
                onTap: () => setState(() => _trust = !_trust),
                trailing: Checkbox.adaptive(
                  value: _trust,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _trust = value ?? false),
                ),
              ),
              GroupedSwitchRow(
                key: const Key('git-enable-switch'),
                title: 'Enable after install',
                value: _enable,
                onTap: _busy ? null : () => setState(() => _enable = !_enable),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _enable = value),
              ),
            ],
          ),
          DisclosureTile(
            title: Text(
              'Advanced',
              style: TextStyle(fontSize: metrics.titleSize),
            ),
            tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              GroupedSection(
                children: [
                  GroupedSwitchRow(
                    key: const Key('git-force-switch'),
                    title: 'Overwrite existing (force)',
                    value: _force,
                    onTap: _busy
                        ? null
                        : () => setState(() => _force = !_force),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _force = value),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
