import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../widgets/app_banner.dart';
import '../../../widgets/destructive_tint_button.dart';
import '../../../widgets/named_icon_button.dart';
import '../agent_models.dart';
import 'agent_note_field.dart';
import 'agent_output_view.dart';
import 'agent_row.dart';
import 'agent_state_glyph.dart';
import 'agent_widget_parts.dart';
import '../../widgets/tool_call_card.dart' show formatToolDuration;

/// Where a stop stands, as the detail draws it.
enum AgentStopStatus {
  idle,

  /// The confirmed stop is on its way.
  sending,

  /// The server accepted it.
  stopping,

  /// A lost answer; the list is being read again.
  checking,

  /// A successful re-read showed the agent had already ended.
  alreadyFinished,

  /// The check ended without an answer: Stop is offered again.
  unconfirmed,
  failed,

  /// The agent ended while the confirmation was open.
  ended,
  unsupported,

  /// The server lists the agent but does not let this device control it.
  notControllable,
}

/// What an agent's detail shows, as plain values.
class AgentDetailModel {
  const AgentDetailModel({
    required this.goal,
    required this.state,
    this.runTime,
    this.toolCount = 0,
    this.currentTool,
    this.startedByAgent = false,
    this.output,
    this.note,
    this.stop = AgentStopStatus.idle,
    this.offline = false,
    this.delivered,
    this.error,
  });

  final String goal;
  final AgentState state;
  final Duration? runTime;
  final int toolCount;

  /// The tool it is using now, while it runs.
  final String? currentTool;
  final bool startedByAgent;

  /// Null leaves the output section out (an older server, a failed
  /// delegation).
  final AgentOutputModel? output;

  /// Null leaves the note section out.
  final AgentNoteModel? note;
  final AgentStopStatus stop;
  final bool offline;

  /// The completion summary, once ended.
  final String? delivered;

  /// A failed delegation's error.
  final String? error;

  bool get active => state.active;

  @override
  String toString() => 'AgentDetailModel($state, $stop)';
}

/// One agent in the Activity panel: what it is doing, its recent output, a
/// note to it, and Stop. Reading comes first; Stop is a tinted secondary
/// action after the output and the note field, never beside Back.
class AgentDetailView extends StatelessWidget {
  const AgentDetailView({
    super.key,
    required this.model,
    required this.onBack,
    required this.onStop,
    required this.onSendNote,
    required this.onNoteChanged,
    required this.onCopyNote,
    required this.onJumpToLatest,
    this.onHolding,
    this.onClose,
    this.noteController,
    this.outputMaxHeight,
  });

  final AgentDetailModel model;
  final VoidCallback onBack;
  final VoidCallback? onStop;
  final VoidCallback? onSendNote;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback? onCopyNote;
  final VoidCallback onJumpToLatest;
  final ValueChanged<bool>? onHolding;

  /// Present in a phone sheet, which draws its own close control.
  final VoidCallback? onClose;
  final TextEditingController? noteController;
  final double? outputMaxHeight;

  bool get _controllable => model.stop != AgentStopStatus.notControllable;

  bool get _stopShown =>
      model.active &&
      _controllable &&
      switch (model.stop) {
        AgentStopStatus.idle ||
        AgentStopStatus.sending ||
        AgentStopStatus.checking ||
        AgentStopStatus.unconfirmed ||
        AgentStopStatus.failed => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final output = model.output;
    final note = model.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(onBack: onBack, onClose: onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  model.goal,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _Facts(model: model),
                if (model.startedByAgent)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AgentSubtleText(l10n.chatSubagentsStartedByAgent),
                  ),
                if (!model.active)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _endedLine(l10n),
                      style: TextStyle(color: subtle),
                    ),
                  ),
                ..._banners(l10n),
                if (_controllable && output != null) ...[
                  const SizedBox(height: 16),
                  AgentOutputView(
                    model: output,
                    onJumpToLatest: onJumpToLatest,
                    onHolding: onHolding,
                    maxHeight: outputMaxHeight,
                  ),
                ],
                if (_controllable && note != null && _noteShown(note)) ...[
                  const SizedBox(height: 16),
                  AgentNoteField(
                    // Offline or ended, nothing can be sent.
                    model: note.copyWith(
                      offline: note.offline || model.offline,
                      canSend: note.canSend && model.active && !model.offline,
                    ),
                    onChanged: onNoteChanged,
                    onSend: onSendNote,
                    onCopy: onCopyNote,
                    controller: noteController,
                  ),
                ],
                if (_stopShown) ...[
                  const Divider(height: 32),
                  _StopButton(model: model, onStop: onStop),
                  const SizedBox(height: 6),
                  AgentSubtleText(l10n.chatSubagentsStopFootnote),
                ],
                if (model.delivered != null && !model.active) ...[
                  const SizedBox(height: 16),
                  AgentSectionTitle(l10n.chatSubagentsDelivered),
                  const SizedBox(height: 4),
                  SelectableText(model.delivered!),
                ],
                if (model.error != null && !model.active) ...[
                  const SizedBox(height: 16),
                  AgentSectionTitle(l10n.chatSubagentsWentWrong),
                  const SizedBox(height: 4),
                  SelectableText(model.error!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// An ended agent takes no note: the section stays only for text typed
  /// and never sent, or to say a note missed.
  bool _noteShown(AgentNoteModel note) =>
      model.active ||
      (note.frozen && note.text.isNotEmpty) ||
      note.status == AgentNoteStatus.missed;

  String _endedLine(AppLocalizations l10n) => switch (model.state) {
    AgentState.finished => l10n.chatSubagentsEndedFinished,
    AgentState.failed => l10n.chatSubagentsEndedFailed,
    AgentState.stopped => l10n.chatSubagentsEndedStopped,
    _ => l10n.chatSubagentsEndedUnknown,
  };

  List<Widget> _banners(AppLocalizations l10n) {
    Widget banner(AppBannerTone tone, String title, [String detail = '']) =>
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppBanner(tone: tone, title: title, detail: detail),
        );
    return [
      if (model.offline)
        banner(AppBannerTone.neutral, l10n.chatSubagentsBannerOffline),
      ...switch (model.stop) {
        AgentStopStatus.stopping => [
          banner(
            AppBannerTone.success,
            l10n.chatSubagentsBannerStoppingTitle,
            l10n.chatSubagentsBannerStoppingDetail,
          ),
        ],
        AgentStopStatus.checking => [
          banner(
            AppBannerTone.warning,
            l10n.chatSubagentsBannerCheckingTitle,
            l10n.chatSubagentsBannerCheckingDetail,
          ),
        ],
        AgentStopStatus.unconfirmed => [
          banner(
            AppBannerTone.warning,
            l10n.chatSubagentsBannerCheckingTitle,
            l10n.chatSubagentsBannerUnconfirmedDetail,
          ),
        ],
        AgentStopStatus.alreadyFinished => [
          banner(
            AppBannerTone.success,
            l10n.chatSubagentsBannerAlreadyFinished,
          ),
        ],
        AgentStopStatus.ended => [
          banner(AppBannerTone.neutral, l10n.chatSubagentsBannerAgentEnded),
        ],
        AgentStopStatus.failed => [
          banner(
            AppBannerTone.error,
            l10n.chatSubagentsBannerStopFailedTitle,
            l10n.chatSubagentsBannerTryAgain,
          ),
        ],
        AgentStopStatus.unsupported => [
          banner(
            AppBannerTone.neutral,
            l10n.chatSubagentsBannerStopUnsupported,
          ),
        ],
        AgentStopStatus.notControllable => [
          banner(
            AppBannerTone.neutral,
            l10n.chatSubagentsBannerNotControllable,
          ),
        ],
        _ => const <Widget>[],
      },
    ];
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.model});

  final AgentDetailModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final word = AgentRow.stateWord(context, model.state);
    final time = model.runTime;
    final tools = model.toolCount > 0
        ? l10n.chatSubagentsToolCount(model.toolCount)
        : null;
    final line = time == null
        ? word
        : tools == null
        ? l10n.chatSubagentsRowLine(word, formatToolDuration(time))
        : l10n.chatSubagentsRowLineTools(word, formatToolDuration(time), tools);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AgentStateGlyph(state: model.state),
            const SizedBox(width: 8),
            // Only the state word is a live region: it is announced once,
            // politely, when it changes, and a refreshed run time is not.
            Expanded(child: _liveStateText(word, line)),
          ],
        ),
        if (model.active && model.currentTool != null)
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: Text(
              model.currentTool!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subtle),
            ),
          ),
      ],
    );
  }
}

Widget _liveStateText(String word, String line) {
  final rest = line.startsWith(word) ? line.substring(word.length) : '';
  return Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(liveRegion: true, child: Text(word)),
        ),
        TextSpan(text: rest),
      ],
    ),
  );
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.model, required this.onStop});

  final AgentDetailModel model;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = model.stop == AgentStopStatus.sending;
    final enabled =
        !model.offline &&
        onStop != null &&
        model.stop != AgentStopStatus.checking;
    final button = DestructiveTintButton(
      label: busy ? l10n.chatSubagentsStopBusy : l10n.chatSubagentsStopButton,
      icon: AppIcons.stop,
      busy: busy,
      onPressed: enabled ? onStop : null,
    );
    return agentLargeText(context)
        ? SizedBox(width: double.infinity, child: button)
        : Align(alignment: AlignmentDirectional.centerEnd, child: button);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onClose});

  final VoidCallback onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chrome = platformChromeOf(context);
    final close = onClose == null
        ? null
        : NamedIconButton(
            label: l10n.chatSubagentsDetailClose,
            icon: AppIcons.close,
            onPressed: onClose,
          );
    final title = Semantics(
      header: true,
      child: Text(
        l10n.chatSubagentsDetailTitle,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    final back = switch (chrome) {
      PlatformChrome.ios => TextButton.icon(
        onPressed: onBack,
        icon: const AppIcon(AppIcons.chevronLeft, size: 18),
        label: Text(l10n.chatSubagentsDetailBack),
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      _ => NamedIconButton(
        label: l10n.chatSubagentsDetailBackTooltip,
        icon: AppIcons.chevronLeft,
        onPressed: onBack,
      ),
    };
    // Bar text keeps its normal size at the largest text sizes, as bars do.
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: switch (chrome) {
          PlatformChrome.ios => Stack(
            alignment: Alignment.center,
            children: [
              Row(children: [back, const Spacer(), ?close]),
              title,
            ],
          ),
          _ => Row(
            children: [
              back,
              if (chrome == PlatformChrome.material) ...[
                const SizedBox(width: 4),
                title,
              ] else
                const SizedBox(width: 4),
              const Spacer(),
              ?close,
            ],
          ),
        },
      ),
    );
  }
}
