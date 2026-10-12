import 'package:hermes_app/src/chat/widgets/chat_suggestions.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode chatSuggestionsNode() => WidgetbookComponent(
  name: 'ChatSuggestions',
  useCases: [
    ...onEachPlatform(
      'Teammates',
      (_) => frame(
        ChatSuggestions(
          header: 'Mention a teammate',
          maxHeight: 180,
          items: const [
            ChatSuggestion('@writer', 'Writer'),
            ChatSuggestion('@research', 'Research specialist'),
          ],
          onChoose: (_) {},
        ),
      ),
    ),
    ...onEachPlatform(
      'Commands',
      (_) => frame(
        ChatSuggestions(
          selectedIndex: 1,
          items: const [
            ChatSuggestion('/help', 'Show command help'),
            ChatSuggestion('/model', 'Change the model'),
          ],
          onChoose: (_) {},
        ),
      ),
    ),
    ...onEachPlatform(
      'Long list',
      (_) => frame(
        ChatSuggestions(
          selectedIndex: 0,
          items: List.generate(
            8,
            (i) => ChatSuggestion(
              '/command$i',
              'A longer command description that remains readable in a narrow suggestion panel',
            ),
          ),
          onChoose: (_) {},
        ),
      ),
    ),
  ],
);
