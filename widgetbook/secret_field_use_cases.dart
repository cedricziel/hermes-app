import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/secret_field_row.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _typed = 'sk-or-v1-0000-invented-key';

WidgetbookNode secretFieldNode() => WidgetbookFolder(
  name: 'Secret fields',
  children: [
    WidgetbookComponent(
      name: 'SecretFieldRow',
      useCases: [
        ...onEachPlatform(
          'Hidden',
          (_) =>
              const _SecretDemo(text: _typed, footer: 'Saved on your server.'),
        ),
        WidgetbookUseCase(name: 'Empty', builder: (_) => const _SecretDemo()),
        ...onEachPlatform(
          'Shown',
          (_) => const _SecretDemo(text: _typed, shown: true),
        ),
        WidgetbookUseCase(
          name: 'Hidden again on going inactive',
          builder: (_) => const _SecretDemo(
            text: _typed,
            shown: true,
            note:
                'Press the button: the app goes inactive, the key hides and '
                'the typed text stays.',
            goInactive: true,
          ),
        ),
        WidgetbookUseCase(
          name: 'After a failed save',
          builder: (_) => const _SecretDemo(
            text: _typed,
            error: "Couldn't save the key. Try again.",
          ),
        ),
        WidgetbookUseCase(
          name: 'After a lost answer (cleared)',
          builder: (_) => const _SecretDemo(
            note: 'May have saved. Paste the key again to be sure.',
          ),
        ),
        WidgetbookUseCase(
          name: 'Saving',
          builder: (_) => const _SecretDemo(text: _typed, busy: true),
        ),
        WidgetbookUseCase(
          name: 'One character',
          builder: (_) => const _SecretDemo(text: 'k'),
        ),
      ],
    ),
  ],
);

class _SecretDemo extends StatefulWidget {
  const _SecretDemo({
    this.text = '',
    this.shown = false,
    this.busy = false,
    this.error,
    this.note,
    this.footer,
    this.goInactive = false,
  });

  final String text;
  final bool shown;
  final bool busy;
  final String? error;
  final String? note;
  final String? footer;
  final bool goInactive;

  @override
  State<_SecretDemo> createState() => _SecretDemoState();
}

class _SecretDemoState extends State<_SecretDemo> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goInactive() {
    final binding = WidgetsBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => frame(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          footer: widget.footer,
          children: [
            SecretFieldRow(
              label: 'API key',
              hint: 'Paste your key',
              controller: _controller,
              busy: widget.busy,
              enabled: !widget.busy,
              initiallyShown: widget.shown,
              errorText: widget.error,
            ),
          ],
        ),
        if (widget.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(widget.note!),
          ),
        if (widget.goInactive)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: _goInactive,
              child: const Text('Send the app to the background'),
            ),
          ),
      ],
    ),
  );
}
