import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';

/// The platform's alert for a question about a credential. Cancel (or "Keep
/// waiting") is the bold default on iOS and macOS and comes first, and the
/// action that removes or sends something is red text, never a filled red
/// button and never the default, so Return does not trigger it on a Mac. The
/// library's Material alert would fill its default button, which would make
/// Cancel look primary, so on Android both are text buttons with Cancel
/// first and the action in the error colour. Answers true only when the
/// action was tapped.
Future<bool> _ask(
  BuildContext context, {
  required String title,
  String? body,
  required String action,
  String? cancel,
  bool destructive = true,
}) async {
  final cancelLabel =
      cancel ?? MaterialLocalizations.of(context).cancelButtonLabel;
  final apple = platformChromeOf(context).isApple;
  final result = await showAppDialog<bool>(
    context: context,
    builder: (dialog) {
      final error = Theme.of(dialog).colorScheme.error;
      return AppAlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          if (apple)
            AppDialogAction(
              isDefault: true,
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(cancelLabel),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(cancelLabel),
            ),
          if (apple)
            AppDialogAction(
              isDestructive: destructive,
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            )
          else
            TextButton(
              style: destructive
                  ? TextButton.styleFrom(foregroundColor: error)
                  : null,
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
        ],
      );
    },
  );
  return result ?? false;
}

/// A removal question's body: what stops working, and when the provider
/// serves the default model, that new chats cannot start.
String _removalBody(
  AppLocalizations l10n, {
  required String provider,
  required String profile,
  required bool servesDefault,
}) => [
  l10n.providersAlertCantUse(profile, provider),
  if (servesDefault) l10n.providersAlertDefaultWarning(profile),
].join(' ');

bool _mac(BuildContext context) =>
    platformChromeOf(context) == PlatformChrome.macos;

/// "Remove the &lt;provider&gt; key?"
Future<bool> confirmRemoveKey(
  BuildContext context, {
  required String provider,
  required String profile,
  bool servesDefault = false,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertRemoveKeyTitle(provider),
    body: _removalBody(
      l10n,
      provider: provider,
      profile: profile,
      servesDefault: servesDefault,
    ),
    action: _mac(context)
        ? l10n.providersAlertRemoveKeyActionMac
        : l10n.providersAlertRemoveKeyAction,
  );
}

/// "Sign out of &lt;provider&gt;?"
Future<bool> confirmSignOut(
  BuildContext context, {
  required String provider,
  required String profile,
  bool servesDefault = false,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertSignOutTitle(provider),
    body: _removalBody(
      l10n,
      provider: provider,
      profile: profile,
      servesDefault: servesDefault,
    ),
    action: _mac(context)
        ? l10n.providersAlertSignOutActionMac
        : l10n.providersAlertSignOutAction,
  );
}

/// "Delete &lt;name&gt;?"
Future<bool> confirmDeleteEndpoint(
  BuildContext context, {
  required String name,
  required String profile,
  bool hasKey = true,
  bool servesDefault = false,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertDeleteEndpointTitle(name),
    body: [
      hasKey
          ? l10n.providersAlertDeleteEndpointKeyBody
          : l10n.providersAlertDeleteEndpointBody(profile),
      if (servesDefault) l10n.providersAlertDefaultWarning(profile),
    ].join(' '),
    action: l10n.providersAlertDeleteAction,
  );
}

/// "Remove the saved key for &lt;name&gt;?"
Future<bool> confirmRemoveEndpointKey(
  BuildContext context, {
  required String name,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertRemoveSavedKeyTitle(name),
    body: l10n.providersAlertRemoveSavedKeyBody,
    action: l10n.providersAlertRemoveAction,
  );
}

/// "Stop signing in to &lt;provider&gt;?", with "Keep waiting" as the default.
Future<bool> confirmStopSignIn(
  BuildContext context, {
  required String provider,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertStopTitle(provider),
    body: l10n.providersAlertStopBody,
    action: l10n.providersAlertStopAction,
    cancel: l10n.providersAlertKeepWaiting,
  );
}

/// "Send the key unencrypted?" before a key goes to an `http://` address that
/// is not local to the server. [address] is the host, shown as text.
Future<bool> confirmCleartextKey(
  BuildContext context, {
  required String address,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertCleartextTitle,
    body: l10n.providersAlertCleartextBody(address),
    action: l10n.providersKeySaveAnyway,
  );
}

/// "Use this model?" with Hermes' own [message] as its body, when Hermes
/// asks for a confirmation of an expensive model. "Use it anyway" is a plain
/// action, not a destructive one; Cancel stays the default.
Future<bool> confirmExpensiveModel(
  BuildContext context, {
  required String message,
}) {
  final l10n = context.l10n;
  return _ask(
    context,
    title: l10n.providersAlertModelTitle,
    body: message,
    action: l10n.providersAlertModelAction,
    destructive: false,
  );
}
