import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../activity/activity_page_binding.dart';
import '../../activity/widgets/activity_page_scaffold.dart';
import '../../activity/widgets/activity_working_line.dart';
import '../../chat_controller.dart';
import '../../chat_models.dart';
import '../context_controller.dart';
import '../widgets/compress_conversation_action.dart';
import '../widgets/compress_outcome_note.dart';
import '../widgets/context_category_list.dart';
import '../widgets/context_summary.dart';
import 'compress_flow.dart';

/// "Context", pushed inside the Activity panel: how full [thread]'s window
/// is, what fills it (read when the page opens, dropped when it closes), and
/// the one action, Compress conversation…, behind a confirmation.
///
/// With [compressOnOpen] (the suggestion's Compress…) the confirmation opens
/// over the page as soon as it shows.
class ContextDetailsPage extends StatefulWidget {
  const ContextDetailsPage({
    super.key,
    required this.chat,
    required this.thread,
    this.from = ContextOpenFrom.row,
    this.compressOnOpen = false,
  });

  final ChatController chat;
  final ChatThread thread;
  final ContextOpenFrom from;
  final bool compressOnOpen;

  static Route<void> route({
    required ChatController chat,
    required ChatThread thread,
    ContextOpenFrom from = ContextOpenFrom.row,
    bool compressOnOpen = false,
  }) => MaterialPageRoute<void>(
    builder: (_) => ContextDetailsPage(
      chat: chat,
      thread: thread,
      from: from,
      compressOnOpen: compressOnOpen,
    ),
  );

  @override
  State<ContextDetailsPage> createState() => _ContextDetailsPageState();
}

class _ContextDetailsPageState extends State<ContextDetailsPage>
    with ActivityPageBinding<ContextDetailsPage, ContextController> {
  @override
  ChatController get chat => widget.chat;

  @override
  ChatThread get thread => widget.thread;

  @override
  ContextController? lookUpController() => switch (currentThread) {
    final thread? => widget.chat.contextIn(thread),
    null => null,
  };

  @override
  bool lockedOf(ContextController controller) => controller.locked;

  @override
  void initState() {
    super.initState();
    bindController();
    // After the first frame: reading notifies, and this runs while the
    // navigator builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = this.controller;
      if (!mounted || controller == null || controller.locked) return;
      unawaited(controller.openDetails(from: widget.from));
      if (widget.compressOnOpen) _compress();
    });
  }

  @override
  void dispose() {
    unbindController();
    // After this frame: closing notifies the panel, which may be building.
    final controller = this.controller;
    if (controller != null) scheduleMicrotask(controller.closeDetails);
    super.dispose();
  }

  void _compress() {
    final controller = this.controller;
    if (controller == null) return;
    unawaited(
      confirmCompressFlow(
        context,
        controller: controller,
        changes: widget.chat,
      ),
    );
  }

  ContextCategoryListState _listState(ContextController controller) {
    if (!controller.breakdownSupported) {
      return ContextCategoryListState.unsupported;
    }
    if (controller.breakdown != null) return ContextCategoryListState.loaded;
    if (controller.breakdownFailed) return ContextCategoryListState.failed;
    // Nothing can be read while the connection is lost: the list is left
    // out rather than loading for ever.
    if (controller.notUpToDate) return ContextCategoryListState.unsupported;
    return ContextCategoryListState.loading;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    final figures = controller.figures;
    final outcome = controller.outcome;
    final breakdown = controller.breakdown;
    return ActivityPageScaffold(
      title: l10n.chatContextLabel,
      onBack: () => Navigator.of(context).maybePop(),
      // A handful of parts: built at once, so none is missing offscreen.
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.compressing)
              ActivityWorkingLine(label: l10n.chatContextCompressing),
            if (outcome != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: CompressOutcomeNote(
                  key: const Key('context-outcome'),
                  outcome: outcome,
                  onTryAgain: _compress,
                ),
              ),
            if (figures != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ContextSummary(
                  figures: figures,
                  level: controller.level,
                  notUpToDate: controller.notUpToDate,
                  model: breakdown?.model,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ContextCategoryList(
                state: _listState(controller),
                categories: breakdown?.categories ?? const [],
                // Reads the breakdown again while the page is open.
                onRetry: () => unawaited(controller.turnEnded()),
              ),
            ),
            CompressConversationAction(
              refusal: controller.compressRefusal,
              overLimit: figures != null && figures.used > figures.max,
              onCompress: _compress,
            ),
          ],
        ),
      ),
    );
  }
}
