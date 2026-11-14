import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../agent_models.dart';

const _cross = AppIconSet(Icons.cancel, CupertinoIcons.xmark_circle_fill);
const _stopSquare = AppIconSet(Icons.stop, CupertinoIcons.stop_fill);
const _dash = AppIconSet(Icons.remove, CupertinoIcons.minus);

/// The mark in front of an agent row. Each state has its own shape, so the
/// state never rests on colour alone. Hidden from screen readers: the row's
/// label says the state.
class AgentStateGlyph extends StatelessWidget {
  const AgentStateGlyph({super.key, required this.state, this.size = 18});

  final AgentState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final glyph = switch (state) {
      AgentState.running => _running(context, scheme.primary),
      AgentState.starting => AppIcon(
        AppIcons.radioOff,
        key: const ValueKey('agent-glyph-starting'),
        size: size,
        color: colors.subtleText,
      ),
      AgentState.finished => AppIcon(
        AppIcons.checkCircleFilled,
        key: const ValueKey('agent-glyph-finished'),
        size: size,
        color: colors.success,
      ),
      AgentState.failed => AppIcon(
        _cross,
        key: const ValueKey('agent-glyph-failed'),
        size: size,
        color: scheme.error,
      ),
      AgentState.stopped => AppIcon(
        _stopSquare,
        key: const ValueKey('agent-glyph-stopped'),
        size: size,
        color: scheme.onSurface,
      ),
      AgentState.ended => AppIcon(
        _dash,
        key: const ValueKey('agent-glyph-ended'),
        size: size,
        color: colors.subtleText,
      ),
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(child: glyph),
      ),
    );
  }

  Widget _running(BuildContext context, Color color) {
    final dot = size * 0.55;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        key: const ValueKey('agent-glyph-running-still'),
        width: dot,
        height: dot,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return SizedBox.square(
      key: const ValueKey('agent-glyph-running'),
      dimension: size * 0.8,
      child: CircularProgressIndicator.adaptive(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
