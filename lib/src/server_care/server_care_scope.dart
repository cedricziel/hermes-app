import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'server_attention_mark.dart';
import 'server_care_controller.dart';

/// The attention mark for the account button; none outside an [AppShell], so
/// a widget built without one (a test, the catalog) shows no mark.
ServerAttentionMark serverAttentionMarkOf(BuildContext context) {
  try {
    return context.watch<ServerCareController>().mark;
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
