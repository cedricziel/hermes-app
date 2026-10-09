import 'package:flutter/material.dart';

import '../../theme/breakpoints.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/settings_search_field.dart';
import '../model_provider_option.dart';

/// Opens [ModelPicker]: a bottom sheet on a phone, a dialog from
/// [isWideLayout]. Without [withEffort] a pick is final, so it
/// closes the picker, and so does [onUseDefault].
Future<void> showModelPicker(
  BuildContext context, {
  required ModelOptions options,
  required ModelChoice? selected,
  required ValueChanged<ModelChoice> onChanged,
  bool withEffort = true,
  String title = 'Model',
  String? note,
  VoidCallback? onUseDefault,
}) {
  Widget picker(BuildContext sheet) => ModelPicker(
    options: options,
    selected: selected,
    withEffort: withEffort,
    title: title,
    note: note,
    onChanged: (choice) {
      onChanged(choice);
      if (!withEffort) Navigator.of(sheet).pop();
    },
    onUseDefault: onUseDefault == null
        ? null
        : () {
            onUseDefault();
            Navigator.of(sheet).pop();
          },
  );
  final size = MediaQuery.sizeOf(context);
  if (isWideLayout(context)) {
    return showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: picker(dialog),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.75),
        child: picker(sheet),
      ),
    ),
  );
}

/// Picks a model, grouped by provider, and the reasoning effort when the
/// model takes one, unless [withEffort] is off. Each pick is reported through
/// [onChanged] at once. [note], when given, is shown under [title]. A long
/// list gets a search field.
class ModelPicker extends StatefulWidget {
  const ModelPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.withEffort = true,
    this.title = 'Model',
    this.note,
    this.onUseDefault,
  });

  final ModelOptions options;
  final ModelChoice? selected;
  final ValueChanged<ModelChoice> onChanged;
  final bool withEffort;
  final String title;
  final String? note;

  /// When set, a "Use the profile's default" entry comes first, checked
  /// while nothing is selected.
  final VoidCallback? onUseDefault;

  /// More models than this get a search field.
  static const searchAbove = 8;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

/// A row's value: a provider and a model id, or [_defaultPick].
typedef _Pick = (String, String);

const _Pick _defaultPick = ('', '');

class _ModelPickerState extends State<ModelPicker> {
  late ModelChoice? _selected = widget.selected;
  String _query = '';

  @override
  void didUpdateWidget(ModelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) _selected = widget.selected;
  }

  void _pick(ModelChoice choice) {
    setState(() => _selected = choice);
    widget.onChanged(choice);
  }

  void _onPicked(_Pick? pick) {
    if (pick == null) return;
    if (pick == _defaultPick) {
      setState(() => _selected = null);
      widget.onUseDefault!();
      return;
    }
    final (providerId, modelId) = pick;
    final model = widget.options.model(ModelChoice(providerId, modelId));
    final effort = _selected?.effort;
    _pick(
      ModelChoice(
        providerId,
        modelId,
        effort: widget.withEffort && (model?.efforts.contains(effort) ?? false)
            ? effort
            : null,
      ),
    );
  }

  /// The providers to list: those whose name matches the search with all
  /// their models, the others with only the models whose id matches.
  List<ModelProviderOption> _matching(String search) {
    final query = search.toLowerCase();
    if (query.isEmpty) return widget.options.providers;
    return [
      for (final provider in widget.options.providers)
        if (provider.displayLabel.toLowerCase().contains(query))
          provider
        else if (provider.models
                .where((model) => model.id.toLowerCase().contains(query))
                .toList()
            case final models when models.isNotEmpty)
          ModelProviderOption(
            id: provider.id,
            label: provider.label,
            models: models,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final chrome = platformChromeOf(context);
    final mac = chrome == PlatformChrome.macos;
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final gutter = metrics.gutter;
    final selected = _selected;
    final efforts = selected == null || !widget.withEffort
        ? const <String>[]
        : widget.options.model(selected)?.efforts ?? const <String>[];
    final modelCount = widget.options.providers
        .expand((provider) => provider.models)
        .length;
    final query = _query.trim();
    final search = modelCount > ModelPicker.searchAbove
        ? SettingsSearchField(
            search: SettingsSearch(
              query: _query,
              hint: 'Search models',
              onChanged: (query) => setState(() => _query = query),
            ),
          )
        : null;
    final providers = _matching(query);
    final dividerIndent = GroupedChoiceRow.dividerIndent(context);
    final title = Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: switch (chrome) {
          PlatformChrome.ios => 17,
          PlatformChrome.macos => 13,
          PlatformChrome.material => 18,
        },
        fontWeight: mac ? FontWeight.w700 : FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, mac ? 14 : 16, gutter, 0),
          child: mac && search != null
              ? Row(
                  spacing: 12,
                  children: [
                    Expanded(child: title),
                    search,
                  ],
                )
              : title,
        ),
        if (widget.note case final note?)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 2, gutter, 0),
            child: Text(
              note,
              style: TextStyle(fontSize: metrics.footerSize, color: muted),
            ),
          ),
        if (search != null && !mac)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
            child: search,
          ),
        Flexible(
          child: RadioGroup<_Pick>(
            groupValue: selected == null
                ? (widget.onUseDefault == null ? null : _defaultPick)
                : (selected.providerId, selected.modelId),
            onChanged: _onPicked,
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
              children: [
                if (widget.onUseDefault != null && query.isEmpty)
                  const GroupedSection(
                    children: [
                      GroupedChoiceRow<_Pick>(
                        key: Key('model-default'),
                        value: _defaultPick,
                        title: 'Use the profile’s default',
                      ),
                    ],
                  ),
                for (final provider in providers)
                  GroupedSection(
                    header: provider.displayLabel,
                    dividerIndent: dividerIndent,
                    children: [
                      for (final model in provider.models)
                        GroupedChoiceRow<_Pick>(
                          key: Key('model-${provider.id}-${model.id}'),
                          value: (provider.id, model.id),
                          title: model.id,
                        ),
                    ],
                  ),
                if (providers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No models match “$query”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: metrics.subtitleSize,
                        color: muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (efforts.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.rowPadding,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        metrics.headerUppercase
                            ? 'REASONING EFFORT'
                            : 'Reasoning effort',
                        style: TextStyle(
                          fontSize: metrics.headerSize,
                          fontWeight: metrics.headerWeight,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                  _EffortControl(
                    efforts: efforts,
                    selected: selected!.effort,
                    onChanged: (effort) => _pick(
                      ModelChoice(
                        selected.providerId,
                        selected.modelId,
                        effort: effort,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The effort levels as pills that wrap onto a second line when they don't
/// fit, the picked one raised like the thumb of a segmented control.
class _EffortControl extends StatelessWidget {
  const _EffortControl({
    required this.efforts,
    required this.selected,
    required this.onChanged,
  });

  final List<String> efforts;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final effort in efforts)
        _EffortSegment(
          key: Key('effort-$effort'),
          label: effortLabel(effort),
          selected: effort == selected,
          onTap: () => onChanged(effort),
        ),
    ],
  );
}

class _EffortSegment extends StatelessWidget {
  const _EffortSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chrome = platformChromeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final (height, fontSize) = switch (chrome) {
      PlatformChrome.ios => (32.0, 15.0),
      PlatformChrome.macos => (24.0, 12.0),
      PlatformChrome.material => (32.0, 14.0),
    };
    final side = selected ? BorderSide(color: scheme.outline) : BorderSide.none;
    final shape = chrome.isApple
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 4),
            side: side,
          )
        : StadiumBorder(side: side);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.surface : scheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: height / 2.5),
            child: Align(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
