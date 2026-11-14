import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../theme/hermes_theme.dart';

typedef LinkOpener = Future<bool> Function(Uri uri);

final _issuesUrl = Uri.parse('https://github.com/cedricziel/hermes-app/issues');

/// A "Report a bug" link to the project's issue tracker, opened in the
/// external browser. Shared by the About dialog and the setup/sign-in
/// screens shown before a user can reach the account menu.
class ReportBugLink extends StatelessWidget {
  const ReportBugLink({super.key, this.openLink});

  /// Opens the issues URL; the system browser when null.
  final LinkOpener? openLink;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(foregroundColor: context.hermesColors.link),
    onPressed: () => openIssueTracker(openLink),
    child: Text(context.l10n.settingsReportBug),
  );
}

/// Opens the project's issue tracker with [openLink], or in the system
/// browser when null.
Future<void> openIssueTracker([LinkOpener? openLink]) async {
  final open =
      openLink ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  try {
    await open(_issuesUrl);
  } on Object catch (_) {
    // The link failing to open is not fatal.
  }
}
