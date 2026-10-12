import 'package:flutter/material.dart';

import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

class ConnectionSetupField extends StatelessWidget {
  const ConnectionSetupField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.error,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String? error;

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      GroupedTextFieldRow(
        label: 'Dashboard URL',
        hint: 'http://192.168.1.20:9119',
        controller: controller,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        errorText: error,
        onSubmitted: onSubmitted,
      ),
    ],
  );
}
