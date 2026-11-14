import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/settings_scaffold.dart';
import 'provider_flow.dart';
import 'provider_sign_in.dart';
import 'provider_view_mapper.dart';
import 'widgets/server_command_view.dart';
import 'widgets/sign_in_code_view.dart';

/// The sign-in step of [providerId], and the default-model step it ends in.
/// Leaving it never cancels the sign-in: the controller keeps following it
/// and the list shows it as waiting. The device code is only drawn here and
/// is never logged.
class ProviderSignInSheet extends StatelessWidget {
  const ProviderSignInSheet({
    super.key,
    required this.services,
    required this.providerId,
  });

  final ProviderFlowServices services;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final controller = services.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (stepIsFor(controller, providerId)) {
          return ProviderSheetKeys(
            onSubmit: null,
            child: ProviderStepPage(services: services, providerId: providerId),
          );
        }
        final signIn = controller.signInFor(providerId);
        if (signIn == null || signIn.phase == SignInPhase.cancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted &&
                controller.signInFor(providerId)?.pending != true &&
                !stepIsFor(controller, providerId)) {
              popIfCurrent(context);
            }
          });
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        final entry = controller.catalog?.byId(providerId);
        final name = entry?.name ?? providerId;
        final link = signIn.verificationLink;
        return ProviderSheetKeys(
          onSubmit: null,
          child: SettingsScaffold(
            title: l10n.providersSignInTitle(name),
            subtitle: services.profileLabel,
            cancel: true,
            macCancel: true,
            shrinkTitle: true,
            body: signIn.phase == SignInPhase.approved
                // The default-model step follows in the same turn.
                ? const Center(child: CircularProgressIndicator.adaptive())
                : SignInCodeView(
                    data: signInCodeData(
                      signIn,
                      name,
                      profile: services.profileLabel,
                    ),
                    onOpen: link == null ? null : () => services.openLink(link),
                    onStartAgain: () => controller.startSignIn(providerId),
                    onCheckAgain: () async {
                      final connected = await controller.checkAgain(providerId);
                      if (connected && context.mounted) {
                        controller.dismissSignIn(providerId);
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
          ),
        );
      },
    );
  }
}

/// "Connect &lt;provider&gt; on your server": the command to run, and "Check
/// again", which reads the providers again.
class ProviderServerSheet extends StatefulWidget {
  const ProviderServerSheet({
    super.key,
    required this.services,
    required this.providerId,
  });

  final ProviderFlowServices services;
  final String providerId;

  @override
  State<ProviderServerSheet> createState() => _ProviderServerSheetState();
}

class _ProviderServerSheetState extends State<ProviderServerSheet> {
  var _checking = false;

  Future<void> _check() async {
    final controller = widget.services.controller;
    setState(() => _checking = true);
    final connected = await controller.checkAgain(widget.providerId);
    if (!mounted) return;
    setState(() => _checking = false);
    if (connected) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final entry = services.controller.catalog?.byId(widget.providerId);
    if (entry == null) return const SizedBox.shrink();
    return ProviderSheetKeys(
      onSubmit: null,
      child: SettingsScaffold(
        title: entry.name,
        subtitle: services.profileLabel,
        formAction: serverCommandFormAction(
          context.l10n,
          onDone: () => Navigator.of(context).maybePop(),
        ),
        body: ServerCommandView(
          data: serverCommandData(
            entry,
            profile: services.profileLabel,
            checking: _checking,
          ),
          onCheckAgain: _check,
        ),
      ),
    );
  }
}
