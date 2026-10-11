import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

typedef NewProfile = ({String name, String description});

/// Asks for the name and an optional description of a new profile; null
/// when cancelled.
Future<NewProfile?> showNewProfileDialog(BuildContext context) =>
    showDialog<NewProfile>(
      context: context,
      barrierDismissible: !platformChromeOf(context).isApple,
      builder: (_) => const _NewProfileDialog(),
    );

/// Hermes names a profile like a directory: letters, digits, `-` and `_`.
final _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');

class _NewProfileDialog extends StatefulWidget {
  const _NewProfileDialog();

  @override
  State<_NewProfileDialog> createState() => _NewProfileDialogState();
}

class _NewProfileDialogState extends State<_NewProfileDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _valid => _validName.hasMatch(_name.text.trim());

  void _save() {
    if (!_valid) return;
    Navigator.of(context)
        .pop((name: _name.text.trim(), description: _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return GroupedDialog(
      title: 'New Profile',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _valid ? _save : null,
            child: const Text('Create'),
          ),
        ),
      ],
      children: [
        GroupedSection(
          footer: 'Use letters, numbers, hyphens, or underscores. Start with a letter or number.',
          children: [
            GroupedTextFieldRow(
              key: const Key('new-profile-name'),
              label: 'Name',
              hint: 'writer',
              controller: _name,
              autofocus: true,
              autocorrect: false,
              onSubmitted: (_) => _save(),
            ),
            GroupedTextFieldRow(
              key: const Key('new-profile-description'),
              label: 'Description',
              hint: 'Optional',
              controller: _description,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks for a new profile's name and makes it with [create], saying why when
/// the dashboard refuses.
Future<void> createProfile(
  BuildContext context,
  Future<void> Function(String name, {String? description}) create,
) async {
  final created = await showNewProfileDialog(context);
  if (created == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await create(created.name, description: created.description);
  } on Object catch (error) {
    final detail = switch (error) {
      DioException(response: Response(data: {'detail': final String d})) =>
        ': $d',
      _ => '',
    };
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not create the profile$detail')),
    );
  }
}
