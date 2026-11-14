import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_list.dart';
import '../tools_models.dart';
import 'tools_target.dart';

/// The content of the model picker for image and video generation: the title
/// "Model" with Done, and a choice row for each model with "Default" as muted
/// meta after the name and speed, strengths and price on the second line.
/// The price is free text from the provider and is shown as given. The footer
/// says where prices come from and when the pick applies.
///
/// It takes plain values: [current] is the model id that shows checked and
/// [onPick] reports a tap. The caller keeps the pick.
class ToolsetModelSheet extends StatelessWidget {
  const ToolsetModelSheet({
    super.key,
    required this.models,
    required this.current,
    required this.provider,
    required this.onPick,
    required this.onDone,
    this.defaultModel,
  });

  final List<ToolsetModel> models;
  final String? current;
  final String? defaultModel;

  /// The provider's name, in the footer.
  final String provider;
  final ValueChanged<String> onPick;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            metrics.gutter,
            mac ? 10 : 8,
            metrics.gutter / 2,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.toolsModelTitle,
                    style: TextStyle(
                      fontSize: mac ? 13 : 17,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: onDone,
                style: toolsButtonStyle(context),
                child: Text(l10n.toolsDone),
              ),
            ],
          ),
        ),
        Flexible(
          child: RadioGroup<String>(
            groupValue: current,
            onChanged: (id) {
              if (id != null) onPick(id);
            },
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                metrics.gutter,
                0,
                metrics.gutter,
                16,
              ),
              children: [
                GroupedSection(
                  dividerIndent: GroupedChoiceRow.dividerIndent(context),
                  footer: l10n.toolsModelFooter(provider),
                  children: [
                    for (final model in models)
                      GroupedChoiceRow<String>(
                        key: Key('tools-model-${model.id}'),
                        value: model.id,
                        title: model.display,
                        titleMaxLines: null,
                        meta: model.id == defaultModel
                            ? l10n.toolsModelDefault
                            : null,
                        subtitle: _secondLine(model),
                        subtitleMaxLines: null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Speed, strengths and price as the provider gave them, or null when it
  /// gave none.
  static String? _secondLine(ToolsetModel model) {
    final parts = [
      for (final part in [model.speed, model.strengths, model.price])
        if (part != null && part.trim().isNotEmpty) part.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Opens [ToolsetModelSheet]: a bottom sheet on a phone, a dialog on a Mac
/// and on wide windows. [onPick] is called for each tap; Done closes it.
Future<void> showToolsetModelSheet(
  BuildContext context, {
  required List<ToolsetModel> models,
  required String? current,
  required String provider,
  required ValueChanged<String> onPick,
  String? defaultModel,
}) {
  var picked = current;
  return showAdaptiveSheet<void>(
    context,
    maxWidth: 440,
    builder: (sheet) => StatefulBuilder(
      builder: (_, setState) => SafeArea(
        child: ToolsetModelSheet(
          models: models,
          current: picked,
          defaultModel: defaultModel,
          provider: provider,
          onPick: (id) {
            setState(() => picked = id);
            onPick(id);
          },
          onDone: () => Navigator.of(sheet).pop(),
        ),
      ),
    ),
  );
}
