import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/reactions/reaction_state.dart';
import 'package:hermes_app/src/chat/reactions/reaction_cards.dart';

import 'support/accessibility.dart';

void main() {
  testWidgets(
    'durable reaction card exposes supplied emoji and author without edit actions',
    (tester) async {
      final snapshot = MessageReactionSnapshot.decode({
        'row_id': 21,
        'role': 'user',
        'reactions': [
          {'emoji': '👍', 'author': 'agent', 'seen': true},
        ],
      })!;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageReactionCard(reactions: snapshot.reactions),
          ),
        ),
      );
      expect(find.text('👍 · agent'), findsOneWidget);
      await tester.tap(find.text('Message reactions'));
      await tester.pumpAndSettle();
      expect(find.text('Author: agent'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(
        tester.getSemantics(find.text('Message reactions')),
        disclosure('Message reactions', open: true),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'identity-free acknowledgement stays neutral without inferred emoji',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionAcknowledgementCard(
              acknowledgement: SessionAcknowledgement.vibe,
              initiallyOpen: true,
            ),
          ),
        ),
      );
      expect(find.text('Session acknowledgement'), findsOneWidget);
      expect(
        find.text('An acknowledgement was reported for this session.'),
        findsOneWidget,
      );
      expect(find.text('❤️'), findsNothing);
    },
  );

  testWidgets(
    'empty reactions disappear and unavailable details remain neutral',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MessageReactionCard(reactions: [])),
        ),
      );
      expect(find.byType(Text), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MessageReactionCard(reactions: null)),
        ),
      );
      expect(find.text('Reaction details unavailable'), findsOneWidget);
    },
  );
}
