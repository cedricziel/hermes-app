import 'package:flutter/material.dart';

/// Explains how to configure the selected profile on the connected server.
Future<void> showModelSetup(BuildContext context, String? profile) {
  final name = profile == null || profile.isEmpty ? 'default' : profile;
  final argument = RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(name)
      ? name
      : "'${name.replaceAll("'", "'\"'\"'")}'";
  final command = name == 'default'
      ? 'hermes model'
      : 'hermes -p $argument model';
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Set up a model'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure a provider and model for the $name profile on your '
            'Hermes server. Run this command on that server, then check again:',
          ),
          const SizedBox(height: 12),
          SelectableText(command),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('Check again'),
        ),
      ],
    ),
  );
}
