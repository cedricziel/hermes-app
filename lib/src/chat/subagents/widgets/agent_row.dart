import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../widgets/row_actions.dart';
import '../../widgets/tool_call_card.dart';
import '../agent_models.dart';
import 'agent_state_glyph.dart';

/// What one agent row shows. Plain data: the roster maps its rows to this.
class AgentRowModel {
  const AgentRowModel({
    required this.goal,
    required this.state,
    this.runTime,
    this.toolCount = 0,
    this.currentTool,
    this.currentPreview,
    this.level = 0,
  });

  final String goal;
  final AgentState state;
  final Duration? runTime;
  final int toolCount;

  /// The tool in use and what it does with it; shown only while running.
  final String? currentTool;
  final String? currentPreview;

  /// Nesting inside its section, 0 to 2; a deeper agent is drawn at 2.
  final int level;
}

/// One agent in the Activity panel: goal, state line, the current tool while
/// running, and a chevron. The whole row opens the details.
class AgentRow extends StatelessWidget {
  const AgentRow({
    super.key,
    required this.model,
    this.onShowDetails,
    this.onStop,
  });

  final AgentRowModel model;
  final VoidCallback? onShowDetails;
  final VoidCallback? onStop;

  static String stateWord(BuildContext context, AgentState state) {
    final l10n = context.l10n;
    return switch (state) {
      AgentState.starting => l10n.chatSubagentsStateStarting,
      AgentState.running => l10n.chatSubagentsStateRunning,
      AgentState.finished => l10n.chatSubagentsStateFinished,
      AgentState.failed => l10n.chatSubagentsStateFailed,
      AgentState.stopped => l10n.chatSubagentsStateStopped,
      AgentState.ended => l10n.chatSubagentsStateEnded,
    };
  }

  String _statusLine(BuildContext context, String state) {
    final l10n = context.l10n;
    final time = model.runTime;
    if (time == null) return state;
    final took = formatToolDuration(time);
    return model.toolCount > 0
        ? l10n.chatSubagentsRowLineTools(
            state,
            took,
            l10n.chatSubagentsToolCount(model.toolCount),
          )
        : l10n.chatSubagentsRowLine(state, took);
  }

  String _label(BuildContext context, String state) {
    final l10n = context.l10n;
    final time = model.runTime;
    final tools = l10n.chatSubagentsToolCount(model.toolCount);
    if (time == null) {
      return [model.goal, state, if (model.toolCount > 0) tools].join(', ');
    }
    final took = formatToolDuration(time);
    return model.toolCount > 0
        ? l10n.chatSubagentsRowSemantics(model.goal, state, tools, took)
        : l10n.chatSubagentsRowSemanticsNoTools(model.goal, state, took);
  }

  String? _current(BuildContext context) {
    final tool = model.currentTool;
    if (model.state != AgentState.running || tool == null || tool.isEmpty) {
      return null;
    }
    final preview = model.currentPreview;
    return preview == null || preview.isEmpty
        ? tool
        : context.l10n.chatSubagentsRowCurrent(tool, preview);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chrome = platformChromeOf(context);
    final theme = Theme.of(context);
    final subtle = context.hermesColors.subtleText;
    final state = stateWord(context, model.state);
    final current = _current(context);
    final stackedLayout = MediaQuery.textScalerOf(context).scale(14) > 21;
    final minHeight = switch (chrome) {
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
      PlatformChrome.material => 48.0,
    };
    final canStop = onStop != null && model.state.active;

    final goal = Text(
      model.goal,
      maxLines: stackedLayout ? null : 2,
      overflow: stackedLayout ? TextOverflow.visible : TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final detail = Text(
      _statusLine(context, state),
      style: theme.textTheme.bodySmall?.copyWith(color: subtle),
    );
    final currentLine = current == null
        ? null
        : Text(
            current,
            maxLines: stackedLayout ? null : 1,
            overflow: stackedLayout
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: subtle,
              fontFamily: 'monospace',
            ),
          );
    final chevron = AppIcon(AppIcons.chevronRight, size: 20, color: subtle);
    final glyph = AgentStateGlyph(state: model.state);

    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        goal,
        const SizedBox(height: 2),
        detail,
        if (currentLine != null) ...[const SizedBox(height: 2), currentLine],
      ],
    );

    final content = stackedLayout
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  glyph,
                  const Spacer(),
                  if (onShowDetails != null) chevron,
                ],
              ),
              const SizedBox(height: 6),
              lines,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              glyph,
              const SizedBox(width: 12),
              Expanded(child: lines),
              if (onShowDetails != null) ...[const SizedBox(width: 8), chevron],
            ],
          );

    final level = model.level.clamp(0, 2);
    Widget row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.0 + 16 * level, 8, 16, 8),
        child: content,
      ),
    );
    row = InkWell(onTap: onShowDetails, child: row);

    row = Semantics(
      button: onShowDetails != null,
      label: _label(context, state),
      hint: onShowDetails != null ? l10n.chatSubagentsRowShowDetailsHint : null,
      onTap: onShowDetails,
      excludeSemantics: true,
      customSemanticsActions: chrome.isApple
          ? null
          : {
              CustomSemanticsAction(label: l10n.chatSubagentsActionShowDetails):
                  ?onShowDetails,
              if (canStop)
                CustomSemanticsAction(label: l10n.chatSubagentsActionStopAgent):
                    onStop!,
            },
      child: row,
    );

    final mac = chrome == PlatformChrome.macos;
    return RowActions(
      title: model.goal,
      actions: [
        if (onShowDetails != null)
          RowAction(
            label: mac
                ? l10n.chatSubagentsMenuShowDetails
                : l10n.chatSubagentsActionShowDetails,
            icon: AppIcons.chevronRight,
            onPressed: onShowDetails!,
          ),
        if (canStop)
          RowAction(
            label: mac
                ? l10n.chatSubagentsMenuStopAgent
                : l10n.chatSubagentsActionStopAgent,
            icon: AppIcons.stop,
            onPressed: onStop!,
            destructive: true,
          ),
      ],
      child: row,
    );
  }
}
