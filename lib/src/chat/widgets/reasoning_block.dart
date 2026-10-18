import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import 'thinking_indicator.dart' show formatThinkingElapsed;
import 'thinking_shimmer.dart';

/// What the model reasoned before it answered, folded away until the user
/// opens it — assistant-ui's collapsible reasoning part.
class ReasoningBlock extends StatefulWidget {
  const ReasoningBlock({
    super.key,
    required this.text,
    this.active = false,
    this.initiallyExpanded = false,
    this.startedAt,
    this.activity,
  });

  final String text;

  /// Reasoning is arriving now, rather than answer text or tool results.
  final bool active;
  final bool initiallyExpanded;
  final DateTime? startedAt;
  final String? activity;

  @override
  State<ReasoningBlock> createState() => _ReasoningBlockState();
}

class _ReasoningBlockState extends State<ReasoningBlock> {
  late bool _open = widget.initiallyExpanded;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ReasoningBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.active && widget.startedAt != null) {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
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

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final label = widget.active ? widget.activity ?? 'Thinking…' : 'Reasoning';
    final elapsed = widget.active && widget.startedAt != null
        ? '${formatThinkingElapsed(DateTime.now().difference(widget.startedAt!))} · '
        : '';
    final minTap = platformChromeOf(context) == PlatformChrome.ios
        ? kAppleMinTapTarget
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label,
          button: true,
          expanded: _open,
          onTap: _toggle,
          child: ExcludeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minTap),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIcons.reasoning, size: 16, color: subtle),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ThinkingShimmer(
                            active: widget.active,
                            child: Text(
                              '$elapsed$label',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: subtle),
                            ),
                          ),
                        ),
                        AppIcon(
                          _open ? AppIcons.expandLess : AppIcons.expandMore,
                          size: 18,
                          color: subtle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4, left: 7),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: scheme.outline)),
            ),
            child: Text(
              widget.text.isEmpty
                  ? widget.active
                        ? 'Waiting for reasoning…'
                        : 'No reasoning text was provided.'
                  : widget.text,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: subtle),
            ),
          ),
      ],
    );
  }
}
