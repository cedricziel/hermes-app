import 'package:flutter/material.dart';

import '../../mcp/mcp_banner.dart';
import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';
import '../memory_settings.dart';
import 'memory_choice_dialog.dart';

/// What Hermes learns about the user, and how it reports it: three switches
/// and two choices for one profile. [settings] is null while they are not
/// read; [onChanged] gets the setting and its new value (a `bool`, the review
/// interval as an `int`, the in-chat reports as `off`, `on` or `verbose`).
class MemoryLearningSection extends StatelessWidget {
  const MemoryLearningSection({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onRetry,
    this.unreadable = false,
    this.message,
  });

  final MemorySettings? settings;
  final bool unreadable;

  /// Why the last change was undone.
  final String? message;
  final void Function(MemorySetting setting, Object value) onChanged;
  final VoidCallback onRetry;

  static const _intervals = [0, 5, 10, 20];

  static String intervalLabel(int turns) =>
      turns == 0 ? 'Off' : 'After every $turns messages';

  static String reportLabel(String value) => switch (value) {
    'off' => 'Off',
    'on' => 'Short note',
    'verbose' => 'With details',
    _ => value,
  };

  Future<void> _pickInterval(BuildContext context, int current) async {
    final offered = {..._intervals, current}.toList()..sort();
    final picked = await showMemoryChoice<int>(
      context,
      title: MemorySetting.reviewInterval.label,
      options: [for (final turns in offered) (turns, intervalLabel(turns))],
      current: current,
    );
    if (picked != null) onChanged(MemorySetting.reviewInterval, picked);
  }

  Future<void> _pickReport(BuildContext context, String current) async {
    final values = ['off', 'on', 'verbose', if (!_known(current)) current];
    final picked = await showMemoryChoice<String>(
      context,
      title: MemorySetting.updatesInChat.label,
      options: [for (final value in values) (value, reportLabel(value))],
      current: current,
    );
    if (picked != null) onChanged(MemorySetting.updatesInChat, picked);
  }

  static bool _known(String value) =>
      value == 'off' || value == 'on' || value == 'verbose';

  @override
  Widget build(BuildContext context) {
    final current = settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: McpBanner(
              tone: McpTone.error,
              icon: AppIcons.error,
              title: message!,
            ),
          ),
        GroupedSection(
          header: 'Learning',
          footer: current == null
              ? null
              : 'Ask before saving applies right away, the rest from the next '
                    'chat.',
          children: [
            if (current == null)
              GroupedRow(
                title: unreadable
                    ? "Couldn't read the memory settings"
                    : 'Reading the memory settings',
                value: unreadable ? 'Retry' : null,
                onTap: unreadable ? onRetry : null,
              )
            else ...[
              _switch(
                MemorySetting.userProfile,
                'Your preferences, name and habits',
                current.userProfile,
              ),
              _switch(
                MemorySetting.agentNotes,
                'Facts about your setup, tools and conventions',
                current.agentNotes,
              ),
              _switch(
                MemorySetting.writeApproval,
                'Hermes asks you before it changes memory',
                current.writeApproval,
              ),
              GroupedRow(
                title: MemorySetting.reviewInterval.label,
                value: intervalLabel(current.reviewInterval),
                onTap: () => _pickInterval(context, current.reviewInterval),
              ),
              GroupedRow(
                title: MemorySetting.updatesInChat.label,
                value: reportLabel(current.updatesInChat),
                onTap: () => _pickReport(context, current.updatesInChat),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _switch(MemorySetting setting, String subtitle, bool value) =>
      GroupedSwitchRow(
        title: setting.label,
        subtitle: subtitle,
        subtitleMaxLines: 2,
        value: value,
        onChanged: (next) => onChanged(setting, next),
      );
}
