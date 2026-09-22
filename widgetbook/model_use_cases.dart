import 'package:flutter/material.dart';
import 'package:hermes_app/src/models/widgets/effort_menu_button.dart';
import 'package:hermes_app/src/models/widgets/model_effort_picker.dart';
import 'package:hermes_app/src/models/widgets/model_menu_button.dart';
import 'package:hermes_app/src/models/widgets/new_chat_model_bar.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookNode modelNode() => WidgetbookFolder(
  name: 'Models',
  children: [
    WidgetbookComponent(
      name: 'NewChatModelBar',
      useCases: [
        WidgetbookUseCase(
          name: 'Above a new chat',
          builder: (_) => fill(
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NewChatModelBar(
                    providers: modelProviders,
                    selectedProviderId: 'anthropic',
                    selectedModelId: 'claude-sonnet-5',
                    selectedEffort: 'medium',
                    onModelSelected: (_, _) {},
                    onEffortSelected: (_) {},
                    onRefreshModels: () {},
                    onEditModels: () {},
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Message Hermes…',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'Model has no effort levels',
          builder: (_) => fill(
            NewChatModelBar(
              providers: modelProviders,
              selectedProviderId: 'anthropic',
              selectedModelId: 'claude-haiku-4-5',
              onModelSelected: (_, _) {},
              onEffortSelected: (_) {},
              onEditModels: () {},
            ),
            width: 420,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ModelMenuButton',
      useCases: [
        WidgetbookUseCase(
          name: 'Closed',
          builder: (_) => fill(
            ModelMenuButton(
              providers: modelProviders,
              selectedProviderId: 'openai',
              selectedModelId: 'gpt-5.1',
              onModelSelected: (_, _) {},
            ),
            width: 300,
          ),
        ),
        WidgetbookUseCase(
          name: 'Open, searchable list',
          builder: (_) => fill(
            ModelMenuButton(
              providers: modelProviders,
              selectedProviderId: 'anthropic',
              selectedModelId: 'claude-sonnet-5',
              onModelSelected: (_, _) {},
              onRefresh: () {},
              onEditModels: () {},
              initiallyOpen: true,
            ),
            width: 320,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'EffortMenuButton',
      useCases: [
        WidgetbookUseCase(
          name: 'Open',
          builder: (_) => fill(
            EffortMenuButton(
              options: const ['low', 'medium', 'high'],
              selected: 'medium',
              onSelected: (_) {},
              initiallyOpen: true,
            ),
            width: 200,
          ),
        ),
        WidgetbookUseCase(
          name: 'No levels for this model',
          builder: (_) => fill(
            EffortMenuButton(
              options: const [],
              selected: null,
              onSelected: (_) {},
            ),
            width: 200,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ModelEffortPicker',
      useCases: [
        WidgetbookUseCase(
          name: 'Clean',
          builder: (_) => fill(
            ModelEffortPicker(
              providers: modelProviders,
              selectedProviderId: 'anthropic',
              selectedModelId: 'claude-sonnet-5',
              selectedEffort: 'medium',
              onModelSelected: (_, _) {},
              onEffortSelected: (_) {},
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'Dirty, ready to save',
          builder: (_) => fill(
            ModelEffortPicker(
              providers: modelProviders,
              selectedProviderId: 'openai',
              selectedModelId: 'gpt-5.1',
              selectedEffort: 'high',
              dirty: true,
              onModelSelected: (_, _) {},
              onEffortSelected: (_) {},
              onSave: () {},
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'Saving',
          builder: (_) => fill(
            ModelEffortPicker(
              providers: modelProviders,
              selectedProviderId: 'openai',
              selectedModelId: 'gpt-5.1',
              selectedEffort: 'high',
              dirty: true,
              saving: true,
              onModelSelected: (_, _) {},
              onEffortSelected: (_) {},
              onSave: () {},
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'Model without a reasoning effort',
          builder: (_) => fill(
            ModelEffortPicker(
              providers: modelProviders,
              selectedProviderId: 'anthropic',
              selectedModelId: 'claude-haiku-4-5',
              onModelSelected: (_, _) {},
              onEffortSelected: (_) {},
            ),
            width: 420,
          ),
        ),
        WidgetbookUseCase(
          name: 'No providers configured',
          builder: (_) => fill(
            ModelEffortPicker(
              providers: const [],
              selectedProviderId: '',
              selectedModelId: '',
              onModelSelected: (_, _) {},
              onEffortSelected: (_) {},
            ),
            width: 420,
          ),
        ),
      ],
    ),
  ],
);
