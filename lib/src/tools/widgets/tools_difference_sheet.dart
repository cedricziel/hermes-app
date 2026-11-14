import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/grouped_list.dart';
import 'tools_switch.dart' show toolsLargeText;
import 'tools_target.dart';

/// "What's the difference?": the title "Tools, skills, plugins and MCP
/// servers", four short paragraphs with the term in bold at the start, and
/// Done.
class ToolsDifferenceSheet extends StatelessWidget {
  const ToolsDifferenceSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final terms = [
      (l10n.toolsDifferenceToolsTerm, l10n.toolsDifferenceToolsText),
      (l10n.toolsDifferenceSkillsTerm, l10n.toolsDifferenceSkillsText),
      (l10n.toolsDifferencePluginsTerm, l10n.toolsDifferencePluginsText),
      (l10n.toolsDifferenceMcpTerm, l10n.toolsDifferenceMcpText),
    ];
    final large = toolsLargeText(context);
    final title = Semantics(
      header: true,
      child: Text(
        l10n.toolsDifferenceTitle,
        style: TextStyle(
          fontSize: mac ? 13 : 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
    final done = TextButton(
      onPressed: onDone,
      style: toolsButtonStyle(context),
      child: Text(l10n.toolsDone),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // At the largest text the title scrolls with the text, so Done stays
        // in reach however tall the title gets.
        if (large)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: metrics.gutter / 2),
              child: done,
            ),
          )
        else
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              metrics.gutter,
              mac ? 10 : 8,
              metrics.gutter / 2,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: title,
                  ),
                ),
                done,
              ],
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(metrics.gutter, 8, metrics.gutter, 20),
            children: [
              if (large)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: title,
                ),
              for (final (term, text) in terms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: term,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' $text'),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: metrics.titleSize,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens [ToolsDifferenceSheet]: a bottom sheet on a phone, a dialog on a Mac
/// and on wide windows.
Future<void> showToolsDifferenceSheet(BuildContext context) =>
    showAdaptiveSheet<void>(
      context,
      maxWidth: 440,
      builder: (sheet) => SafeArea(
        child: ToolsDifferenceSheet(onDone: () => Navigator.of(sheet).pop()),
      ),
    );
