import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../models/auth_provider_info.dart';

/// Sign-in screen. Every registered provider — OIDC/OAuth or the bundled
/// username/password provider alike — signs in through the same RFC 8252
/// native flow: tapping a provider opens the system browser (so an OIDC
/// provider can run its normal login, and so the OS password manager can
/// autofill Hermes's own credential form), and this app only ever receives
/// the resulting bearer token set back via the loopback redirect.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final signingIn = auth.state == HermesConnectionState.signingIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        actions: [
          IconButton(
            tooltip: 'Change server',
            icon: const Icon(Icons.dns_outlined),
            onPressed: signingIn ? null : () => auth.changeServer(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    auth.baseUrl ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (signingIn)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          const Text('Continue in your browser…'),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: auth.cancelSignIn,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    )
                  else if (auth.status?.lacksNativePkce ?? false)
                    const Text(
                      "This server doesn't support app sign-in. Update the "
                      'Hermes dashboard, or sign in from its web UI.',
                      textAlign: TextAlign.center,
                    )
                  else if (auth.providers.isEmpty)
                    const Text(
                      'No sign-in providers are registered on this server.',
                    )
                  else
                    ...auth.providers.map(
                      (provider) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProviderButton(provider: provider),
                      ),
                    ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.provider});

  final AuthProviderInfo provider;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final label = provider.supportsPassword
        ? 'Sign in with username & password'
        : 'Sign in with ${provider.displayName}';
    return FilledButton.icon(
      icon: Icon(
        provider.supportsPassword ? Icons.password : Icons.open_in_browser,
      ),
      label: Text(label),
      onPressed: () => auth.signInWithProvider(provider),
    );
  }
}
