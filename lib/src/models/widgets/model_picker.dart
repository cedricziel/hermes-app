import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart';
import '../../theme/breakpoints.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/anchored_popover.dart';
import '../../widgets/dialog_presentation.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/settings_search_field.dart';
import '../model_provider_option.dart';

bool _isDesktop(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

/// Opens [ModelPicker]. The platform decides first: on macOS, Windows and
/// Linux it is a popover on [anchor] (a global rectangle, only the composer's
/// pill passes one) or, without an anchor, the app's adaptive dialog, at any
/// window width. On iOS and Android it is a dialog from [isWideLayout] and a
/// bottom sheet below it. Without [withEffort] a pick is final, so it
/// closes the picker, and so does [onUseDefault].
Future<void> showModelPicker(
  BuildContext context, {
  required ModelOptions options,
  required ModelChoice? selected,
  required ValueChanged<ModelChoice> onChanged,
  bool withEffort = true,
  String? title,
  String? note,
  VoidCallback? onUseDefault,
  Listenable? updates,
  ModelOptions? Function()? latest,
  ModelChoice? Function()? latestSelected,
  Rect? anchor,
  PopoverHandle? popoverHandle,
}) {
  ModelOptions currentOptions() => latest?.call() ?? options;
  ModelChoice? currentSelected() =>
      latestSelected == null ? selected : latestSelected();
  Widget picker(
    BuildContext sheet,
    ModelOptions pickerOptions,
    ModelChoice? pickerSelected, {
    ModelPickerPresentation presentation = ModelPickerPresentation.sheet,
  }) => ModelPicker(
    presentation: presentation,
    options: pickerOptions,
    selected: pickerSelected,
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
  Widget live(
    BuildContext sheet, {
    ModelPickerPresentation presentation = ModelPickerPresentation.sheet,
  }) => updates == null
      ? picker(
          sheet,
          currentOptions(),
          currentSelected(),
          presentation: presentation,
        )
      : _LivePicker(
          updates: updates,
          options: currentOptions,
          selected: currentSelected,
          builder: (options, selected) =>
              picker(sheet, options, selected, presentation: presentation),
        );
  final size = MediaQuery.sizeOf(context);
  Widget dialogBody(BuildContext dialog) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
      child: live(dialog, presentation: ModelPickerPresentation.dialog),
    ),
  );
  // A desktop window is never a phone: the app's adaptive dialog at any
  // width, a bottom sheet only on iOS and Android.
  if (_isDesktop(context) && anchor != null) {
    return showAnchoredPopover<void>(
      context,
      anchor: anchor,
      semanticLabel: title ?? context.l10n.modelsPickerTitle,
      handle: popoverHandle,
      builder: (popover) =>
          live(popover, presentation: ModelPickerPresentation.popover),
    );
  }
  if (_isDesktop(context)) {
    return showAppDialog<void>(context: context, builder: dialogBody);
  }
  if (isWideLayout(context)) {
    return showDialog<void>(context: context, builder: dialogBody);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.75),
        child: live(sheet),
      ),
    ),
  );
}

/// Rebuilds [builder] when [updates] fires, but only when the options (by
/// identity) or the selection really changed, so a stream of unrelated
/// notifications leaves an open picker alone.
class _LivePicker extends StatefulWidget {
  const _LivePicker({
    required this.updates,
    required this.options,
    required this.selected,
    required this.builder,
  });

  final Listenable updates;
  final ModelOptions Function() options;
  final ModelChoice? Function() selected;
  final Widget Function(ModelOptions options, ModelChoice? selected) builder;

  @override
  State<_LivePicker> createState() => _LivePickerState();
}

class _LivePickerState extends State<_LivePicker> {
  late ModelOptions _options = widget.options();
  late ModelChoice? _selected = widget.selected();

  @override
  void initState() {
    super.initState();
    widget.updates.addListener(_changed);
  }

  @override
  void didUpdateWidget(_LivePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.updates != oldWidget.updates) {
      oldWidget.updates.removeListener(_changed);
      widget.updates.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.updates.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final options = widget.options();
    final selected = widget.selected();
    if (identical(options, _options) && selected == _selected) return;
    setState(() {
      _options = options;
      _selected = selected;
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_options, _selected);
}

class _RowMoveIntent extends Intent {
  const _RowMoveIntent(this.step);

  final int step;
}

/// Moves focus between rows, and only while a model row has it: elsewhere
/// (an effort pill, the search field) the key goes on to its own handler.
class _RowMoveAction extends Action<_RowMoveIntent> {
  _RowMoveAction({required this.enabled, required this.move});

  final bool Function() enabled;
  final void Function(int step) move;

  @override
  bool isEnabled(_RowMoveIntent intent, [BuildContext? context]) => enabled();

  @override
  Object? invoke(_RowMoveIntent intent) {
    move(intent.step);
    return null;
  }
}

/// In a popover the arrows only move focus, one row at a time, and Return or
/// Space picks. The radio group's own arrows would pick as they move, so this
/// sits below it, nearer the focus, and walks the rows itself.
Widget _popoverKeys({
  required bool popover,
  required bool Function() enabled,
  required void Function(int step) move,
  required Widget list,
}) => !popover
    ? list
    : Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): _RowMoveIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _RowMoveIntent(-1),
        },
        child: Actions(
          actions: {
            _RowMoveIntent: _RowMoveAction(enabled: enabled, move: move),
          },
          child: list,
        ),
      );

/// Where a [ModelPicker] is shown.
enum ModelPickerPresentation { sheet, dialog, popover }

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
    this.title,
    this.note,
    this.onUseDefault,
    this.presentation = ModelPickerPresentation.sheet,
  });

  final ModelOptions options;
  final ModelChoice? selected;
  final ValueChanged<ModelChoice> onChanged;
  final bool withEffort;

  /// Null names the picker "Model".
  final String? title;
  final String? note;

  /// When set, a "Use the profile's default" entry comes first, checked
  /// while nothing is selected. It names [ModelOptions.current] when the
  /// server reported one.
  final VoidCallback? onUseDefault;

  /// Where it is shown. A popover has no visible title (the route is named
  /// by [title]), a full-width search field first, [note] under it, and the
  /// checked row takes the keyboard focus.
  final ModelPickerPresentation presentation;

  /// More models than this get a search field.
  static const searchAbove = 8;

  /// From this text scale on, the effort pills scroll at the end of the list
  /// instead of staying pinned under it, so they cannot take the room the
  /// rows need.
  static const unpinEffortAtScale = 1.3;

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

  final _nodes = <_Pick, FocusNode>{};

  FocusNode _nodeFor(_Pick pick) =>
      _nodes.putIfAbsent(pick, () => FocusNode(debugLabel: 'model row'));

  /// Whether a model row has the focus: the arrows are the picker's only
  /// then; on an effort pill or the search field they are left alone.
  bool _rowHasFocus(List<_Pick> order) =>
      order.any((pick) => _nodeFor(pick).hasFocus);

  /// Moves focus [step] rows through [order], wrapping at the ends, and
  /// scrolls the row into view.
  void _moveFocus(List<_Pick> order, int step) {
    if (order.isEmpty) return;
    final at = order.indexWhere((pick) => _nodeFor(pick).hasFocus);
    if (at < 0) return;
    final next = (at + step) % order.length;
    final node = _nodeFor(order[next])..requestFocus();
    final context = node.context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: next > at
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
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
    final popover = widget.presentation == ModelPickerPresentation.popover;
    final gutter = popover ? 12.0 : metrics.gutter;
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
            fullWidth: popover,
            search: SettingsSearch(
              query: _query,
              hint: context.l10n.modelsPickerSearchHint,
              onChanged: (query) => setState(() => _query = query),
            ),
          )
        : null;
    final providers = _matching(query);
    // The rows in the order they are drawn, for the popover's arrow keys.
    final order = <_Pick>[
      if (widget.onUseDefault != null && query.isEmpty) _defaultPick,
      for (final provider in providers)
        for (final model in provider.models) (provider.id, model.id),
    ];
    // The row that takes the focus when a popover opens: the checked one, or
    // the first when nothing is checked.
    final autoPick = selected != null
        ? (selected.providerId, selected.modelId)
        : (widget.onUseDefault != null && query.isEmpty
              ? _defaultPick
              : (order.isEmpty ? null : order.first));
    final dividerIndent = GroupedChoiceRow.dividerIndent(context);
    final large =
        MediaQuery.textScalerOf(context).scale(14) / 14 >=
        ModelPicker.unpinEffortAtScale;
    final desktop = const {
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }.contains(Theme.of(context).platform);
    final title = Text(
      widget.title ?? context.l10n.modelsPickerTitle,
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
    // Pinned under the list, or at its end from a large text scale on.
    final effortBlock = efforts.isEmpty
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              // `outline`, not `outlineVariant`: that is the dark overlay surface.
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(large ? 0 : gutter, 12, gutter, 16),
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
                            ? context.l10n.modelsPickerEffortHeader
                                  .toUpperCase()
                            : context.l10n.modelsPickerEffortHeader,
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
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (popover) ...[
          // The route is named by the title; nothing draws it.
          const SizedBox(height: 12),
          if (search != null)
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
              child: search,
            ),
        ] else
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
        if (search != null && !mac && !popover)
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
            child: _popoverKeys(
              popover: popover,
              enabled: () => _rowHasFocus(order),
              move: (step) => _moveFocus(order, step),
              list: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  popover ? 12 : 16,
                ),
                children: [
                  if (widget.onUseDefault != null && query.isEmpty)
                    GroupedSection(
                      children: [
                        GroupedChoiceRow<_Pick>(
                          key: const Key('model-default'),
                          value: _defaultPick,
                          autofocus: popover && autoPick == _defaultPick,
                          rowFocusable: !popover,
                          focusNode: popover ? _nodeFor(_defaultPick) : null,
                          title: context.l10n.modelsPickerUseDefault,
                          titleMaxLines: large ? 2 : 1,
                          subtitleMaxLines: large ? 2 : 1,
                          subtitleMiddleEllipsis: true,
                          // The server's value, drawn with its control and
                          // bidi characters visible.
                          subtitle: widget.options.current == null
                              ? null
                              : context.l10n.modelsPickerDefaultUses(
                                  safePathText(widget.options.current!.modelId),
                                ),
                        ),
                      ],
                    ),
                  for (final provider in providers)
                    GroupedSection(
                      header: provider.displayLabel,
                      dividerIndent: dividerIndent,
                      children: [
                        for (final model in provider.models)
                          _hoverName(
                            desktop,
                            safePathText(model.id),
                            GroupedChoiceRow<_Pick>(
                              key: Key('model-${provider.id}-${model.id}'),
                              value: (provider.id, model.id),
                              rowFocusable: !popover,
                              focusNode: popover
                                  ? _nodeFor((provider.id, model.id))
                                  : null,
                              autofocus:
                                  popover &&
                                  autoPick == (provider.id, model.id),
                              title: safePathText(model.id),
                              titleMaxLines: large ? 2 : 1,
                              titleMiddleEllipsis: true,
                            ),
                          ),
                      ],
                    ),
                  if (providers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        context.l10n.modelsPickerNoMatch(query),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: metrics.subtitleSize,
                          color: muted,
                        ),
                      ),
                    ),
                  if (effortBlock != null && large) effortBlock,
                ],
              ),
            ),
          ),
        ),
        if (effortBlock != null && !large) effortBlock,
      ],
    );
  }
}

/// [row] with [name] as its hover text on a pointer platform, which a touch
/// screen never shows.
Widget _hoverName(bool desktop, String name, Widget row) =>
    desktop ? Tooltip(message: name, child: row) : row;

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
    // The pill as drawn, the area that takes a tap, and the text size.
    final (height, hit, fontSize) = switch (chrome) {
      PlatformChrome.ios => (36.0, 44.0, 15.0),
      PlatformChrome.macos => (28.0, 28.0, 12.0),
      PlatformChrome.material => (40.0, 48.0, 14.0),
    };
    final side = selected ? BorderSide(color: scheme.outline) : BorderSide.none;
    final shape = chrome.isApple
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 4),
            side: side,
          )
        : StadiumBorder(side: side);
    final pill = Material(
      color: selected ? scheme.surface : scheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // A minimum: the pill grows with the text size.
          constraints: BoxConstraints(minHeight: height),
          padding: EdgeInsets.symmetric(horizontal: height / 2.5, vertical: 4),
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
    );
    return Semantics(
      button: true,
      selected: selected,
      child: hit <= height
          ? pill
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: hit),
                child: Center(widthFactor: 1, child: pill),
              ),
            ),
    );
  }
}
