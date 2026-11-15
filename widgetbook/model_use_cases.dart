import 'package:flutter/material.dart';
import 'package:hermes_app/src/models/auxiliary_models.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/settings/widgets/helper_model_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

const _longModel = ModelChoice(
  'openrouter',
  'meta-llama/llama-4-maverick-17b-128e-instruct-long-context',
);

WidgetbookNode modelNode() => WidgetbookFolder(
  name: 'Models',
  children: [
    WidgetbookComponent(
      name: 'ComposerModelPill',
      useCases: [
        WidgetbookUseCase(
          name: 'Server default',
          builder: (_) => frame(_Pill(choice: null)),
        ),
        WidgetbookUseCase(
          name: 'With effort',
          builder: (_) => frame(
            _Pill(
              choice: const ModelChoice(
                'anthropic',
                'claude-opus-4',
                effort: 'medium',
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Long model id, truncated',
          builder: (_) => frame(_Pill(choice: _longModel), maxWidth: 260),
        ),
        WidgetbookUseCase(
          name: 'Model without effort',
          builder: (_) => frame(
            _Pill(choice: const ModelChoice('anthropic', 'claude-haiku-4-5')),
          ),
        ),
        WidgetbookUseCase(
          name: 'Profile default (Kanban task)',
          builder: (_) => frame(
            _Pill(choice: null, options: kanbanModelOptions, canReset: true),
          ),
        ),
        WidgetbookUseCase(
          name: 'Loading models',
          builder: (_) => frame(
            ComposerModelPill(options: null, choice: null, onChanged: (_) {}),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ModelPicker',
      useCases: [
        ...onEachPlatform(
          'Model with effort levels',
          (_) => _picker(
            ModelPicker(
              options: modelOptions,
              selected: const ModelChoice(
                'anthropic',
                'claude-opus-4',
                effort: 'high',
              ),
              onChanged: (_) {},
            ),
          ),
        ),
        ...onEachPlatform(
          'Model without effort',
          (_) => _picker(
            ModelPicker(
              options: modelOptions,
              selected: _longModel,
              onChanged: (_) {},
            ),
          ),
        ),
        ...onEachPlatform(
          'Profile default, no effort',
          (_) => _picker(
            ModelPicker(
              options: modelOptions,
              selected: modelOptions.current,
              onChanged: (_) {},
              withEffort: false,
              title: 'Default model',
              note:
                  'New chats in Work assistant start with this model. '
                  'Open chats keep theirs.',
            ),
          ),
        ),
        ...onEachPlatform(
          'With a default entry',
          (_) => _picker(
            ModelPicker(
              options: modelOptions,
              selected: null,
              onChanged: (_) {},
              onUseDefault: () {},
              withEffort: false,
            ),
          ),
        ),
        ...onEachPlatform(
          'Default entry, long model name',
          (_) => _picker(
            ModelPicker(
              options: ModelOptions(
                current: _longModel,
                providers: modelOptions.providers,
              ),
              selected: null,
              onChanged: (_) {},
              onUseDefault: () {},
              withEffort: false,
            ),
          ),
        ),
        ...onEachPlatform(
          'Default entry, default unknown',
          (_) => _picker(
            ModelPicker(
              options: kanbanModelOptions,
              selected: null,
              onChanged: (_) {},
              onUseDefault: () {},
              withEffort: false,
            ),
          ),
        ),
        ...onEachPlatform(
          'Explicit pick checked, default still named',
          (_) => _picker(
            ModelPicker(
              options: modelOptions,
              selected: const ModelChoice('anthropic', 'claude-haiku-4-5'),
              onChanged: (_) {},
              onUseDefault: () {},
              withEffort: false,
            ),
          ),
        ),
        ...onEachPlatform(
          'Kanban task: default entry and effort',
          (_) => _picker(
            ModelPicker(
              options: kanbanModelOptions,
              selected: const ModelChoice(
                'anthropic',
                'claude-opus-4',
                effort: 'xhigh',
              ),
              onChanged: (_) {},
              onUseDefault: () {},
            ),
          ),
        ),
        ...onEachPlatform(
          'Long list with search',
          (_) => _picker(
            ModelPicker(
              options: _manyModels,
              selected: const ModelChoice('openrouter', 'openai/gpt-5.1'),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    ),
    // On a desktop platform the picker opens as a popover on the composer's
    // pill (a dialog without an anchor) at any window width, never as a
    // bottom sheet. 800 pt is the default Mac window.
    WidgetbookComponent(
      name: 'ModelPicker presentation',
      useCases: [
        for (final (label, platform, width, state) in [
          ('Default checked', TargetPlatform.macOS, 800.0, _State.defaultRow),
          ('Pick with effort', TargetPlatform.macOS, 800.0, _State.effort),
          (
            'Pick with effort, wide',
            TargetPlatform.macOS,
            1200.0,
            _State.effort,
          ),
          ('Long ids', TargetPlatform.macOS, 800.0, _State.longIds),
          ('Default unknown', TargetPlatform.macOS, 800.0, _State.unknown),
          ('Search, scrolls', TargetPlatform.macOS, 800.0, _State.many),
          ('Windows', TargetPlatform.windows, 800.0, _State.effort),
          ('Linux', TargetPlatform.linux, 800.0, _State.effort),
          (
            'Without an anchor (dialog)',
            TargetPlatform.macOS,
            800.0,
            _State.noAnchor,
          ),
          ('Phone (bottom sheet)', TargetPlatform.iOS, 390.0, _State.effort),
        ])
          WidgetbookUseCase(
            name: 'Desktop popover: $label',
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(platform: platform),
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: Size(width, 700)),
                  child: _PopoverHost(state: state),
                ),
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'HelperModelList',
      useCases: [
        ...onEachPlatform(
          'Pinned and on the main model',
          (_) => HelperModelList(models: helperModels, onTap: (_) {}),
        ),
        ...onEachPlatform(
          'With mixture of agents',
          (_) => HelperModelList(
            models: AuxiliaryModels(
              main: helperModels.main,
              slots: helperModels.slots.sublist(0, 3),
            ),
            onTap: (_) {},
            moa: helperMoa(),
            onTapMoa: (_) {},
          ),
        ),
        ...onEachPlatform(
          'Named MoA preset, advisor off, saving',
          (_) => HelperModelList(
            models: AuxiliaryModels(slots: helperModels.slots.sublist(0, 2)),
            onTap: (_) {},
            moa: helperMoa(preset: 'deep-research', advisorOff: true),
            onTapMoa: (_) {},
            saving: const {'moa-aggregator'},
          ),
        ),
        ...onEachPlatform(
          'MoA locked by the privacy filter',
          (_) => HelperModelList(
            models: AuxiliaryModels(slots: helperModels.slots.sublist(0, 2)),
            onTap: (_) {},
            moa: helperMoa(privacyFilter: true),
          ),
        ),
        ...onEachPlatform(
          'Saving a slot',
          (_) => HelperModelList(
            models: helperModels,
            saving: const {'vision'},
            onTap: (_) {},
          ),
        ),
        ...onEachPlatform(
          'With the difference link',
          (_) => HelperModelList(
            models: helperModels,
            onTap: (_) {},
            onWhatsTheDifference: () {},
          ),
        ),
        ...onEachPlatform(
          'Main model unknown',
          (_) => HelperModelList(
            models: AuxiliaryModels(slots: helperModels.slots.sublist(1, 3)),
            onTap: (_) {},
          ),
        ),
      ],
    ),
  ],
);

/// A picker in a sheet's width and colour.
Widget _picker(ModelPicker picker) => Builder(
  builder: (context) => fill(
    Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: picker,
    ),
    width: 420,
  ),
);

const _manyModels = ModelOptions(
  providers: [
    ModelProviderOption(
      id: 'anthropic',
      label: 'Anthropic',
      models: [
        ModelOption(id: 'claude-opus-4'),
        ModelOption(id: 'claude-sonnet-4-5'),
        ModelOption(id: 'claude-haiku-4-5', reasoning: false),
      ],
    ),
    ModelProviderOption(
      id: 'openrouter',
      label: 'OpenRouter',
      models: [
        ModelOption(id: 'openai/gpt-5.1'),
        ModelOption(id: 'openai/gpt-5.1-mini'),
        ModelOption(id: 'google/gemini-2.5-pro'),
        ModelOption(id: 'deepseek/deepseek-v4-pro'),
        ModelOption(id: 'qwen/qwen3-coder', reasoning: false),
        ModelOption(id: 'x-ai/grok-4'),
      ],
    ),
  ],
);

/// The pill with a choice that follows what the picker reports.
class _Pill extends StatefulWidget {
  const _Pill({
    required this.choice,
    this.options = modelOptions,
    this.canReset = false,
  });

  final ModelChoice? choice;
  final ModelOptions options;
  final bool canReset;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  late ModelChoice? _choice = widget.choice;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ComposerModelPill(
      options: widget.options,
      choice: _choice,
      onChanged: (choice) => setState(() => _choice = choice),
      onUseDefault: widget.canReset
          ? () => setState(() => _choice = null)
          : null,
    ),
  );
}

enum _State { defaultRow, effort, longIds, unknown, many, noAnchor }

/// A fake composer pill at the bottom left that opens the picker on itself,
/// as the real pill does.
class _PopoverHost extends StatefulWidget {
  const _PopoverHost({required this.state});

  final _State state;

  @override
  State<_PopoverHost> createState() => _PopoverHostState();
}

class _PopoverHostState extends State<_PopoverHost> {
  final _pill = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  void _open() {
    final box = _pill.currentContext!.findRenderObject()! as RenderBox;
    final anchor = widget.state == _State.noAnchor
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final (options, selected) = switch (widget.state) {
      _State.defaultRow => (modelOptions, null),
      _State.longIds => (
        ModelOptions(current: _longModel, providers: modelOptions.providers),
        _longModel,
      ),
      _State.unknown => (kanbanModelOptions, null),
      _State.many => (
        _manyModels,
        const ModelChoice('openrouter', 'openai/gpt-5.1'),
      ),
      _ => (
        modelOptions,
        const ModelChoice('anthropic', 'claude-opus-4', effort: 'high'),
      ),
    };
    showModelPicker(
      context,
      options: options,
      selected: selected,
      onChanged: (_) {},
      onUseDefault: widget.state == _State.effort ? null : () {},
      anchor: anchor,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          key: _pill,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('claude-opus-4 · High'),
        ),
      ),
    ),
  );
}
