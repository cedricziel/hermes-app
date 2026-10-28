import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_screen/widgets/sudo_password_prompt.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// The question as the platform draws it, over a muted page, with the field
/// empty or holding an invented password.
class _Prompt extends StatefulWidget {
  const _Prompt({this.typed = ''});

  final String typed;

  @override
  State<_Prompt> createState() => _PromptState();
}

class _PromptState extends State<_Prompt> {
  late final _controller = TextEditingController(text: widget.typed);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black26,
    child: Center(
      child: SingleChildScrollView(
        child: SudoPasswordPrompt(
          host: 'hermes.example.com',
          controller: _controller,
          onInstall: (_) {},
          onCancel: () {},
        ),
      ),
    ),
  );
}

WidgetbookNode sudoPasswordPromptNode() => WidgetbookComponent(
  name: 'Sudo password prompt',
  useCases: [
    ...onEachPlatform('Empty', (_) => const _Prompt()),
    ...onEachPlatform(
      'Typed',
      (_) => const _Prompt(typed: 'correct horse battery'),
    ),
  ],
);
