import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
import 'report_bug_link.dart';

Future<void> showAppAboutDialog(BuildContext context) async {
  final version = await PackageInfo.fromPlatform()
      .then((info) => info.version)
      .catchError((_) => 'Unavailable');
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => AppAboutDialog(version: version),
  );
}

/// Shows the app's version and a way to report a bug.
class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key, required this.version, this.openLink});

  final String version;
  final LinkOpener? openLink;

  @override
  Widget build(BuildContext context) {
    return GroupedDialog(
      title: 'About',
      children: [
        GroupedSection(
          children: [
            GroupedRow(title: 'Version', value: version),
            GroupedRow(
              key: const Key('report-bug'),
              title: 'Report a bug',
              onTap: () => openIssueTracker(openLink),
            ),
          ],
        ),
      ],
    );
  }
}
