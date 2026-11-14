import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../activity/activity_page_binding.dart';
import '../../activity/widgets/activity_page_scaffold.dart';
import '../../chat_controller.dart';
import '../../chat_models.dart';
import '../checkpoint_models.dart';
import '../checkpoints_controller.dart';
import '../widgets/changed_files_list.dart';
import '../widgets/changes_page_message.dart';
import '../widgets/file_diff_view.dart';
import 'restore_flow.dart';

/// One changed file of checkpoint [hash], pushed from Changes: its diff,
/// "Restore this file…" in the bottom bar, and previous and next arrows (⌥↑
/// and ⌥↓) to walk the list. It reads the changes Changes holds and never
/// reads the diff itself.
///
/// After Restore this file is confirmed, the page goes back to Changes,
/// which is read again with the outcome note on top.
class FileChangePage extends StatefulWidget {
  const FileChangePage({
    super.key,
    required this.chat,
    required this.thread,
    required this.hash,
    required this.path,
  });

  final ChatController chat;
  final ChatThread thread;
  final String hash;
  final String path;

  static Route<void> route({
    required ChatController chat,
    required ChatThread thread,
    required String hash,
    required String path,
  }) => MaterialPageRoute<void>(
    builder: (_) =>
        FileChangePage(chat: chat, thread: thread, hash: hash, path: path),
  );

  @override
  State<FileChangePage> createState() => _FileChangePageState();
}

class _FileChangePageState extends State<FileChangePage>
    with ActivityPageBinding<FileChangePage, CheckpointsController> {
  late String _path = widget.path;

  @override
  ChatController get chat => widget.chat;

  @override
  ChatThread get thread => widget.thread;

  @override
  CheckpointsController? lookUpController() => switch (currentThread) {
    final thread? => widget.chat.checkpointsIn(thread),
    null => null,
  };

  @override
  bool lockedOf(CheckpointsController controller) => controller.locked;

  @override
  void initState() {
    super.initState();
    bindController();
  }

  @override
  void dispose() {
    unbindController();
    super.dispose();
  }

  Changes? _changes(CheckpointsController controller) {
    final changes = controller.changes;
    return controller.openHash == widget.hash && changes is Changes
        ? changes
        : null;
  }

  void _step(List<ChangedFile> files, int by) {
    final at = files.indexWhere((file) => file.path == _path);
    final next = at + by;
    if (at < 0 || next < 0 || next >= files.length) return;
    setState(() => _path = files[next].path);
  }

  void _restore(ChangedFile file) {
    final controller = this.controller;
    if (controller == null) return;
    unawaited(
      confirmRestoreFlow(
        context,
        controller: controller,
        changes: widget.chat,
        hash: widget.hash,
        filePath: file.path,
      ).then((sent) {
        // Back to Changes, which is read again.
        if (sent && mounted) Navigator.of(context).maybePop();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    final changes = _changes(controller);
    final files = changes?.files ?? const <ChangedFile>[];
    final at = files.indexWhere((file) => file.path == _path);
    final file = at < 0 ? null : files[at];
    void back() => Navigator.of(context).maybePop();
    if (file == null) {
      return ActivityPageScaffold(
        title: breakableFileName(splitChangedPath(_path).$2),
        titleLabel: splitChangedPath(_path).$2,
        onBack: back,
        body: ChangesPageMessage(
          status: controller.loadingChanges || controller.restoring
              ? ChangesPageStatus.loading
              : ChangesPageStatus.unreadable,
        ),
      );
    }
    final (folder, name) = splitChangedPath(file.path);
    final hasPrevious = at > 0, hasNext = at < files.length - 1;
    return ActivityPageScaffold(
      title: breakableFileName(name),
      titleLabel: name,
      subtitle: folder.isEmpty
          ? l10n.chatCheckpointsChangesTopOfFolder
          : folder,
      onBack: back,
      actions: [
        ActivityPageAction(
          key: const Key('file-previous'),
          label: l10n.chatCheckpointsPageFilePrevious,
          icon: AppIcons.expandLess,
          onPressed: hasPrevious ? () => _step(files, -1) : null,
        ),
        ActivityPageAction(
          key: const Key('file-next'),
          label: l10n.chatCheckpointsPageFileNext,
          icon: AppIcons.expandMore,
          onPressed: hasNext ? () => _step(files, 1) : null,
        ),
      ],
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            _step(files, -1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            _step(files, 1),
      },
      body: SingleChildScrollView(
        key: ValueKey(file.path),
        child: FileDiffView(
          file: file,
          truncated: changes?.truncated ?? false,
          showAction: false,
        ),
      ),
      bottom: FileRestoreAction(
        file: file,
        refusal: controller.restoreRefusal(filePath: file.path),
        restoring: controller.restoring,
        onRestore: () => _restore(file),
      ),
    );
  }
}
