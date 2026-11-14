import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/grouped_list.dart';
import 'terminal_backends_controller.dart';
import 'tools_controller.dart' show ToolsLoadState;
import 'tools_models.dart';
import 'tools_panel_env.dart';
import 'tools_write.dart';
import 'widgets/provider_choice_section.dart';
import 'widgets/status_chip.dart';
import 'widgets/tools_load_state.dart';
import 'widgets/tools_note.dart';

/// "Where commands run" in the Terminal details: the backends Hermes lists,
/// the active one marked, and the pick between them.
///
/// Picking Local first asks "Run commands directly on your server?"; nothing
/// is sent until the user confirms. The section is gone when Hermes has no
/// backends route, whatever the toolset list says, and a failed read leaves
/// the rest of the details alone.
class TerminalBackendsPanel extends StatefulWidget {
  const TerminalBackendsPanel({super.key, required this.env});

  final ToolsPanelEnv env;

  @override
  State<TerminalBackendsPanel> createState() => _TerminalBackendsPanelState();
}

class _TerminalBackendsPanelState extends State<TerminalBackendsPanel> {
  /// The registry's controller: a pick goes on, and its result waits, when
  /// the panel is gone.
  late final TerminalBackendsController _controller =
      widget.env.registry.backends;

  bool get _writing =>
      _controller.pickState == ToolsWriteState.saving ||
      _controller.pickState == ToolsWriteState.checking;

  @override
  void initState() {
    super.initState();
    widget.env.registry.claim(_ownerKey, this);
    // After this frame, like the setup panel's read.
    scheduleMicrotask(() {
      if (mounted) unawaited(_controller.load());
    });
    widget.env.refresh.add(_load);
  }

  static const _ownerKey = 'backends';

  // Its own closure: a tear-off of the shared controller would be equal to
  // the one a replacing panel registered, and removing it would drop that.
  Future<void> _load() => _controller.load();

  @override
  void dispose() {
    widget.env.refresh.remove(_load);
    // Only the panel that shows the result sees it; one the layout replaced
    // leaves it to its successor.
    if (widget.env.registry.release(_ownerKey, this)) {
      _controller.acknowledge();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final state = _controller.loadState;
      if (state == ToolsLoadState.unsupported ||
          state == ToolsLoadState.profileGone) {
        return const SizedBox.shrink();
      }
      if (!_controller.hasLoaded) {
        return GroupedSection(
          header: l10n.toolsBackendsHeader,
          children: [
            if (state == ToolsLoadState.loading)
              ToolsLoadingRow(l10n.toolsBackendsLoading)
            else
              ToolsFailureRow(
                text: l10n.toolsBackendsLoadFailed,
                onRetry: () => unawaited(_controller.load()),
              ),
          ],
        );
      }
      final writing = _writing || widget.env.locked;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProviderChoiceSection(
            header: l10n.toolsBackendsHeader,
            footer: l10n.toolsBackendsFooter,
            enabled: !writing,
            choices: [
              for (final backend in _controller.backends)
                _choice(backend, picked: backend.name == _controller.active),
            ],
            onPick: (name) {
              if (!widget.env.locked) unawaited(_controller.pick(name));
            },
          ),
          ?_note(context),
        ],
      );
    },
  );

  ProviderChoice _choice(TerminalBackend backend, {required bool picked}) {
    final ready = backend.status == BackendStatus.ready;
    final detail = backend.detail?.trim();
    return ProviderChoice(
      id: backend.name,
      name: backend.label,
      status: ToolsStatus.fromBackend(backend.status),
      picked: picked,
      line: backend.description.isEmpty ? null : backend.description,
      hermesText: !ready && detail != null && detail.isNotEmpty ? detail : null,
      commandsWillFail: picked && !ready,
    );
  }

  Widget? _note(BuildContext context) {
    final l10n = context.l10n;
    final desktop = toolsOnDesktop(context);
    return switch (_controller.pickState) {
      ToolsWriteState.idle => null,
      ToolsWriteState.saving => ToolsLoadingRow(l10n.toolsWriteSaving),
      ToolsWriteState.checking => ToolsLoadingRow(l10n.toolsRowChecking),
      ToolsWriteState.unconfirmed => ToolsNote(
        tone: ToolsNoteTone.warning,
        text: desktop
            ? l10n.toolsRowUnconfirmedRetry
            : l10n.toolsRowUnconfirmedPull,
        actionLabel: desktop ? l10n.toolsTryAgain : null,
        onAction: desktop ? () => unawaited(_controller.load()) : null,
      ),
      ToolsWriteState.notApplied => ToolsNote(
        tone: ToolsNoteTone.warning,
        text: l10n.toolsWriteNotApplied,
      ),
      ToolsWriteState.refused => ToolsNote(
        tone: ToolsNoteTone.error,
        text: (_controller.refusalDetail?.trim().isNotEmpty ?? false)
            ? _controller.refusalDetail!
            : l10n.toolsWriteFailedBackend,
      ),
      ToolsWriteState.failed => ToolsNote(
        tone: ToolsNoteTone.error,
        text: l10n.toolsWriteFailedBackend,
      ),
    };
  }
}
