import 'dart:async';

import 'package:flutter/material.dart';

import '../../../widgets/adaptive_sheet.dart';
import '../context_controller.dart';
import '../widgets/compress_confirmation.dart';

/// What the confirmation answered: Compress, with the focus the user wrote.
class _Confirmed {
  const _Confirmed(this.focus);
  final String? focus;
}

/// Asks to compress the chat of [controller]: starts it with
/// [ContextController.beginCompress], shows "Compress this conversation?"
/// (a sheet on a phone, a dialog on a Mac and wide layouts, Cancel first),
/// and only on Compress sends it with [ContextController.confirmCompress].
/// The sheet closes at once; the panel shows the compress in flight and its
/// outcome.
///
/// The focus text lives in the sheet's field and goes straight to the
/// controller; it is never kept or logged. [changes] tells the sheet that a
/// reply started (Compress then waits, disabled). The sheet closes by itself
/// when the compress can no longer be sent (App Lock, a lost connection).
/// Returns whether the compress was sent.
Future<bool> confirmCompressFlow(
  BuildContext context, {
  required ContextController controller,
  required Listenable changes,
}) async {
  final intent = controller.beginCompress();
  if (intent == null) return false;
  // From the root navigator, so a phone shows the sheet over the whole
  // screen and not inside the panel's own pages.
  final root = Navigator.of(context, rootNavigator: true).context;
  final answer = await showAdaptiveSheet<_Confirmed>(
    root,
    builder: (sheet) =>
        _CompressSheet(controller: controller, changes: changes),
  );
  if (answer == null) return false;
  unawaited(controller.confirmCompress(intent, focus: answer.focus));
  return true;
}

class _CompressSheet extends StatefulWidget {
  const _CompressSheet({required this.controller, required this.changes});

  final ContextController controller;
  final Listenable changes;

  @override
  State<_CompressSheet> createState() => _CompressSheetState();
}

class _CompressSheetState extends State<_CompressSheet> {
  late final Listenable _both = Listenable.merge([
    widget.controller,
    widget.changes,
  ]);
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _both.addListener(_changed);
  }

  @override
  void dispose() {
    _both.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted || _closed) return;
    final refusal = widget.controller.compressRefusal;
    if (refusal != null && refusal != CompressRefusal.replying) {
      // The compress can no longer be sent: the sheet goes, nothing is sent.
      _closed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    setState(() {});
  }

  void _close([_Confirmed? answer]) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(answer);
  }

  @override
  Widget build(BuildContext context) => CompressConfirmation(
    replyStarted: widget.controller.compressRefusal == CompressRefusal.replying,
    onConfirm: (focus) => _close(_Confirmed(focus)),
    onCancel: _close,
  );
}
