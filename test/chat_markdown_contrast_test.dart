import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hermes_app/src/chat/widgets/chat_text_message.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/markdown_contrast.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('chat message headings and links are readable in '
        '${dark ? 'dark' : 'light'}', (tester) async {
      final theme = dark ? buildHermesDarkTheme() : buildHermesLightTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Provider<ChatTheme>.value(
              value: dark ? ChatTheme.dark() : ChatTheme.light(),
              child: ChatTextMessage(
                message: const TextMessage(
                  id: '1',
                  authorId: 'a',
                  text: '# Heading\n\nSee [the docs](https://example.com).',
                ),
                isSentByMe: false,
                textStyle: TextStyle(color: theme.colorScheme.onSurface),
                backgroundColor: Colors.transparent,
                borderRadius: BorderRadius.zero,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      expectReadableOnSurface(tester, ['Heading', 'the docs']);
    });
  }
}
