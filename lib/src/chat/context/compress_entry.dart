import 'package:flutter/widgets.dart';

import 'context_controller.dart';

/// Opens the compress confirmation for [controller]'s chat, the same one the
/// Context details page shows, and confirms through it. It must start with
/// `controller.beginCompress()` and send only through `confirmCompress` with
/// that intent, after the user confirmed; when `beginCompress` returns null it
/// shows nothing and sends nothing.
///
/// Chat > Compress Conversation… calls it. The menu item stays off while a
/// screen has none.
typedef CompressConversationEntry = Future<void> Function(
  BuildContext context,
  ContextController controller,
);
