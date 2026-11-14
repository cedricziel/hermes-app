import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import 'server_attention_mark.dart';
import 'server_care_controller.dart';

/// The attention mark for the account button; none outside an [AppShell], so
/// a widget built without one (a test, the catalog) shows no mark.
ServerAttentionMark serverAttentionMarkOf(BuildContext context) {
  try {
    return context.select<ServerCareController, ServerAttentionMark>(
      (care) => care.mark,
    );
  } on ProviderNotFoundException {
    return ServerAttentionMark.none;
  }
}

/// Whether the account menu offers Server: the shell provides a controller
/// and the server has a status route.
bool serverCareOffered(BuildContext context) {
  try {
    return context.read<ServerCareController>().supported;
  } on ProviderNotFoundException {
    return false;
  }
}

/// The Mac sidebar row's caption for [mark]; null when there is nothing to
/// say.
String? serverMarkCaption(AppLocalizations l10n, ServerAttentionMark mark) =>
    switch (mark) {
      ServerAttentionMark.none => null,
      ServerAttentionMark.needsAttention =>
        l10n.serverCareSidebarCaptionNeedsAttention,
      ServerAttentionMark.updating => l10n.serverCareSidebarCaptionUpdating,
      ServerAttentionMark.restarting => l10n.serverCareSidebarCaptionRestarting,
    };

/// The account button's accessible label for [mark].
String serverMarkAccountLabel(
  AppLocalizations l10n,
  ServerAttentionMark mark,
) => mark == ServerAttentionMark.needsAttention
    ? l10n.serverCareAccountButtonLabelNeedsAttention
    : l10n.serverCareAccountButtonLabel;
