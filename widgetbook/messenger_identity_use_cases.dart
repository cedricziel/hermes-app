import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookNode messengerIdentityNode() => WidgetbookFolder(
  name: 'Messenger identity',
  children: [
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
