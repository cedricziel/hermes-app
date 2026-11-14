import 'package:flutter/material.dart';

import 'safe_path_text.dart';
import '../../../l10n/l10n.dart';
import '../../theme/breakpoints.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/adaptive_sheet.dart';
import 'file_size.dart';
import 'files_metrics.dart';

/// "This file is 212 MB. Download it anyway?" Phones get a bottom sheet with
/// Download filled and Cancel as text; iPad, the Mac and Android in a wide
/// window get an alert with Download the default. Answers true only for
/// Download.
Future<bool> askDownloadLargeFile(BuildContext context, int bytes) async {
  final l10n = context.l10n;
  final sentence = l10n.filesSizeQuestion(formatByteSize(l10n, bytes));
  final cancel = MaterialLocalizations.of(context).cancelButtonLabel;
  final alert =
      platformChromeOf(context) == PlatformChrome.macos ||
      isWideLayout(context);
  if (alert) {
    return showConfirmDialog(
      context,
      title: sentence,
      confirmLabel: l10n.filesActionDownload,
      cancelLabel: cancel,
    );
  }
  final answer = await showAdaptiveSheet<bool>(
    context,
    builder: (sheet) => FileSizeSheet(
      sentence: sentence,
      onCancel: () => Navigator.pop(sheet, false),
      onDownload: () => Navigator.pop(sheet, true),
    ),
  );
  return answer ?? false;
}

/// The phone sheet of the size question: the sentence, Cancel as a text
/// button and Download filled.
class FileSizeSheet extends StatelessWidget {
  const FileSizeSheet({
    super.key,
    required this.sentence,
    required this.onCancel,
    required this.onDownload,
  });

  final String sentence;
  final VoidCallback onCancel;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = FilesMetrics.of(context);
    final cancel = TextButton(
      onPressed: onCancel,
      style: files.buttonStyle(),
      child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
    );
    final download = FilledButton(
      onPressed: onDownload,
      style: files.buttonStyle(),
      child: Text(l10n.filesActionDownload),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                sentence,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            if (isLargeText(context)) ...[
              download,
              const SizedBox(height: 8),
              cancel,
            ] else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [cancel, download],
              ),
          ],
        ),
      ),
    );
  }
}

/// The secret question, asked before preview, Save, Share and Open with…:
/// the file's name as the title, "This file may contain passwords or keys.
/// Continue anyway?", Cancel (the emphasised default on Apple platforms) and
/// Continue. On Android two text buttons, Cancel first. Answers true only for Continue.
Future<bool> askOpenSecretFile(BuildContext context, String name) {
  final l10n = context.l10n;
  return showConfirmDialog(
    context,
    title: safePathText(name),
    message: l10n.filesSecretQuestion,
    confirmLabel: l10n.filesActionContinue,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    cancelIsDefault: true,
  );
}

/// "Open example.com?" with Cancel and Open, before a Markdown link opens;
/// "Write to me@example.org?" for a mail address ([target] has an `@`).
Future<bool> confirmOpenLink(BuildContext context, String target) {
  final l10n = context.l10n;
  return showConfirmDialog(
    context,
    title: target.contains('@')
        ? l10n.filesOpenMailTitle(target)
        : l10n.filesOpenLinkTitle(target),
    confirmLabel: l10n.filesActionOpen,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    cancelIsDefault: true,
  );
}

/// "Saved export.zip." after the system save dialog.
void showFilesSaved(BuildContext context, String name) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.filesSavedMessage(name))));
}
