import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/models/model_options_state.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookNode messengerIdentityNode() => WidgetbookFolder(
  name: 'Messenger identity',
  children: [
    WidgetbookComponent(
      name: 'Composer selectors',
      useCases: [
        WidgetbookUseCase(
          name: 'Compact composer width, ready',
          builder: (_) => frame(
            const SizedBox(
              width: 200,
              child: _SelectorPairPreview(
                recipient: RecipientSelectorState.ready,
                model: ModelOptionsState.ready,
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Compact composer width, large text failure',
          builder: (context) => frame(
            SizedBox(
              width: 200,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: const _SelectorPairPreview(
                  recipient: RecipientSelectorState.failed,
                  model: ModelOptionsState.failed,
                ),
              ),
            ),
          ),
        ),
        for (final (label, recipient, model) in [
          (
            'Ready, long labels',
            RecipientSelectorState.ready,
            ModelOptionsState.ready,
          ),
          (
            'Loading recipients',
            RecipientSelectorState.loading,
            ModelOptionsState.ready,
          ),
          (
            'Choose recipient',
            RecipientSelectorState.choose,
            ModelOptionsState.ready,
          ),
          (
            'No profiles',
            RecipientSelectorState.empty,
            ModelOptionsState.ready,
          ),
          (
            'Unavailable recipient',
            RecipientSelectorState.unavailable,
            ModelOptionsState.ready,
          ),
          (
            'Recipient failure',
            RecipientSelectorState.failed,
            ModelOptionsState.ready,
          ),
          (
            'Loading models',
            RecipientSelectorState.ready,
            ModelOptionsState.loading,
          ),
          (
            'Model setup',
            RecipientSelectorState.ready,
            ModelOptionsState.incomplete,
          ),
          (
            'Model failure',
            RecipientSelectorState.ready,
            ModelOptionsState.failed,
          ),
          (
            'Legacy model default',
            RecipientSelectorState.ready,
            ModelOptionsState.unsupported,
          ),
          (
            'Both failed',
            RecipientSelectorState.failed,
            ModelOptionsState.failed,
          ),
        ])
          WidgetbookUseCase(
            name: label,
            builder: (_) => frame(
              _SelectorPairPreview(recipient: recipient, model: model),
              maxWidth: 720,
            ),
          ),
        WidgetbookUseCase(
          name: 'Large text, long labels',
          builder: (context) => frame(
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: const _SelectorPairPreview(
                recipient: RecipientSelectorState.ready,
                model: ModelOptionsState.ready,
              ),
            ),
            maxWidth: 720,
          ),
        ),
        WidgetbookUseCase(
          name: 'Large text, both failed',
          builder: (context) => frame(
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: const _SelectorPairPreview(
                recipient: RecipientSelectorState.failed,
                model: ModelOptionsState.failed,
              ),
            ),
            maxWidth: 720,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Profile avatar',
      useCases: [
        WidgetbookUseCase(
          name: 'Monogram sizes',
          builder: (_) => frame(_avatars()),
        ),
        WidgetbookUseCase(
          name: 'Configured image sizes',
          builder: (_) =>
              frame(_avatars(bytes: base64Decode(messengerAvatarPng))),
        ),
        WidgetbookUseCase(
          name: 'Failed image fallback',
          builder: (_) => frame(_avatars(bytes: Uint8List.fromList([1, 2, 3]))),
        ),
        WidgetbookUseCase(
          name: 'Group',
          builder: (_) => frame(const GroupAvatar(label: 'Project team')),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Recipient picker',
      useCases: [
        for (final state in [
          'Available',
          'Loading',
          'Empty',
          'Failed',
          'Large text',
        ])
          WidgetbookUseCase(
            name: state,
            builder: (context) {
              final picker = RecipientPicker(
                profiles: state == 'Empty' ? const [] : messengerRecipients,
                selectedProfile: 'writer',
                loading: state == 'Loading',
                failed: state == 'Failed',
                onSelected: (_) {},
                onRetry: () {},
                onSetup: () {},
              );
              return frame(
                state == 'Large text'
                    ? MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: const TextScaler.linear(2)),
                        child: picker,
                      )
                    : picker,
              );
            },
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'Recipient chip',
      useCases: [
        WidgetbookUseCase(
          name: 'Selected',
          builder: (_) => frame(
            ProfileRecipientChip(
              profile: messengerRecipients.first,
              onTap: () {},
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Long name',
          builder: (_) => frame(
            ProfileRecipientChip(
              profile: messengerRecipients.last,
              onTap: () {},
            ),
          ),
        ),
      ],
    ),
  ],
);

Widget _avatars({Uint8List? bytes}) => Wrap(
  spacing: 16,
  runSpacing: 16,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    for (final size in [24.0, 32.0, 40.0])
      ProfileAvatar(
        profile: messengerRecipients.first,
        size: size,
        imageBytes: bytes,
      ),
  ],
);

class _SelectorPairPreview extends StatefulWidget {
  const _SelectorPairPreview({required this.recipient, required this.model});

  final RecipientSelectorState recipient;
  final ModelOptionsState model;

  @override
  State<_SelectorPairPreview> createState() => _SelectorPairPreviewState();
}

class _SelectorPairPreviewState extends State<_SelectorPairPreview> {
  late RecipientSelectorState _recipient = widget.recipient;
  late ModelOptionsState _model = widget.model;
  late HermesProfile? _profile =
      _recipient == RecipientSelectorState.choose ||
          _recipient == RecipientSelectorState.empty
      ? null
      : messengerRecipients.last;
  ModelChoice _choice = ModelChoice(
    modelOptions.providers.last.id,
    modelOptions.providers.last.models.last.id,
  );

  Future<void> _chooseRecipient() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
        child: RecipientPicker(
          profiles: messengerRecipients,
          selectedProfile: _profile?.name,
          onSelected: (profile) {
            setState(() {
              _profile = profile;
              _recipient = RecipientSelectorState.ready;
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Flexible(
        child: ProfileRecipientChip(
          profile: _profile,
          state: _recipient,
          onTap: _chooseRecipient,
          onRetry: () =>
              setState(() => _recipient = RecipientSelectorState.ready),
          onSetup: () => setState(() {
            _profile = messengerRecipients.last;
            _recipient = RecipientSelectorState.ready;
          }),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: ComposerModelPill(
          options: _model == ModelOptionsState.incomplete
              ? const ModelOptions()
              : modelOptions,
          choice: _model == ModelOptionsState.ready ? _choice : null,
          state: _model,
          onChanged: (choice) => setState(() => _choice = choice),
          onRetry: () => setState(() => _model = ModelOptionsState.ready),
          onSetup: () => setState(() => _model = ModelOptionsState.ready),
        ),
      ),
    ],
  );
}
