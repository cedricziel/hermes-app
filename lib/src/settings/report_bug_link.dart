import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Widget build(BuildContext context) {
    final open =
        openLink ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    return TextButton(
      onPressed: () async {
        try {
          await open(_issuesUrl);
        } on Object catch (_) {
          // The link failing to open is not fatal; the button stays put.
        }
      },
      child: const Text('Report a bug'),
    );
  }
}
