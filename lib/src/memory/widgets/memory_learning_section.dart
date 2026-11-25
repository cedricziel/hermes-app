import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/app_banner.dart';
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

  static String intervalLabel(AppLocalizations l10n, int turns) =>
      turns == 0 ? l10n.commonOff : l10n.memoryLearningIntervalEvery(turns);

  static String reportLabel(AppLocalizations l10n, String value) =>
      switch (value) {
        'off' => l10n.commonOff,
        'on' => l10n.memoryLearningReportShort,
        'verbose' => l10n.memoryLearningReportDetailed,
        _ => value,
      };

  /// The title of a setting's row, and of the choice list it opens.
  static String settingLabel(AppLocalizations l10n, MemorySetting setting) =>
      switch (setting) {
        MemorySetting.userProfile => l10n.memoryLearningUserProfile,
        MemorySetting.agentNotes => l10n.memoryLearningAgentNotes,
        MemorySetting.writeApproval => l10n.memoryLearningWriteApproval,
        MemorySetting.reviewInterval => l10n.memoryLearningReviewInterval,
        MemorySetting.updatesInChat => l10n.memoryLearningUpdatesInChat,
      };

  Future<void> _pickInterval(BuildContext context, int current) async {
    final l10n = context.l10n;
    final offered = {..._intervals, current}.toList()..sort();
    final picked = await showMemoryChoice<int>(
      context,
      title: settingLabel(l10n, MemorySetting.reviewInterval),
      options: [
        for (final turns in offered) (turns, intervalLabel(l10n, turns)),
      ],
      current: current,
    );
    if (picked != null) onChanged(MemorySetting.reviewInterval, picked);
  }

  Future<void> _pickReport(BuildContext context, String current) async {
    final l10n = context.l10n;
    final values = ['off', 'on', 'verbose', if (!_known(current)) current];
    final picked = await showMemoryChoice<String>(
      context,
      title: settingLabel(l10n, MemorySetting.updatesInChat),
      options: [for (final value in values) (value, reportLabel(l10n, value))],
      current: current,
    );
    if (picked != null) onChanged(MemorySetting.updatesInChat, picked);
  }

  static bool _known(String value) =>
      value == 'off' || value == 'on' || value == 'verbose';

  @override
  Widget build(BuildContext context) {
    final current = settings;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppBanner(
              tone: AppBannerTone.error,
              icon: AppIcons.error,
              title: message!,
            ),
          ),
        GroupedSection(
          header: l10n.memoryLearningHeader,
          footer: current == null ? null : l10n.memoryLearningFooter,
          children: [
            if (current == null)
              GroupedRow(
                wrapWhenStacked: true,
                title: unreadable
                    ? l10n.memoryLearningUnreadable
                    : l10n.memoryLearningReadingSettings,
                value: unreadable ? l10n.commonRetry : null,
                onTap: unreadable ? onRetry : null,
              )
            else ...[
              _switch(
                l10n,
                MemorySetting.userProfile,
                l10n.memoryLearningUserProfileDetail,
                current.userProfile,
              ),
              _switch(
                l10n,
                MemorySetting.agentNotes,
                l10n.memoryLearningAgentNotesDetail,
                current.agentNotes,
              ),
              _switch(
                l10n,
                MemorySetting.writeApproval,
                l10n.memoryLearningWriteApprovalDetail,
                current.writeApproval,
              ),
              GroupedRow(
                wrapWhenStacked: true,
                title: settingLabel(l10n, MemorySetting.reviewInterval),
                value: intervalLabel(l10n, current.reviewInterval),
                onTap: () => _pickInterval(context, current.reviewInterval),
              ),
              GroupedRow(
                wrapWhenStacked: true,
                title: settingLabel(l10n, MemorySetting.updatesInChat),
                value: reportLabel(l10n, current.updatesInChat),
                onTap: () => _pickReport(context, current.updatesInChat),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _switch(
    AppLocalizations l10n,
    MemorySetting setting,
    String subtitle,
    bool value,
  ) => GroupedSwitchRow(
    title: settingLabel(l10n, setting),
    subtitle: subtitle,
    subtitleMaxLines: 2,
    value: value,
    onChanged: (next) => onChanged(setting, next),
  );
}
