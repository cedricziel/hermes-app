import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/l10n.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
import 'report_bug_link.dart';

Future<void> showAppAboutDialog(BuildContext context) async {
  final version = await PackageInfo.fromPlatform().then<String?>(
    (info) => info.version,
    onError: (_) => null,
  );
  if (!context.mounted) return;
  final shown = version ?? context.l10n.settingsAboutVersionUnavailable;
  await showDialog<void>(
    context: context,
    builder: (_) => AppAboutDialog(version: shown),
  );
}

/// Shows the app's version and a way to report a bug.
class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key, required this.version, this.openLink});

  final String version;
  final LinkOpener? openLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GroupedDialog(
      title: l10n.settingsAboutTitle,
      children: [
        GroupedSection(
          children: [
            GroupedRow(title: l10n.settingsAboutVersion, value: version),
            GroupedRow(
              key: const Key('report-bug'),
              title: l10n.settingsReportBug,
              onTap: () => openIssueTracker(openLink),
            ),
          ],
        ),
      ],
    );
  }
}
