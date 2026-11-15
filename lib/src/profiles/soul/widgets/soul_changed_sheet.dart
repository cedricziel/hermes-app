import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../files/widgets/safe_path_text.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/breakpoints.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../tools/widgets/tools_target.dart';
import '../../../widgets/adaptive_sheet.dart';
import '../../../widgets/disclosure_tile.dart';
import '../../../widgets/grouped_list.dart';

/// [text] as it may be shown: line breaks stay, and any other control or bidi
/// character is drawn as a visible `<U+202E>` placeholder (see
/// [safePathText]), so the server's text cannot reorder or hide what the user
/// reads. Only the display changes; Copy takes the original text.
String soulSafeText(String text) =>
    text.replaceAll('\r\n', '\n').split('\n').map(safePathText).join('\n');

/// What the user chose in the changed-on-the-server sheet.
enum SoulChangedChoice { keepEditing, replaceAnyway }

/// "Changed on the server": the file changed after the page loaded it.
///
/// The title and the body, a "Show server's version" row that opens the
/// server's text (closed by default), Keep editing as the filled default
/// button and Replace anyway as a plain text button under it. Opened, the
/// text is a read-only, selectable box capped at 40% of the window's height
/// that scrolls, with Copy under it; control and bidi characters are drawn as
/// placeholders. When the file is gone on the server ([serverGone]) the body
/// says so and the server's version reads "No personality set."; there is
/// nothing to copy then, so Copy is not drawn.
///
/// It takes plain values and callbacks, no controller. [dialog] only changes
/// the frame: a drag handle on a phone sheet, none in a dialog on a Mac and on
/// wide windows ([showSoulChangedSheet] picks it). Nothing is sent until
/// [onReplaceAnyway].
class SoulChangedSheet extends StatefulWidget {
  const SoulChangedSheet({
    super.key,
    required this.serverText,
    this.serverGone = false,
    this.dialog = false,
    this.initiallyOpen = false,
    required this.onKeepEditing,
    required this.onReplaceAnyway,
    required this.onCopy,
  });

  /// The file's text on the server; ignored while [serverGone].
  final String serverText;
  final bool serverGone;
  final bool dialog;
  final bool initiallyOpen;
  final VoidCallback onKeepEditing;
  final VoidCallback onReplaceAnyway;

  /// Puts the original (not the displayed) text on the clipboard.
  final ValueChanged<String> onCopy;

  @override
  State<SoulChangedSheet> createState() => _SoulChangedSheetState();
}

class _SoulChangedSheetState extends State<SoulChangedSheet> {
  var _copied = false;

  @override
  void didUpdateWidget(SoulChangedSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverText != widget.serverText) _copied = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final shown = widget.serverGone
        ? l10n.profilesSoulChangedServerEmpty
        : soulSafeText(widget.serverText);
    final style = TextStyle(
      fontSize: metrics.titleSize,
      height: 1.35,
      color: scheme.onSurface,
    );
    final box = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(metrics.radius),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowPadding,
              vertical: 12,
            ),
            child: Semantics(
              label: l10n.profilesSoulChangedServerVersionLabel,
              child: SelectableText(shown, style: style),
            ),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.dialog)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.subtleText.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // Title, body and the server's version scroll together at the largest
        // text; the two buttons stay in view.
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              metrics.gutter,
              widget.dialog ? 20 : 16,
              metrics.gutter,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.profilesSoulChangedTitle,
                    style: TextStyle(
                      fontSize: mac ? 13 : 17,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.serverGone
                      ? l10n.profilesSoulChangedGone
                      : l10n.profilesSoulChangedBody,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: DisclosureTile(
                    initiallyExpanded: widget.initiallyOpen,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    minTileHeight: toolsTarget(context),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      l10n.profilesSoulChangedShowVersion,
                      style: TextStyle(
                        fontSize: metrics.titleSize,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    children: [
                      box,
                      if (!widget.serverGone)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  widget.onCopy(widget.serverText);
                                  setState(() => _copied = true);
                                },
                                style: toolsButtonStyle(context),
                                icon: ExcludeSemantics(
                                  child: AppIcon(AppIcons.copy, size: 18),
                                ),
                                label: Text(l10n.profilesSoulChangedCopy),
                              ),
                              if (_copied)
                                Semantics(
                                  liveRegion: true,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 8,
                                    ),
                                    child: Text(
                                      l10n.profilesSoulChangedCopied,
                                      style: TextStyle(
                                        fontSize: metrics.footerSize,
                                        color: colors.subtleText,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(metrics.gutter, 4, metrics.gutter, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: widget.onKeepEditing,
                style: toolsButtonStyle(context, wide: true),
                child: Text(l10n.profilesSoulKeepEditing),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onReplaceAnyway,
                style: toolsButtonStyle(context, wide: true),
                child: Text(l10n.profilesSoulChangedReplaceAnyway),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens [SoulChangedSheet]: a bottom sheet on a phone, a dialog on a Mac and
/// on wide windows. Dismissing it is Keep editing. Answers what the user
/// chose; nothing is sent from here.
Future<SoulChangedChoice> showSoulChangedSheet(
  BuildContext context, {
  required String serverText,
  bool serverGone = false,
  required ValueChanged<String> onCopy,
}) async {
  final choice = await showAdaptiveSheet<SoulChangedChoice>(
    context,
    maxWidth: 480,
    builder: (sheet) => SafeArea(
      child: SoulChangedSheet(
        serverText: serverText,
        serverGone: serverGone,
        dialog:
            Theme.of(sheet).platform == TargetPlatform.macOS ||
            isWideLayout(sheet),
        onKeepEditing: () =>
            Navigator.of(sheet).pop(SoulChangedChoice.keepEditing),
        onReplaceAnyway: () =>
            Navigator.of(sheet).pop(SoulChangedChoice.replaceAnyway),
        onCopy: onCopy,
      ),
    ),
  );
  return choice ?? SoulChangedChoice.keepEditing;
}
