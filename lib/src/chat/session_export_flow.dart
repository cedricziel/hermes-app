import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../api/hermes_api_client.dart';
import '../widgets/dialog_presentation.dart';
import 'media/media_actions.dart';
import 'media/media_store.dart';
import 'session_export_controller.dart';
import 'session_export_telemetry.dart';
import 'thread_export.dart';
import 'widgets/session_export_alert.dart';

/// The controller a screen owns for "Export chat as JSON". The file goes out
/// through the system save sheet only: the screen's [MediaStore] saves it from
/// memory (it never stages it), or the platform's own save where there is no
/// store. On iOS the picker's temporary copy is not cleared yet (see below).
SessionExportController newSessionExportController(
  BuildContext context, {
  required HermesApiClient api,
  SessionExportTelemetry telemetry = const SessionExportTelemetry(),
}) {
  MediaStore? store;
  try {
    store = context.read<MediaStore?>();
  } on ProviderNotFoundException {
    store = null;
  }
  final Future<bool> Function(String, Uint8List) save =
      store?.save ?? PlatformMediaActions().save;
  return SessionExportController(
    api: api,
    save: save,
    telemetry: telemetry,
    // No clear hook on any platform yet: FilePicker.clearTemporaryFiles is
    // global and can delete a pending composer attachment on iOS. It is wired
    // after picked files are copied out of the plugin's directory.
    clearTemporaryFiles: null,
  );
}

/// Opens the confirmation for the chat [sessionId] of [profile] and carries the
/// export through its alert: confirmation, progress, a failure or the save
/// sheet, then "Chat saved" once the file is written. [title] only names the
/// file the save sheet proposes. Does nothing without a [profile] or while
/// [controller] is busy.
///
/// The alert shows no title, so App Lock has nothing to blank; the controller
/// closing it (a lock, a sign-out, a change of profile or server) removes it.
Future<void> showSessionExport(
  BuildContext context,
  SessionExportController controller, {
  required String sessionId,
  required String? profile,
  required String title,
}) async {
  final began = controller.begin(
    sessionId,
    profile,
    fileName: threadExportFileName(title, extension: 'json'),
  );
  if (!began) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final savedText = context.l10n.chatSessionExportSaved;

  Future<void> confirm() async {
    final result = await controller.confirm();
    if (result == SessionExportSaveResult.saved) {
      messenger?.showSnackBar(SnackBar(content: Text(savedText)));
    }
  }

  final shown = showAppDialog<void>(
    context: context,
    builder: (_) => _SessionExportDialog(
      controller: controller,
      onConfirm: () => unawaited(confirm()),
    ),
  );
  await shown;
  // Escape, a tap outside or the back gesture closed a confirmation or a
  // failure: only the progress is protected from that.
  if (controller.phase case SessionExportConfirm() || SessionExportFailed()) {
    controller.close();
  }
}

class _SessionExportDialog extends StatefulWidget {
  const _SessionExportDialog({
    required this.controller,
    required this.onConfirm,
  });

  final SessionExportController controller;
  final VoidCallback onConfirm;

  @override
  State<_SessionExportDialog> createState() => _SessionExportDialogState();
}

class _SessionExportDialogState extends State<_SessionExportDialog> {
  SessionExportPhase? _last;
  var _closing = false;

  SessionExportController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _last = _controller.phase;
    _controller.addListener(_changed);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final phase = _controller.phase;
    if (phase != null) {
      setState(() => _last = phase);
      return;
    }
    if (_closing) return;
    _closing = true;
    // Not while the tree is building: a lock can arrive in any frame phase.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _close())
      ..scheduleFrame();
  }

  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) => SessionExportAlert(
    phase: _last ?? const SessionExportConfirm(),
    onConfirm: widget.onConfirm,
    onCancel: _controller.cancel,
    onRetry: _controller.retry,
    onClose: _controller.close,
  );
}
