import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../media/media_source.dart';
import '../media/media_store.dart';
import '../media/quick_look.dart';
import '../media/quick_look_telemetry.dart';
import '../widgets/quick_look_target.dart';

/// Whether [attachment] has a file to work with: a path Hermes can serve and,
/// with [local], the bytes the history embedded or the file the user picked.
bool attachmentHasFile(
  ChatAttachment attachment,
  MediaStore? store, {
  required bool local,
}) =>
    store != null &&
    (attachment.fetchPath != null || (local && _isLocal(attachment)));

/// Whether making a file of [attachment] reads no server: the bytes or the
/// picked file are on this device.
bool _isLocal(ChatAttachment attachment) =>
    attachment.bytes != null || attachment.path != null;

/// [attachment] as a file in the media cache, which is where the system's
/// Quick Look, Open and Save read from. What the message embedded is written
/// there, a file the user picked is copied (the panel must not read outside
/// the app's container), and the rest is downloaded, once: the same file the
/// card's Open and a drag out of the app use.
///
/// Without [local] only the server's file is considered, as before Quick Look.
Future<File> stageAttachment(
  MediaStore store,
  ChatAttachment attachment, {
  required bool local,
}) {
  final bytes = local ? attachment.bytes : null;
  if (bytes != null) {
    return store.stageBytes(
      'embedded:${sha256.convert(bytes)}',
      attachment.name,
      bytes,
    );
  }
  final path = local ? attachment.path : null;
  final remote = attachment.fetchPath;
  if (path != null) {
    final copy = store.stageCopy(attachment.name, File(path));
    // A picked file that moved away may still be on the server.
    if (remote == null) return copy;
    return copy.onError<MediaFetchException>(
      (_, _) => store.file(remote, attachment.name),
    );
  }
  if (remote == null) {
    return Future.error(const MediaFetchException(MediaFailure.missing));
  }
  return store.file(remote, attachment.name);
}

/// What a widget showing an attachment needs to open, save and preview its
/// file: one request at a time, with the loading and failure states the
/// widget draws.
mixin AttachmentFileActions<T extends StatefulWidget> on State<T> {
  ChatAttachment get attachment;

  /// A request is running; the widget shows its loading state, and further
  /// requests are ignored until it ends.
  bool get busy => _busy;
  var _busy = false;

  /// Whether [attachment] has a file to open, save or preview. On a Mac that
  /// includes files on this device; elsewhere only the server's.
  bool get hasFile => attachmentHasFile(
    attachment,
    context.read<MediaStore?>(),
    local: quickLookTargetsAt(context),
  );

  /// Tells the user why the file could not be fetched.
  void failedToFetch(MediaFailure reason);

  /// A new request starts; the widget forgets an earlier failure.
  void clearFetchFailure() {}

  /// Makes the file and hands it to [then]. A request for a widget that has
  /// gone by the time the file arrived does nothing.
  ///
  /// With [preview], a failure is also reported to telemetry as a failed
  /// Quick Look.
  Future<void> useFile(
    Future<void> Function(MediaStore store, File file) then, {
    QuickLookTrigger? preview,
  }) async {
    final store = context.read<MediaStore?>();
    if (store == null || _busy || !hasFile) return;
    final local = quickLookTargetsAt(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final telemetry = QuickLookTelemetry.of(context);
    setState(() {
      _busy = true;
      clearFetchFailure();
    });
    try {
      final file = await stageAttachment(store, attachment, local: local);
      if (!mounted) return;
      await then(store, file);
    } on MediaFetchException catch (e) {
      if (preview != null) {
        telemetry.failed(
          QuickLookSource.chat,
          preview,
          stage: _isLocal(attachment)
              ? QuickLookStage.stageLocal
              : QuickLookStage.download,
          reason: e.reason.name,
        );
      }
      if (mounted) failedToFetch(e.reason);
    } on Object {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Wraps [child] so that, on macOS, it is selected by a click, opened by
  /// [onOpen] on a double-click, previewed with Space and offered the context
  /// menu (see [QuickLookTarget]). Elsewhere it is [child].
  Widget quickLookTarget({
    required Widget child,
    required VoidCallback? onOpen,
  }) {
    final available = hasFile;
    VoidCallback? preview(QuickLookTrigger trigger, {required bool toggle}) =>
        !available
        ? null
        : () => useFile(
            (store, file) =>
                showInQuickLook(store, file, trigger: trigger, toggle: toggle),
            preview: trigger,
          );
    return QuickLookTarget(
      borderRadius: BorderRadius.circular(kHermesRadius),
      onOpen: onOpen,
      onToggle: preview(QuickLookTrigger.key, toggle: true),
      onShow: preview(QuickLookTrigger.menu, toggle: false),
      onSave: available ? () => useFile(saveToDevice) : null,
      child: child,
    );
  }

  /// Hands [file] to the app the system has for its type.
  Future<void> openWithSystem(MediaStore store, File file) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await store.open(file)) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No app can open this file.')),
      );
    }
  }

  /// Asks where to keep [file], under the attachment's name.
  Future<void> saveToDevice(MediaStore store, File file) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = attachment.name;
    if (await store.save(name, await file.readAsBytes())) {
      messenger?.showSnackBar(SnackBar(content: Text('Saved $name')));
    }
  }

  /// Shows [file] in the Quick Look panel: with [toggle], closes the panel
  /// when it already shows it.
  Future<void> showInQuickLook(
    MediaStore store,
    File file, {
    required QuickLookTrigger trigger,
    required bool toggle,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final telemetry = QuickLookTelemetry.of(context);
    switch (await store.showQuickLook(file, toggle: toggle)) {
      case QuickLookToggle.shown:
        telemetry.opened(QuickLookSource.chat, trigger);
      case QuickLookToggle.closed:
        break;
      case QuickLookToggle.failed:
        telemetry.failed(
          QuickLookSource.chat,
          trigger,
          stage: QuickLookStage.native,
          reason: 'unavailable',
        );
        messenger?.showSnackBar(
          const SnackBar(
            content: Text("Quick Look couldn't preview this file."),
          ),
        );
    }
  }
}
