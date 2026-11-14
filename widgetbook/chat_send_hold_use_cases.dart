import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/composer_status_line.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// Invented text; nothing here comes from a server.
const _draft = 'Split the token refresh out';

Widget _scaled(BuildContext context, double scale, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
  child: child,
);

Widget _still(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child,
);

WidgetbookUseCase _composer(
  String name, {
  String text = '',
  bool sendHeld = false,
  bool handedBack = false,
  double scale = 1,
}) => WidgetbookUseCase(
  name: name,
  builder: (context) => _scaled(
    context,
    scale,
    frame(
      _Composer(
        key: ValueKey(name),
        text: text,
        sendHeld: sendHeld,
        handedBack: handedBack,
      ),
      maxWidth: 760,
    ),
  ),
);

/// The composer while a full restore holds Send, and after it put the last
/// message back.
WidgetbookFolder chatSendHoldNode() => WidgetbookFolder(
  name: 'Chat send hold',
  children: [
    WidgetbookComponent(
      name: 'ComposerStatusLine',
      useCases: [
        WidgetbookUseCase(
          name: 'Restoring files',
          builder: (context) => frame(
            ComposerStatusLine(
              text: context.l10n.chatComposerHoldRestoring,
              busy: true,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Restoring files, reduced motion',
          builder: (context) => _still(
            context,
            frame(
              ComposerStatusLine(
                text: context.l10n.chatComposerHoldRestoring,
                busy: true,
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Last message handed back',
          builder: (context) => frame(
            ComposerStatusLine(
              text: context.l10n.chatComposerHoldHandedBack,
              icon: AppIcons.undo,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, handed back',
          builder: (context) => _scaled(
            context,
            3,
            frame(
              ComposerStatusLine(
                text: context.l10n.chatComposerHoldHandedBack,
                icon: AppIcons.undo,
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ChatComposer',
      useCases: [
        _composer('Send held, empty', sendHeld: true),
        _composer('Send held, typing', text: 'Next step', sendHeld: true),
        _composer('Last message handed back', text: _draft, handedBack: true),
        _composer(
          'Largest text, send held',
          text: 'Next step',
          sendHeld: true,
          scale: 3,
        ),
        _composer(
          'Largest text, handed back',
          text: _draft,
          handedBack: true,
          scale: 3,
        ),
      ],
    ),
  ],
);

class _Composer extends StatefulWidget {
  const _Composer({
    super.key,
    required this.text,
    required this.sendHeld,
    required this.handedBack,
  });

  final String text;
  final bool sendHeld;
  final bool handedBack;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatComposer(
    controller: _text,
    onSend: (_) => _text.clear(),
    onAttach: () {},
    onRemoveAttachment: (_) {},
    sendHeld: widget.sendHeld,
    draftHandedBack: widget.handedBack,
  );
}
