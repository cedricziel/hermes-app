import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/grouped_list.dart';
import 'terminal_backends_controller.dart';
import 'toolset_copy.dart';
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
  late TerminalBackendsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _newController();
    unawaited(_controller.load());
    widget.env.refresh.add(_controller.load);
  }

  TerminalBackendsController _newController() => TerminalBackendsController(
    widget.env.repository,
    telemetry: widget.env.repository.telemetry,
    confirmLocal: () =>
        widget.env.ask(toolsetLocalBackendQuestion(context.l10n)),
  );

  @override
  void didUpdateWidget(TerminalBackendsPanel old) {
    super.didUpdateWidget(old);
    if (old.env.repository.profile != widget.env.repository.profile) {
      _controller.switchProfile(widget.env.repository);
      unawaited(_controller.load());
    }
  }

  @override
  void dispose() {
    widget.env.refresh.remove(_controller.load);
    _controller.dispose();
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
      final writing =
          _controller.pickState == ToolsWriteState.saving ||
          _controller.pickState == ToolsWriteState.checking;
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
            onPick: (name) => unawaited(_controller.pick(name)),
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
