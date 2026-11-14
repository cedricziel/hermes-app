import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../widgets/adaptive_sheet.dart';
import '../../widgets/relative_time.dart';
import '../checkpoint_models.dart';
import '../checkpoints_controller.dart';
import '../widgets/changed_files_list.dart';
import '../widgets/restore_all_confirmation.dart';
import '../widgets/restore_file_confirmation.dart';

/// The checkpoint and file of the last restore the user confirmed, so its
/// outcome note knows whether it was one file and Try again knows what to
/// offer again. Held beside the controller, in memory only.
class _LastRestore {
  const _LastRestore(this.hash, this.filePath);
  final String hash;
  final String? filePath;
}

final _lastRestore = Expando<_LastRestore>('lastRestore');

/// Whether the last restore confirmed on [controller] was one file: true,
/// false for all files, null when none was confirmed here.
bool? lastRestoreWasFile(CheckpointsController controller) {
  final last = _lastRestore[controller];
  return last == null ? null : last.filePath != null;
}

/// The checkpoint the last restore confirmed on [controller] went to.
String? lastRestoreHash(CheckpointsController controller) =>
    _lastRestore[controller]?.hash;

/// When [checkpoint] was taken, as a label ("12 min ago"), or null when its
/// time is unknown.
String? checkpointTimeLabel(AppLocalizations l10n, Checkpoint checkpoint) {
  final at = checkpoint.timestamp;
  return at == null ? null : relativeTimeLabel(l10n, at);
}

/// The exact time of [checkpoint] for a screen reader, or null.
String? checkpointTimeSemantics(AppLocalizations l10n, Checkpoint checkpoint) {
  final at = checkpoint.timestamp;
  return at == null ? null : exactTimeLabel(l10n, at);
}

Checkpoint? _listed(CheckpointsController controller, String hash) {
  for (final checkpoint in controller.checkpoints) {
    if (checkpoint.hash == hash) return checkpoint;
  }
  return null;
}

/// Asks to restore [hash]: every file when [filePath] is null, else that one
/// file. Starts the restore with [CheckpointsController.beginRestore], shows
/// the confirmation (a sheet on a phone, a dialog on a Mac and wide layouts,
/// Cancel first), and only on Restore sends it with
/// [CheckpointsController.confirmRestore]. The sheet closes at once; the
/// panel shows the restore in flight and its outcome.
///
/// [changes] is what tells the sheet that a reply started or stopped (the
/// chat controller). The sheet closes by itself when the restore can no
/// longer be sent (App Lock, a lost connection). Returns whether the restore
/// was sent.
Future<bool> confirmRestoreFlow(
  BuildContext context, {
  required CheckpointsController controller,
  required Listenable changes,
  required String hash,
  String? filePath,
}) async {
  final intent = controller.beginRestore(hash, filePath: filePath);
  if (intent == null) return false;
  final l10n = context.l10n;
  final checkpoint = _listed(controller, hash);
  final time =
      (checkpoint == null ? null : checkpointTimeLabel(l10n, checkpoint)) ??
      l10n.chatCheckpointsPageTimeUnknown;
  final reason = checkpoint?.reason ?? CheckpointReason.other;
  // From the root navigator, so a phone shows the sheet over the whole
  // screen and not inside the panel's own pages.
  final root = Navigator.of(context, rootNavigator: true).context;
  final confirmed = await showAdaptiveSheet<bool>(
    root,
    builder: (sheet) => _RestoreSheet(
      controller: controller,
      changes: changes,
      intent: intent,
      timeLabel: time,
      reason: reason,
    ),
  );
  if (confirmed != true) return false;
  _lastRestore[controller] = _LastRestore(hash, filePath);
  unawaited(controller.confirmRestore(intent));
  return true;
}

/// Offers the last restore of [controller] again, behind a new confirmation.
/// Nothing is sent before the user confirms it.
Future<bool> restoreAgainFlow(
  BuildContext context, {
  required CheckpointsController controller,
  required Listenable changes,
}) async {
  final last = _lastRestore[controller];
  if (last == null) return false;
  return confirmRestoreFlow(
    context,
    controller: controller,
    changes: changes,
    hash: last.hash,
    filePath: last.filePath,
  );
}

class _RestoreSheet extends StatefulWidget {
  const _RestoreSheet({
    required this.controller,
    required this.changes,
    required this.intent,
    required this.timeLabel,
    required this.reason,
  });

  final CheckpointsController controller;
  final Listenable changes;
  final RestoreIntent intent;
  final String timeLabel;
  final CheckpointReason reason;

  @override
  State<_RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends State<_RestoreSheet> {
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

  bool get _dead {
    final controller = widget.controller;
    final refusal = controller.restoreRefusal(filePath: widget.intent.filePath);
    return controller.locked ||
        controller.notUpToDate ||
        refusal == RestoreRefusal.unavailable ||
        refusal == RestoreRefusal.restoring;
  }

  void _changed() {
    if (!mounted || _closed) return;
    if (_dead) {
      // The restore can no longer be sent: the sheet goes, nothing is sent.
      _close(false, later: true);
      return;
    }
    setState(() {});
  }

  /// [later] waits for the frame, for a close that a notification asked
  /// for, which may come while another widget builds.
  void _close(bool confirmed, {bool later = false}) {
    if (_closed) return;
    _closed = true;
    if (!later) {
      Navigator.of(context).pop(confirmed);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(confirmed);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final intent = widget.intent;
    final replying =
        widget.controller.restoreRefusal() == RestoreRefusal.replying;
    if (intent.isFull) {
      return RestoreAllConfirmation(
        timeLabel: widget.timeLabel,
        reason: widget.reason,
        differingFiles: intent.filesDiffer,
        quotedPrompt: intent.quote?.text,
        replying: replying,
        onConfirm: () => _close(true),
        onCancel: () => _close(false),
      );
    }
    final (_, name) = splitChangedPath(intent.filePath!);
    return RestoreFileConfirmation(
      fileName: name,
      timeLabel: widget.timeLabel,
      reason: widget.reason,
      agentWorking: intent.agentWorking || replying,
      onConfirm: () => _close(true),
      onCancel: () => _close(false),
    );
  }
}
