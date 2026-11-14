import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/motion_spinner.dart';

/// Whether the text is scaled to the point where a row or header gives its
/// switch a line of its own.
bool toolsLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 28;

/// The Tools screens' 16 pt spinner (a still hourglass with reduced motion).
class ToolsSpinner extends StatelessWidget {
  const ToolsSpinner({super.key});

  @override
  Widget build(BuildContext context) => const MotionSpinner();
}

/// A toolset's switch, named "name, on" and, while a change is being
/// written, "name, on, saving" with the switch disabled and a spinner
/// beside it. While Hermes is first being asked what it needs ([preparing])
/// it is disabled with a spinner and no "saving". It sits in a target of 44 pt on iOS, 48 dp on Material and
/// 28 pt on a Mac, where the pointer is the input.
class ToolsSwitch extends StatelessWidget {
  const ToolsSwitch({
    super.key,
    required this.name,
    required this.value,
    required this.onChanged,
    this.saving = false,
    this.preparing = false,
    this.showStateWord = false,
  });

  final String name;

  /// The position shown, which while [saving] is the one being written.
  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final bool saving;

  /// Hermes is being asked what the switch needs before anything is sent: a
  /// spinner and a disabled switch at the saved position, named without
  /// "saving".
  final bool preparing;

  /// Says "On" or "Off" before the switch, for when it has a line to itself.
  final bool showStateWord;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = value ? 'on' : 'off';
    final target = switch (platformChromeOf(context)) {
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.material => 48.0,
      PlatformChrome.macos => 28.0,
    };
    final metrics = GroupedMetrics.of(context);
    final usable = !saving && !preparing && onChanged != null;
    void toggle() => onChanged!(!value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStateWord) ...[
          ExcludeSemantics(
            child: Text(
              value ? l10n.commonOn : l10n.commonOff,
              style: TextStyle(
                fontSize: metrics.subtitleSize,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (saving || preparing) ...[
          const ToolsSpinner(),
          const SizedBox(width: 8),
        ],
        // The platform switch is smaller than a touch target, so the target
        // and its accessibility node are this box, and the switch inside it
        // only draws and drags.
        Semantics(
          container: true,
          label: saving
              ? l10n.toolsSwitchLabelSaving(name, state)
              : l10n.toolsSwitchLabel(name, state),
          toggled: value,
          enabled: usable,
          onTap: usable ? toggle : null,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: usable ? toggle : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: target,
                  minHeight: target,
                ),
                child: Center(
                  child: GroupedSwitch(
                    value: value,
                    onChanged: usable ? onChanged : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
