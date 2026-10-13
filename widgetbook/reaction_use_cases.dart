import 'package:hermes_app/src/chat/reactions/reaction_cards.dart';
import 'package:hermes_app/src/chat/reactions/reaction_state.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _reactions = [ReportedReaction(emoji: '👍', author: 'agent', seen: true)];
WidgetbookNode reactionNode() => WidgetbookComponent(
  name: 'Reported reactions',
  useCases: [
    for (final open in [false, true])
      WidgetbookUseCase(
        name: 'Message ${open ? 'expanded' : 'compact'}',
        builder: (_) => frame(
          MessageReactionCard(reactions: _reactions, initiallyOpen: open),
        ),
      ),
    WidgetbookUseCase(
      name: 'Empty',
      builder: (_) => frame(const MessageReactionCard(reactions: [])),
    ),
    WidgetbookUseCase(
      name: 'Unavailable',
      builder: (_) => frame(const MessageReactionCard(reactions: null)),
    ),
    WidgetbookUseCase(
      name: 'Session acknowledgement',
      builder: (_) => frame(
        const SessionAcknowledgementCard(
          acknowledgement: SessionAcknowledgement.vibe,
          initiallyOpen: true,
        ),
      ),
    ),
  ],
);
