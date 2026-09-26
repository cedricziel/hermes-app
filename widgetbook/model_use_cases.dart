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
          name: 'Loading or unavailable (hidden)',
          builder: (_) => frame(
            ComposerModelPill(options: null, choice: null, onChanged: (_) {}),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ModelPicker',
      useCases: [
        WidgetbookUseCase(
          name: 'Model with effort levels',
          builder: (_) => fill(
            ModelPicker(
              options: modelOptions,
              selected: const ModelChoice(
                'anthropic',
                'claude-opus-4',
                effort: 'high',
              ),
              onChanged: (_) {},
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'Model without effort',
          builder: (_) => fill(
            ModelPicker(
              options: modelOptions,
              selected: _longModel,
              onChanged: (_) {},
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'Profile default, no effort',
          builder: (_) => fill(
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
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'With a default entry',
          builder: (_) => fill(
            ModelPicker(
              options: modelOptions,
              selected: null,
              onChanged: (_) {},
              onUseDefault: () {},
              withEffort: false,
            ),
            width: 420,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'HelperModelList',
      useCases: [
        WidgetbookUseCase(
          name: 'Pinned and on the main model',
          builder: (_) => HelperModelList(models: helperModels, onTap: (_) {}),
        ),
        WidgetbookUseCase(
          name: 'With mixture of agents',
          builder: (_) => HelperModelList(
            models: AuxiliaryModels(slots: helperModels.slots.sublist(0, 3)),
            onTap: (_) {},
            moa: helperMoa(),
            onTapMoa: (_) {},
          ),
        ),
        WidgetbookUseCase(
          name: 'Named MoA preset, advisor off, saving',
          builder: (_) => HelperModelList(
            models: AuxiliaryModels(slots: helperModels.slots.sublist(0, 2)),
            onTap: (_) {},
            moa: helperMoa(preset: 'deep-research', advisorOff: true),
            onTapMoa: (_) {},
            saving: const {'moa-aggregator'},
          ),
        ),
        WidgetbookUseCase(
          name: 'Saving a slot',
          builder: (_) => HelperModelList(
            models: helperModels,
            saving: const {'vision'},
            onTap: (_) {},
          ),
        ),
        WidgetbookUseCase(
          name: 'Main model unknown',
          builder: (_) => HelperModelList(
            models: AuxiliaryModels(slots: helperModels.slots.sublist(1, 3)),
            onTap: (_) {},
          ),
        ),
      ],
    ),
  ],
);

/// The pill with a choice that follows what the picker reports.
class _Pill extends StatefulWidget {
  const _Pill({required this.choice});

  final ModelChoice? choice;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  late ModelChoice? _choice = widget.choice;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ComposerModelPill(
      options: modelOptions,
      choice: _choice,
      onChanged: (choice) => setState(() => _choice = choice),
    ),
  );
}
