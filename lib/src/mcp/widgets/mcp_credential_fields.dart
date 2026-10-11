import 'package:flutter/material.dart';

import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../hermes_mcp_repository.dart';

class McpCredentialFields extends StatelessWidget {
  const McpCredentialFields({
    super.key,
    required this.credentials,
    required this.controllers,
    this.busy = false,
  });

  final List<HermesMcpCredential> credentials;
  final Map<String, TextEditingController> controllers;
  final bool busy;

  @override
  Widget build(BuildContext context) => GroupedSection(
    header: 'Credentials',
    footer: 'Saved on your Hermes server. It is never shown again.',
    children: [
      for (final credential in credentials)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupedTextFieldRow(
              label: credential.name,
              controller: controllers[credential.name],
              obscureText: true,
              readOnly: busy,
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
            ),
            GroupedFooter(
              credential.required
                  ? credential.prompt
                  : '${credential.prompt} (optional)',
            ),
          ],
        ),
    ],
  );
}
