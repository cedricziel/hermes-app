import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/destructive_tint_button.dart';
import '../../widgets/disclosure_tile.dart';
import '../process_output_state.dart';
import '../subagents/agent_models.dart';
import '../subagents/widgets/agent_state_glyph.dart';
import 'tool_call_card.dart' show formatToolDuration;

/// Where Hermes lists a background program: running, ended on request,
/// exited on its own, or gone without a completion.
enum ProcessCardStatus { running, stopped, exited, ended }

/// How the last Stop press went. [killed], [alreadyEnded] and [notListed] end
/// the question; [failed] and [unconfirmed] bring Stop back.
enum ProcessStopStatus {
  idle,
  sending,
  checking,
  killed,
  alreadyEnded,
  notListed,
  failed,
  unconfirmed,
}

/// What Hermes' program list says about a card. A card without it keeps the
/// wording it had before the list existed.
class ProcessCardInfo {
  const ProcessCardInfo({
    this.command,
    required this.status,
    this.exitCode,
    this.runTime,
    this.seeded = false,
    this.stop = ProcessStopStatus.idle,
  });

  final String? command;
  final ProcessCardStatus status;
  final int? exitCode;
  final Duration? runTime;

  /// The text came from the list and holds only the end of the output.
  final bool seeded;
  final ProcessStopStatus stop;
}

/// Hermes cuts a command at this many characters.
const kProcessCommandChars = 200;

String processCommandLine(String command) {
  final runes = command.runes.toList();
  if (runes.length < kProcessCommandChars) return command;
  return '${String.fromCharCodes(runes.take(kProcessCommandChars))}…';
}

class ProcessOutputCard extends StatelessWidget {
  const ProcessOutputCard({
    super.key,
    required this.output,
    this.omittedCards = false,
    this.initiallyOpen = false,
    this.onDetails,
    this.info,
    this.onStop,
  });
  final ProcessOutput? output;
  final bool omittedCards, initiallyOpen;
  final VoidCallback? onDetails;
  final ProcessCardInfo? info;

  /// Asks to stop the program; Stop shows only while it runs and this is set.
  final VoidCallback? onStop;
  @override
  Widget build(BuildContext context) {
    final process = output;
    if (process == null) return const Text('Process output unavailable');
    final info = this.info;
    return DisclosureTile(
      initiallyExpanded: initiallyOpen,
      dense: true,
      title: info == null
          ? Text(
              'Process ${process.processId} · ${process.closed ? 'Closed' : 'Output received'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : _Title(info: info),
      onExpansionChanged: (expanded) {
        if (expanded) onDetails?.call();
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          // Full width, so a short output sits at the start, not centred.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info != null && info.seeded && process.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      context.l10n.chatWidgetsProgramEarlierOmitted,
                      style: TextStyle(color: context.hermesColors.subtleText),
                    ),
                  ),
                if (process.text.isEmpty)
                  Text(
                    info == null
                        ? 'No output received.'
                        : context.l10n.chatWidgetsProgramNoOutput,
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: SelectableText(process.text),
                    ),
                  ),
                if (process.omitted && !(info?.seeded ?? false))
                  Text(
                    info == null
                        ? 'Earlier output omitted.'
                        : context.l10n.chatWidgetsProgramEarlierOmitted,
                  ),
                if (omittedCards)
                  Text(
                    info == null
                        ? 'Earlier process cards omitted.'
                        : context.l10n.chatWidgetsProgramOmittedCards,
                  ),
                if (info != null) _Controls(info: info, onStop: onStop),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.info});
  final ProcessCardInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = switch (info.status) {
      ProcessCardStatus.running => l10n.chatWidgetsProgramStateRunning,
      ProcessCardStatus.stopped => l10n.chatWidgetsProgramStateStopped,
      // An exit without a code is Ended, never "code 0".
      ProcessCardStatus.exited when info.exitCode == null =>
        l10n.chatWidgetsProgramStateEnded,
      ProcessCardStatus.exited => l10n.chatWidgetsProgramStateExited(
        info.exitCode!,
      ),
      ProcessCardStatus.ended => l10n.chatWidgetsProgramStateEnded,
    };
    final time = info.runTime;
    final line = time == null
        ? state
        : l10n.chatWidgetsProgramLine(state, formatToolDuration(time));
    final glyph = switch (info.status) {
      ProcessCardStatus.running => AgentState.running,
      ProcessCardStatus.stopped => AgentState.stopped,
      // A non-zero exit has its own shape, apart from a plain end.
      ProcessCardStatus.exited when (info.exitCode ?? 0) != 0 =>
        AgentState.failed,
      ProcessCardStatus.exited || ProcessCardStatus.ended => AgentState.ended,
    };
    final command = info.command;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (command != null && command.isNotEmpty)
          Text(
            processCommandLine(command),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        Row(
          children: [
            AgentStateGlyph(state: glyph, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(line)),
          ],
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.info, required this.onStop});
  final ProcessCardInfo info;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stop = info.stop;
    final banner = switch (stop) {
      ProcessStopStatus.idle || ProcessStopStatus.sending => null,
      ProcessStopStatus.killed => AppBanner(
        tone: AppBannerTone.success,
        title: l10n.chatWidgetsProgramOutcomeStopped,
      ),
      ProcessStopStatus.alreadyEnded => AppBanner(
        tone: AppBannerTone.success,
        title: l10n.chatWidgetsProgramOutcomeAlreadyEnded,
      ),
      ProcessStopStatus.notListed => AppBanner(
        tone: AppBannerTone.neutral,
        title: l10n.chatWidgetsProgramOutcomeNotListed,
      ),
      ProcessStopStatus.failed => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.chatWidgetsProgramOutcomeFailed,
        detail: l10n.chatSubagentsBannerTryAgain,
      ),
      ProcessStopStatus.checking => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.chatSubagentsBannerCheckingTitle,
        detail: l10n.chatSubagentsBannerCheckingDetail,
      ),
      ProcessStopStatus.unconfirmed => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.chatSubagentsBannerCheckingTitle,
        detail: l10n.chatSubagentsBannerUnconfirmedDetail,
      ),
    };
    final ended =
        stop == ProcessStopStatus.killed ||
        stop == ProcessStopStatus.alreadyEnded ||
        stop == ProcessStopStatus.notListed;
    final showStop =
        info.status == ProcessCardStatus.running && onStop != null && !ended;
    if (banner == null && !showStop) return const SizedBox.shrink();
    final sending = stop == ProcessStopStatus.sending;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?banner,
          if (banner != null && showStop) const SizedBox(height: 8),
          if (showStop)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DestructiveTintButton(
                label: sending
                    ? l10n.chatWidgetsProgramStopBusy
                    : l10n.chatWidgetsProgramStopButton,
                icon: AppIcons.stop,
                busy: sending,
                onPressed: stop == ProcessStopStatus.checking ? null : onStop,
              ),
            ),
        ],
      ),
    );
  }
}
