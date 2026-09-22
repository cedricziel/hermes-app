import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    return SimpleDialog(
      title: const Text('About'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Version $version'),
        ),
        ReportBugLink(openLink: openLink),
      ],
    );
  }
}
