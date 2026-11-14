import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../widgets/disclosure_tile.dart';
import '../context_models.dart' show isAcceptableFocus;
import 'context_format.dart';

/// The content and buttons of "Compress this conversation?", for
/// `showAdaptiveSheet`.
///
/// Compress removes older messages from the model's view for good, so it is an
/// outlined button, neither filled nor red, and Cancel has the first focus. On
/// Android both are text buttons, Cancel first. At the largest text size the
/// body scrolls and the buttons stack full width. The focus text lives in this
/// widget's field only: it is handed to [onConfirm] and never stored or
/// logged. It needs a bounded height (a sheet or a dialog gives one), since
/// its body scrolls.
class CompressConfirmation extends StatefulWidget {
  const CompressConfirmation({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.replyStarted = false,
    this.initialFocus = '',
    this.advancedInitiallyOpen = false,
  });

  /// Called with the trimmed focus, or null when none was written.
  final ValueChanged<String?> onConfirm;
  final VoidCallback onCancel;

  /// The chat started replying while the sheet is open: Compress is disabled.
  final bool replyStarted;
  final String initialFocus;
  final bool advancedInitiallyOpen;

  @override
  State<CompressConfirmation> createState() => _CompressConfirmationState();
}

class _CompressConfirmationState extends State<CompressConfirmation> {
  late final TextEditingController _focus = TextEditingController(
    text: widget.initialFocus,
  );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _focus.text.trim();
    widget.onConfirm(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subtle = context.hermesColors.subtleText;
    final refused = !isAcceptableFocus(_focus.text);
    final canConfirm = !widget.replyStarted && !refused;
    final stacked = contextLargeText(context);
    final chrome = platformChromeOf(context);
    final style = contextButtonStyle(context);

    final cancel = TextButton(
      autofocus: true,
      style: style,
      onPressed: widget.onCancel,
      child: Text(l10n.chatContextCompressCancel),
    );
    final confirm = chrome == PlatformChrome.material
        ? TextButton(
            style: style,
            onPressed: canConfirm ? _confirm : null,
            child: Text(l10n.chatContextCompressConfirm),
          )
        : OutlinedButton(
            style: style,
            onPressed: canConfirm ? _confirm : null,
            child: Text(l10n.chatContextCompressConfirm),
          );

    final Widget buttons;
    if (stacked) {
      buttons = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cancel, const SizedBox(height: 8), confirm],
      );
    } else if (chrome == PlatformChrome.ios) {
      buttons = Row(
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 12),
          Expanded(child: confirm),
        ],
      );
    } else {
      buttons = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [cancel, const SizedBox(width: 8), confirm],
      );
    }

    final lines = [
      l10n.chatContextCompressBodyReplace,
      l10n.chatContextCompressBodyHelper,
      l10n.chatContextCompressBodyUndo,
      l10n.chatContextCompressBodyReload,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.chatContextCompressTitle,
                style: theme.textTheme.titleLarge,
                // Capped so a long word is not cut mid-word; the body below
                // still scales fully.
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExcludeSemantics(child: Text('•  ')),
                            Expanded(child: Text(line)),
                          ],
                        ),
                      ),
                    DisclosureTile(
                      initiallyExpanded: widget.advancedInitiallyOpen,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        top: 10,
                        bottom: 8,
                      ),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(l10n.chatContextCompressAdvanced),
                      children: [
                        TextField(
                          controller: _focus,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: l10n.chatContextCompressFocusLabel,
                            hintText: l10n.chatContextCompressFocusHint,
                            helperText: l10n.chatContextCompressFocusHelper,
                            helperMaxLines: 3,
                            errorText: refused
                                ? l10n.chatContextCompressFocusError
                                : null,
                            errorMaxLines: 6,
                          ),
                        ),
                      ],
                    ),
                    if (widget.replyStarted)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.chatContextCompressReplyStarted,
                            style: TextStyle(color: subtle),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            buttons,
          ],
        ),
      ),
    );
  }
}
