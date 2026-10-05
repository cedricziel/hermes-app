import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

import '../../theme/app_icons.dart';
import '../../bot_mode/widgets/bot_handoff_body.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/disclosure_tile.dart';
import '../chat_models.dart';
import 'approval_card.dart';
import 'thinking_indicator.dart' show formatThinkingElapsed;
import 'tool_call_bodies.dart';

/// A compact summary of a tool the agent ran — assistant-ui surfaces tool
/// calls as their own inline card rather than mixing them into the message
/// prose, so the reasoning stays scannable. Tapping it opens what the tool was
/// given and what it returned, in the tool's own view when it has one
/// ([toolCallBody]).
///
/// The header shows how long the call has been running, ticking once a
/// second, and how long it took once done. An [approval] that holds the call
/// up shows inside the card, below the header while it waits for an answer
/// and with the rest of the details once it has one.
class ToolCallCard extends StatelessWidget {
  const ToolCallCard({
    super.key,
    required this.call,
    this.approval,
    this.onAnswerApproval,
    this.initiallyOpen = false,
  });

  final ToolCall call;

  /// Starts with the details showing, as the catalog does to show them.
  final bool initiallyOpen;
  final ApprovalRequest? approval;

  /// Sends the answer to [approval]; without one its buttons are disabled.
  final Future<void> Function(String choice)? onAnswerApproval;

  bool get _waiting => approval?.status == InputRequestStatus.pending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final approval = this.approval;
    final approvalCard = approval == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ApprovalCard(request: approval, onAnswer: onAnswerApproval),
          );
    final details = [
      ...switch (toolCallBody(call)) {
        final Widget body => [body],
        null => _genericSections(call),
      },
      if (approvalCard != null && !_waiting) ...[
        const SizedBox(height: 8),
        approvalCard,
      ],
    ];
    final expandable = details.isNotEmpty;
    final handoff = BotHandoffBody.of(call);
    final summary = call.preparing
        ? 'Preparing…'
        : handoff?.label ?? call.summary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DisclosureTile(
            enabled: expandable,
            initiallyExpanded: initiallyOpen && expandable,
            dense: true,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            minTileHeight: platformChromeOf(context) == PlatformChrome.ios
                ? kAppleMinTapTarget
                : 36,
            iconColor: subtle,
            collapsedIconColor: subtle,
            trailing: expandable ? null : const SizedBox.shrink(),
            title: Row(
              children: [
                if (handoff?.pending == true &&
                    handoff!.data['status'] != 'ambiguous')
                  AppIcon(AppIcons.schedule, size: 14, color: subtle)
                else
                  ToolCallStatusIcon(
                    status:
                        handoff?.failed == true ||
                            handoff?.data['status'] == 'ambiguous'
                        ? ToolCallStatus.error
                        : call.status,
                    waiting: _waiting,
                  ),
                const SizedBox(width: 8),
                Text(
                  call.name,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: subtle),
                  ),
                ),
                ToolCallTime(call: call),
              ],
            ),
            children: details,
          ),
          if (approvalCard != null && _waiting) approvalCard,
        ],
      ),
    );
  }
}

/// The generic view of a call: what it was given and what it returned.
List<Widget> _genericSections(ToolCall call) {
  final args = call.args;
  final input = args != null
      ? const JsonEncoder.withIndent('  ').convert(args)
      : call.summary.trim();
  final result = call.result.trim();
  return [
    if (input.isNotEmpty) _Section(label: 'Input', text: input),
    if (result.isNotEmpty)
      _Section(
        label: call.status == ToolCallStatus.error ? 'Error' : 'Result',
        text: result,
      ),
  ];
}

/// How long a call has run, ticking once a second while it runs, then how
/// long it took. Nothing for a call with no known start or duration, such as
/// one read from history.
class ToolCallTime extends StatefulWidget {
  const ToolCallTime({super.key, required this.call});

  final ToolCall call;

  @override
  State<ToolCallTime> createState() => _ToolCallTimeState();
}

class _ToolCallTimeState extends State<ToolCallTime> {
  Timer? _ticker;

  bool get _ticking =>
      widget.call.status == ToolCallStatus.running &&
      !widget.call.preparing &&
      widget.call.startedAt != null;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ToolCallTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_ticking) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final text = _ticking
        ? formatThinkingElapsed(DateTime.now().difference(call.startedAt!))
        : switch (call.duration) {
            final Duration took when call.status != ToolCallStatus.running =>
              formatToolDuration(took),
            _ => null,
          };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: context.hermesColors.subtleText,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A finished call's duration: tenths of a second under ten seconds, so a
/// quick call does not read "0s", whole seconds from there.
String formatToolDuration(Duration took) {
  if (took.isNegative) return '0.0s';
  if (took < const Duration(seconds: 10)) {
    return '${(took.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
  return formatThinkingElapsed(took);
}

bool _isJsonContainer(String text) {
  if (!text.startsWith('{') && !text.startsWith('[')) return false;
  try {
    final decoded = jsonDecode(text);
    return decoded is Map || decoded is List;
  } on FormatException {
    return false;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.text});

  final String label;
  final String text;

  static const double _maxHeight = 220;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);
    final Widget body = _isJsonContainer(text)
        ? JsonView.string(
            text,
            theme: JsonViewTheme(
              backgroundColor: Colors.transparent,
              defaultTextStyle: mono.copyWith(color: scheme.onSurface),
              keyStyle: TextStyle(color: subtle),
              stringStyle: TextStyle(color: scheme.onSurface),
              intStyle: TextStyle(color: scheme.secondary),
              doubleStyle: TextStyle(color: scheme.secondary),
              boolStyle: TextStyle(
                color: scheme.secondary,
                fontWeight: FontWeight.w600,
              ),
              openIcon: AppIcon(AppIcons.dropDown, size: 18, color: subtle),
              closeIcon: AppIcon(AppIcons.dropRight, size: 18, color: subtle),
            ),
          )
        : SingleChildScrollView(
            child: Text(text, style: mono.copyWith(color: scheme.onSurface)),
          );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: subtle,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            child: body,
          ),
        ],
      ),
    );
  }
}

/// The status glyph a tool call or a group of them shows: a spinner while
/// running, a raised hand while [waiting] on the user, a check once done, an
/// error mark once failed, a stop mark once cancelled.
class ToolCallStatusIcon extends StatelessWidget {
  const ToolCallStatusIcon({
    super.key,
    required this.status,
    this.waiting = false,
  });

  final ToolCallStatus status;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    if (waiting) {
      return AppIcon(
        AppIcons.handRaised,
        size: 14,
        color: context.hermesColors.warning,
      );
    }
    switch (status) {
      case ToolCallStatus.running:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        );
      case ToolCallStatus.completed:
        return AppIcon(
          AppIcons.checkCircleFilled,
          size: 14,
          color: context.hermesColors.success,
        );
      case ToolCallStatus.error:
        return AppIcon(
          AppIcons.errorFilled,
          size: 14,
          color: Theme.of(context).colorScheme.error,
        );
      case ToolCallStatus.cancelled:
        return AppIcon(
          AppIcons.blocked,
          size: 14,
          color: context.hermesColors.subtleText,
        );
    }
  }
}
