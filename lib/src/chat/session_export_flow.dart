import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
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
import 'widgets/chat_composer.dart';
import 'widgets/session_export_alert.dart';

/// The controller a screen owns for "Export chat as JSON". The file goes out
/// through the system save sheet only: the screen's [MediaStore] saves it from
/// memory (it never stages it), or the platform's own save where there is no
/// store. On iOS the picker's temporary copy is cleared when the sheet returns.
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
    // iOS only: file_picker writes a temporary copy before the save sheet. The
    // clear is global, which is safe because picked composer files are copied
    // out of the plugin's directory at pick time.
    clearTemporaryFiles: defaultTargetPlatform == TargetPlatform.iOS
        ? FilePicker.clearTemporaryFiles
        : null,
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

  var open = false;
  late final Future<void> Function() present;

  Future<void> confirm() async {
    final result = await controller.confirm();
    if (result == SessionExportSaveResult.saved) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(savedText),
          behavior: SnackBarBehavior.floating,
          margin: context.mounted
              ? _aboveComposer(context)
              : const EdgeInsets.all(_snackBarInset),
        ),
      );
    } else if (!open && controller.phase is SessionExportFailed) {
      // The save sheet failed after the alert had closed behind it: show the
      // failure again, or nothing could close it and a new export would be
      // refused.
      if (context.mounted) {
        unawaited(present());
      } else {
        controller.close();
      }
    }
  }

  present = () async {
    open = true;
    await showAppDialog<void>(
      context: context,
      builder: (_) => _SessionExportDialog(
        controller: controller,
        onConfirm: () => unawaited(confirm()),
      ),
    );
    open = false;
    // Escape, a tap outside or the back gesture closed a confirmation or a
    // failure: only the progress is protected from that.
    switch (controller.phase) {
      case SessionExportConfirm() || SessionExportFailed():
        controller.close();
      case SessionExportProgress():
        // A navigation that pops every route (a notification tap, a deep
        // link) ignores PopScope: the alert is gone, so the run goes too.
        controller.cancel();
      case null:
        break;
    }
  };

  await present();
}

const _snackBarInset = 16.0;

/// The floating snack bar's margin: the design's 16 px inset, with the bottom
/// raised above the composer when the screen under [context] has one. A
/// Scaffold only lifts a snack bar above its own bottom widgets, and the
/// composer sits in the body, so without this the bar covers the send button.
EdgeInsets _aboveComposer(BuildContext context) {
  const inset = EdgeInsets.all(_snackBarInset);
  // The save already succeeded: a measuring failure must not cost the notice.
  try {
    debugSessionExportMeasureHook?.call();
    Element? composer;
    void find(Element element) {
      if (composer != null) return;
      if (element.widget.key == chatComposerKey) {
        composer = element;
        return;
      }
      element.visitChildren(find);
    }

    (context as Element).visitChildren(find);
    final found = composer;
    final scaffold = found == null ? null : Scaffold.maybeOf(found);
    final box = found?.renderObject;
    final scaffoldBox = scaffold?.context.findRenderObject();
    if (found == null ||
        scaffold == null ||
        box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        scaffoldBox is! RenderBox ||
        !scaffoldBox.attached ||
        !scaffoldBox.hasSize) {
      return inset;
    }
    // The Scaffold strips the keyboard inset from its body's MediaQuery, so
    // it is read from the Scaffold's own context; the body ends above it.
    final composerTop = box.localToGlobal(Offset.zero).dy;
    final contentBottom =
        scaffoldBox.localToGlobal(Offset(0, scaffoldBox.size.height)).dy -
        MediaQuery.viewInsetsOf(scaffold.context).bottom;
    final bottom = contentBottom - composerTop + _snackBarInset;
    if (!bottom.isFinite) return inset;
    return inset.copyWith(bottom: max(_snackBarInset, bottom));
  } on Object {
    return inset;
  }
}

/// Runs inside [_aboveComposer]'s measuring; a test makes it throw.
@visibleForTesting
void Function()? debugSessionExportMeasureHook;

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
    // A newer phase came back before the frame (a late failure): stay.
    if (_controller.phase != null) {
      _closing = false;
      return;
    }
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
