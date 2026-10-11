import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/named_icon_button.dart';
import '../hermes_mcp_repository.dart';

class McpEnvironmentField {
  const McpEnvironmentField({
    required this.name,
    required this.value,
    required this.onRemove,
    this.error,
  });
  final TextEditingController name;
  final TextEditingController value;
  final VoidCallback onRemove;
  final String? error;
}

class McpServerFields extends StatelessWidget {
  const McpServerFields({
    super.key,
    required this.name,
    required this.url,
    required this.token,
    required this.command,
    required this.args,
    required this.remote,
    required this.auth,
    required this.saving,
    required this.onRemoteChanged,
    required this.onAuthChanged,
    required this.onNameChanged,
    required this.onSubmit,
    required this.onAddVariable,
    required this.environment,
    this.nameError,
    this.urlError,
  });
  final TextEditingController name, url, token, command, args;
  final bool remote, saving;
  final McpRemoteAuth auth;
  final ValueChanged<bool> onRemoteChanged;
  final ValueChanged<McpRemoteAuth> onAuthChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSubmit, onAddVariable;
  final List<McpEnvironmentField> environment;
  final String? nameError, urlError;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupedSection(
        children: [
          AbsorbPointer(
            absorbing: saving,
            child: GroupedSegmentedRow<bool>(
              value: remote,
              segments: const {true: 'Remote (URL)', false: 'Command'},
              onChanged: (choice) {
                if (!saving) onRemoteChanged(choice);
              },
            ),
          ),
        ],
      ),
      _field(name, 'Name', errorText: nameError, onChanged: onNameChanged),
      if (remote)
        ..._remoteFields(Theme.of(context))
      else
        ..._commandFields(Theme.of(context)),
    ],
  );

  /// A text field of the form. Every field is read-only while saving. A
  /// secret is obscured and kept out of the keyboard's learning, and Enter in
  /// any field that submits goes through the same [onSubmit], review included.
  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? errorText,
    int? errorMaxLines,
    TextInputType? keyboardType,
    bool secret = false,
    bool mono = false,
    bool multiline = false,
    bool submits = true,
    bool next = false,
    ValueChanged<String>? onChanged,
  }) {
    return GroupedSection(
      header: multiline ? label : null,
      children: [
        GroupedTextFieldRow(
          label: label,
          hint: hint,
          controller: controller,
          readOnly: saving,
          obscureText: secret,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: !secret,
          keyboardType: multiline ? TextInputType.multiline : keyboardType,
          minLines: multiline ? 3 : null,
          maxLines: multiline ? 8 : 1,
          textInputAction: multiline
              ? null
              : next
              ? TextInputAction.next
              : TextInputAction.done,
          onChanged: onChanged,
          onSubmitted: submits ? (_) => onSubmit() : null,
          monospace: mono,
          errorText: errorText,
          errorMaxLines: errorMaxLines,
        ),
      ],
    );
  }

  List<Widget> _remoteFields(ThemeData theme) {
    return [
      _field(
        url,
        'URL',
        hint: 'https://mcp.example.com/mcp',
        keyboardType: TextInputType.url,
        errorText: urlError,
      ),
      const SizedBox(height: 16),
      Text('Authentication', style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      GroupedSection(
        children: [
          AbsorbPointer(
            absorbing: saving,
            child: GroupedSegmentedRow<McpRemoteAuth>(
              value: auth,
              segments: const {
                McpRemoteAuth.none: 'None',
                McpRemoteAuth.bearerToken: 'Bearer token',
                McpRemoteAuth.oauth: 'OAuth',
              },
              onChanged: (choice) {
                if (!saving) onAuthChanged(choice);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (auth == McpRemoteAuth.oauth)
        Text(
          "After adding, you sign in from the server's page.",
          style: theme.textTheme.bodySmall,
        ),
      if (auth == McpRemoteAuth.bearerToken) ...[
        _field(token, 'Bearer token', secret: true),
        const SizedBox(height: 4),
        Text(
          'Kept on your Hermes server. It is never shown again.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    ];
  }

  List<Widget> _commandFields(ThemeData theme) {
    return [
      _field(command, 'Command', hint: 'npx', mono: true),
      const SizedBox(height: 12),
      _field(
        args,
        'Arguments (one per line)',
        mono: true,
        multiline: true,
        submits: false,
      ),
      const SizedBox(height: 16),
      Text('Environment variables', style: theme.textTheme.labelLarge),
      for (final row in environment)
        Padding(
          key: ObjectKey(row.name),
          padding: const EdgeInsets.only(top: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final nameField = _field(
                row.name,
                'Variable name',
                mono: true,
                submits: false,
                next: true,
                errorText: row.error,
                errorMaxLines: 2,
              );
              final valueField = _field(row.value, 'Value', secret: true);
              final remove = NamedIconButton(
                label: 'Remove variable',
                icon: AppIcons.close,
                onPressed: saving ? null : row.onRemove,
              );
              if (constraints.maxWidth < 480) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: nameField),
                        remove,
                      ],
                    ),
                    valueField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nameField),
                  const SizedBox(width: 8),
                  Expanded(child: valueField),
                  remove,
                ],
              );
            },
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: saving ? null : onAddVariable,
          icon: const AppIcon(AppIcons.add),
          label: const Text('Add variable'),
        ),
      ),
      Text(
        'Values are sent to your Hermes server once and never shown again.',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }
}
