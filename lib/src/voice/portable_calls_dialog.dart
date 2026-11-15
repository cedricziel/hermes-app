import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../widgets/grouped_dialog.dart';
import 'calls/portable_call_settings.dart';
import 'widgets/portable_calls_section.dart';

Future<void> showPortableCallsDialog(BuildContext context) {
  final settings = context.read<PortableCallSettings>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: const _PortableCallsDialog(),
    ),
  );
}

class _PortableCallsDialog extends StatelessWidget {
  const _PortableCallsDialog();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<PortableCallSettings>();
    return GroupedDialog(
      title: context.l10n.settingsVoiceCalls,
      children: [
        PortableCallsSection(
          value: settings.enabled,
          onChanged: settings.setEnabled,
        ),
      ],
    );
  }
}
