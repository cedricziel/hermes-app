import 'package:material_ui/material_ui.dart';

import '../theme/app_icons.dart';
import '../widgets/adaptive_back_button.dart';
import '../widgets/content_column.dart';
import '../widgets/disclosure_tile.dart';
import '../widgets/named_icon_button.dart';
import 'hermes_messaging_repository.dart';
import 'telegram_pairing_screen.dart';
import 'whatsapp/whatsapp_pairing_telemetry.dart';
import 'whatsapp_pairing_screen.dart';
import '../chat/gateway_connection_transport.dart';
import '../widgets/route_dismissal.dart';
import '../telemetry/report_bug.dart';
import '../../l10n/l10n.dart';

/// A form for the credentials and settings a platform reads from its
/// environment. Values the dashboard already holds are never shown, only
/// that they are set; a field left blank keeps its value.
///
/// Pops `true` once the setup was saved.
class MessagingSetupScreen extends StatefulWidget {
  const MessagingSetupScreen({
    super.key,
    required this.platform,
    required this.repository,
    this.changeSource,
    this.whatsAppTelemetry,
  });

  final HermesMessagingPlatform platform;
  final HermesMessagingRepository repository;
  final GatewayConnectionTransport? changeSource;

  /// What the WhatsApp screen tells telemetry; one per Messaging visit, so the
  /// old-server event is logged once there.
  final WhatsAppPairingTelemetry? whatsAppTelemetry;

  @override
  State<MessagingSetupScreen> createState() => _MessagingSetupScreenState();
}

class _MessagingSetupScreenState extends State<MessagingSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final v in widget.platform.envVars) v.key: TextEditingController(),
  };
  final _cleared = <String>{};
  bool _saving = false;
  String? _error;

  /// The platform list is being read before the WhatsApp screen opens.
  bool _linking = false;

  /// The server answered that it cannot link WhatsApp this way: the button
  /// goes away.
  bool _linkUnsupported = false;

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
        widget.platform.id,
        env: env,
        clear: _cleared.toList(),
      );
      if (mounted) dismissRoute(context, true);
    } on Object catch (e, stack) {
      reportBug(e, stack, 'a messaging screen');
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
        builder: (_) => TelegramPairingScreen(
          repository: widget.repository,
          changeSource: widget.changeSource,
        ),
      ),
    );
    if (paired == true && mounted) dismissRoute(context, true);
  }

  /// Reads whether WhatsApp is already on (10 s at most, the button showing
  /// progress), then opens the screen that links it. Nothing is started yet.
  Future<void> _linkWhatsApp(String profile) async {
    if (_linking) return;
    setState(() => _linking = true);
    final wasEnabled = await whatsAppWasEnabled(widget.repository);
    if (!mounted) return;
    setState(() => _linking = false);
    final saved = await Navigator.push<WhatsAppSavedOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsAppPairingScreen(
          repository: widget.repository,
          profile: profile,
          wasEnabled: wasEnabled,
          telemetry: widget.whatsAppTelemetry,
          onUnsupported: () {
            if (mounted) setState(() => _linkUnsupported = true);
          },
        ),
      ),
    );
    if (saved != null && mounted) dismissRoute(context, saved);
  }

  /// The "Link WhatsApp" entry, for a profile named explicitly and a server
  /// that has the route.
  List<Widget> _whatsAppLink() {
    final profile = widget.repository.profile;
    if (widget.platform.id != 'whatsapp' ||
        profile == null ||
        _linkUnsupported) {
      return const [];
    }
    return [
      OutlinedButton.icon(
        onPressed: _linking ? null : () => _linkWhatsApp(profile),
        icon: _linking
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const AppIcon(AppIcons.magic),
        label: Text(context.l10n.messagingWhatsappTitle),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(context.l10n.messagingWhatsappOrEnterYourself),
      ),
    ];
  }

  void _toggleCleared(String key) {
    _controllers[key]!.clear();
    setState(() {
      if (!_cleared.add(key)) _cleared.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vars = widget.platform.envVars;
    final basic = vars.where((v) => !v.advanced);
    final advanced = vars.where((v) => v.advanced).toList();
    return Scaffold(
      appBar: AppBar(
        leading: const AdaptiveBackButton(previousTitle: 'Messaging'),
        leadingWidth: adaptiveBackLeadingWidth(context),
        title: Text(context.l10n.messagingSetupTitle(widget.platform.name)),
      ),
      body: ContentColumn(
        child: vars.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._whatsAppLink(),
                  Text(context.l10n.messagingSetupNothingToSetUp),
                ],
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.platform.id == 'telegram') ...[
                      OutlinedButton.icon(
                        onPressed: _pairTelegram,
                        icon: const AppIcon(AppIcons.magic),
                        label: const Text('Set up with Telegram'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Or enter the details yourself.'),
                      ),
                    ],
                    ..._whatsAppLink(),
                    for (final v in basic) _field(v),
                    if (advanced.isNotEmpty)
                      DisclosureTile(
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
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field(HermesMessagingEnvVar v) {
    final l10n = context.l10n;
    final cleared = _cleared.contains(v.key);
    final helper = [
      if (cleared)
        'Will be cleared'
      else if (v.isSet)
        l10n.messagingSetupHelperSet(
          v.redactedValue ?? l10n.messagingSetupValueHidden,
        ),
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
              ? NamedIconButton(
                  label: cleared ? 'Keep ${v.label}' : 'Clear ${v.label}',
                  icon: cleared ? AppIcons.undo : AppIcons.delete,
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
