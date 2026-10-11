import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/grouped_dialog.dart';
import 'spotlight_settings.dart';
import 'widgets/spotlight_settings_view.dart';

Future<void> showSpotlightDialog(BuildContext context) {
  final settings = context.read<SpotlightSettings>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: const _SpotlightDialog(),
    ),
  );
}

class _SpotlightDialog extends StatelessWidget {
  const _SpotlightDialog();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SpotlightSettings>();
    return GroupedDialog(
      title: 'Spotlight',
      children: [
        SpotlightSettingsView(
          enabled: settings.enabled,
          onChanged: settings.setEnabled,
        ),
      ],
    );
  }
}
