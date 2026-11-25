import 'dart:async';
import 'dart:convert';

import 'package:provider/provider.dart';

import '../../telemetry/breadcrumbs.dart';

import 'package:material_ui/material_ui.dart';

import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../../theme/app_icons.dart';
import '../../bot_mode/widgets/bot_handoff_body.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/disclosure_tile.dart';
import '../chat_models.dart';
import '../tool_value_language.dart';
import '../tool_call_presentation.dart';
import 'approval_card.dart';
import 'thinking_indicator.dart' show formatThinkingElapsed;
import 'tool_call_bodies.dart';
import 'tool_arguments_view.dart';
import 'tool_value_view.dart';

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
    this.onOpenChanged,
  });

  final ToolCall call;

  /// Told when the reader opens or closes the details, so a parent that
  /// rebuilds this card in another place can open it again.
  final ValueChanged<bool>? onOpenChanged;

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
      if (call.isToolBridge) ...[
        if (call.argumentGroups.isEmpty && call.displayTools.isNotEmpty)
          _Section(call: call, kind: _SectionKind.tools)
        else if (call.name == 'tool_call' && call.argumentGroups.isEmpty)
          _Section(call: call, kind: _SectionKind.toolDetails),
      ],
      if (call.outputRisk != null)
        _Section(call: call, kind: _SectionKind.outputRisk),
      ...switch (toolCallBody(call)) {
        final Widget body => [
          body,
          if (call.name == 'terminal' &&
              call.args?.keys.any((key) => key != 'command') == true)
            ToolArgumentsView(
              title: 'Arguments',
              arguments: Map.of(call.args!)..remove('command'),
            ),
        ],
        null => _genericSections(call),
      },
      if (call.isToolBridge || call.args?.isNotEmpty == true)
        DisclosureTile(
          dense: true,
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text('Raw arguments', style: TextStyle(fontSize: 12)),
          children: [
            if (call.isToolBridge)
              _Section(call: call, kind: _SectionKind.dispatcher),
            if (call.args != null)
              _Section(call: call, kind: _SectionKind.rawInput),
          ],
        ),
      if (approvalCard != null && !_waiting) ...[
        const SizedBox(height: 8),
        approvalCard,
      ],
    ];
    final expandable = details.isNotEmpty;
    final handoff = BotHandoffBody.of(call);
    final summary = wellFormedText(handoff?.label ?? call.displaySummary);
    final name = Text(
      wellFormedText(call.displayName),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
    final summaryText = Text(
      summary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12.5, color: subtle),
    );
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
            onExpansionChanged: (open) {
              onOpenChanged?.call(open);
              if (!open || call.outputRisk == null) return;
              try {
                context.read<Breadcrumbs>()('chat.visibility_action', {
                  'feature': 'warnings',
                  'action': 'details',
                });
              } on ProviderNotFoundException {
                return;
              }
            },
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
                if (call.isToolBridge)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [name, if (summary.isNotEmpty) summaryText],
                    ),
                  )
                else ...[
                  Flexible(flex: 2, child: name),
                  const SizedBox(width: 8),
                  Expanded(child: summaryText),
                ],
                ToolCallTime(call: call),
              ],
            ),
            children: details,
          ),
          if (approvalCard != null && _waiting) approvalCard,
          if (call.outputRisk case final risk?)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                wellFormedText(
                  'Output risk: ${risk.risk}${risk.redacted ? ' · Redacted' : ''}',
                ),
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// The generic view of a call: what it was given and what it returned. Only
/// the sections are made here; their text is made when the card is opened.
List<Widget> _genericSections(ToolCall call) {
  final args = call.args;
  return [
    if (call.argumentGroups.isNotEmpty)
      for (final group in call.argumentGroups)
        ToolArgumentsView(title: group.title, arguments: group.arguments)
    else if (args != null && args.isNotEmpty)
      ToolArgumentsView(arguments: args)
    else if (args != null || call.summary.trim().isNotEmpty)
      _Section(call: call, kind: _SectionKind.input),
    if (call.result.trim().isNotEmpty)
      _Section(
        call: call,
        kind: call.status == ToolCallStatus.error
            ? _SectionKind.error
            : _SectionKind.result,
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

enum _SectionKind {
  input,
  rawInput,
  result,
  error,
  dispatcher,
  tools,
  toolDetails,
  outputRisk,
}

/// One section of the open card. Its text, its language and its view are made
/// when the card opens (the card does not build its children while closed),
/// and again only when [call] is another object: a rebuild of the same call
/// keeps them, and the view the reader chose (text or tree) with them.
class _Section extends StatefulWidget {
  const _Section({required this.call, required this.kind});

  final ToolCall call;
  final _SectionKind kind;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late String _text;
  late String? _language;

  @override
  void initState() {
    super.initState();
    _make();
  }

  @override
  void didUpdateWidget(_Section oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.call, widget.call) ||
        oldWidget.kind != widget.kind) {
      _make();
    }
  }

  void _make() {
    final call = widget.call;
    switch (widget.kind) {
      case _SectionKind.input:
        final args = call.args;
        _text = args != null
            ? const JsonEncoder.withIndent('  ').convert(args)
            : call.summary.trim();
        // Encoded arguments are JSON by construction; a summary is sniffed.
        _language = args != null ? 'json' : toolValueLanguage(_text);
      case _SectionKind.rawInput:
        _text = const JsonEncoder.withIndent('  ').convert(call.args);
        _language = 'json';
      case _SectionKind.result || _SectionKind.error:
        _text = call.result.trim();
        _language = toolValueLanguage(
          _text,
          path: widget.kind == _SectionKind.result ? _readPath(call) : null,
        );
      case _SectionKind.dispatcher:
        _text = call.name;
        _language = null;
      case _SectionKind.tools:
        _text = call.displayTools
            .map(
              (tool) =>
                  '${tool.text}${tool.name.isNotEmpty && tool.name != tool.text ? ' (${tool.name})' : ''}${tool.preview.isNotEmpty ? '\n${tool.preview}' : ''}',
            )
            .join('\n\n');
        _language = null;
      case _SectionKind.toolDetails:
        _text = call.preparing
            ? 'The tool name will appear when Hermes starts the call.'
            : 'Hermes did not include the underlying tool name.';
        _language = null;
      case _SectionKind.outputRisk:
        final risk = call.outputRisk;
        _text = risk == null || risk.findings.isEmpty
            ? 'No further details'
            : risk.findings.join('\n');
        _language = null;
    }
    _text = wellFormedText(_text);
  }

  /// The path a file-reading tool was given: its extension names the language
  /// of what it returned. Another tool's path says nothing about its result.
  static String? _readPath(ToolCall call) {
    if (!call.name.toLowerCase().contains('read')) return null;
    final args = call.args;
    final path = args?['path'] ?? args?['file_path'];
    return path is String ? path : null;
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final label = switch (kind) {
      _SectionKind.input || _SectionKind.rawInput => 'Input',
      _SectionKind.result => 'Result',
      _SectionKind.error => 'Error',
      _SectionKind.dispatcher => 'Dispatcher',
      _SectionKind.tools => 'Tools',
      _SectionKind.toolDetails => 'Tool details',
      _SectionKind.outputRisk => 'Output risk',
    };
    return ToolValuePanel(
      label: label,
      text: _text,
      language: _language,
      settled: widget.call.status != ToolCallStatus.running,
      section: switch (kind) {
        _SectionKind.input || _SectionKind.rawInput => ToolValueSection.input,
        _SectionKind.error => ToolValueSection.error,
        _ => ToolValueSection.result,
      },
      // An Input above "Raw arguments" is copied there; the labels that only
      // explain the call have nothing worth copying.
      showCopy:
          kind == _SectionKind.rawInput ||
          kind == _SectionKind.result ||
          kind == _SectionKind.error,
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
      case ToolCallStatus.warning:
        return AppIcon(
          AppIcons.warning,
          size: 14,
          color: context.hermesColors.warning,
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
