import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';
import '../auth/connect_failure.dart';

final _vpnGuide = Uri.parse(
  'https://github.com/cedricziel/hermes-app#reaching-your-dashboard-over-a-vpn',
);

/// First-run screen: point the app at a `hermes dashboard` instance
/// (e.g. `http://192.168.1.20:9119`).
class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  late final _controller = TextEditingController(
    text: context.read<AuthController>().savedServerUrl ?? 'http://',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final connecting = auth.state == HermesConnectionState.connecting;
    final failure = auth.lastFailure;
    final hint = failure == null
        ? null
        : vpnHint(failure, vpnActive: auth.vpnActive);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.hub_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Connect to Hermes',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the address of your hermes dashboard.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Behind Tailscale or WireGuard? Enter its VPN address, '
                      'or run tailscale serve on the server for an https:// '
                      'address.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        _vpnGuide,
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Read the VPN setup guide'),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Dashboard URL',
                        hintText: 'http://192.168.1.20:9119',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a URL'
                          : null,
                      onFieldSubmitted: (_) => _submit(auth),
                    ),
                    if (auth.state == HermesConnectionState.connectionError &&
                        auth.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          hint,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: connecting ? null : () => _submit(auth),
                      child: connecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(AuthController auth) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    auth.connect(_controller.text);
  }
}
