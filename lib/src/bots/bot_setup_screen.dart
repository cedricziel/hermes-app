import 'package:flutter/material.dart';

import 'hermes_bots_repository.dart';
import 'telegram_pairing_screen.dart';

/// A form for the credentials and settings a platform reads from its
/// environment. Values the dashboard already holds are never shown, only
/// that they are set; a field left blank keeps its value.
///
/// Pops `true` once the setup was saved.
class BotSetupScreen extends StatefulWidget {
  const BotSetupScreen({
    super.key,
    required this.bot,
    required this.repository,
  });

  final HermesBot bot;
  final HermesBotsRepository repository;

  @override
  State<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends State<BotSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final v in widget.bot.envVars) v.key: TextEditingController(),
  };
  final _cleared = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final env = <String, String>{};
    for (final MapEntry(:key, :value) in _controllers.entries) {
      final text = value.text.trim();
      if (text.isNotEmpty) env[key] = text;
    }
    if (env.isEmpty && _cleared.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveSetup(
        widget.bot.id,
        env: env,
        clear: _cleared.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = explainSetupError(e, 'Could not save the setup');
      });
    }
  }

  Future<void> _pairTelegram() async {
    final paired = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TelegramPairingScreen(repository: widget.repository),
      ),
    );
    if (paired == true && mounted) Navigator.pop(context, true);
  }

  void _toggleCleared(String key) {
    _controllers[key]!.clear();
    setState(() {
      if (!_cleared.add(key)) _cleared.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vars = widget.bot.envVars;
    final basic = vars.where((v) => !v.advanced);
    final advanced = vars.where((v) => v.advanced).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Set up ${widget.bot.name}')),
      body: vars.isEmpty
          ? const Center(child: Text('Nothing to set up for this bot.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.bot.id == 'telegram') ...[
                    OutlinedButton.icon(
                      onPressed: _pairTelegram,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Set up with Telegram'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Or enter the details yourself.'),
                    ),
                  ],
                  for (final v in basic) _field(v),
                  if (advanced.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Advanced'),
                      maintainState: true,
                      initiallyExpanded: advanced.any(
                        (v) => v.required && !v.isSet,
                      ),
                      children: [for (final v in advanced) _field(v)],
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(HermesBotEnvVar v) {
    final cleared = _cleared.contains(v.key);
    final helper = [
      if (cleared)
        'Will be cleared'
      else if (v.isSet)
        'Set (${v.redactedValue ?? 'hidden'}). Leave blank to keep it.',
      if (v.help.isNotEmpty)
        v.help
      else if (v.description.isNotEmpty)
        v.description,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _controllers[v.key],
        readOnly: cleared,
        obscureText: v.isPassword,
        autocorrect: false,
        enableSuggestions: !v.isPassword,
        decoration: InputDecoration(
          labelText: v.label,
          helperText: helper.join('\n'),
          helperMaxLines: 4,
          suffixIcon: v.isSet && !v.required
              ? IconButton(
                  tooltip: cleared ? 'Keep ${v.label}' : 'Clear ${v.label}',
                  icon: Icon(cleared ? Icons.undo : Icons.delete_outline),
                  onPressed: () => _toggleCleared(v.key),
                )
              : null,
        ),
        validator: (value) =>
            v.required && !v.isSet && (value ?? '').trim().isEmpty
            ? 'Required'
            : null,
      ),
    );
  }
}
