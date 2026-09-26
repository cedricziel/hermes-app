import 'package:url_launcher/url_launcher.dart';

import '../settings/report_bug_link.dart' show LinkOpener;

const _openableSchemes = {'http', 'https', 'mailto'};

/// An `onLinkTap` for `GptMarkdown` that opens web and mail links in the
/// system's own app, the browser when [open] is null.
///
/// Markdown here comes from the agent, so links with any other scheme
/// (`file:`, `javascript:`, app deep links) and relative links are ignored.
void Function(String url, String title) markdownLinkHandler({
  LinkOpener? open,
}) {
  final opener =
      open ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  return (url, _) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_openableSchemes.contains(uri.scheme.toLowerCase())) {
      return;
    }
    try {
      await opener(uri);
    } on Object catch (_) {
      // A link that fails to open leaves the message as it is.
    }
  };
}
