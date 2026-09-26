import 'package:flutter/material.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
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
        WidgetbookUseCase(
          name: 'Kanban task: default entry and effort',
          builder: (_) => fill(
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
            width: 420,
          ),
        ),
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
