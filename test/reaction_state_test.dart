import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/reactions/reaction_state.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/gateway/reactions.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test(
    'identity-free supported kind comes from the pinned detector fixture',
    () {
      expect(fixture['source_ref'], '167e9fdb84248cd0fff80762dc57b6a914b6e930');
      expect(
        SessionAcknowledgement.decode(fixture['reaction']),
        SessionAcknowledgement.vibe,
      );
      expect(SessionAcknowledgement.decode({'kind': 'future'}), isNull);
    },
  );

  test(
    'reaction snapshots attach only after exact durable row identity loads',
    () {
      final scope = ReactionScope(
        connection: Object(),
        lineage: Object(),
        profile: 'work',
      );
      final state = ReactionState()..adopt(scope);
      addTearDown(state.dispose);
      final update = MessageReactionSnapshot.decode(
        fixture['message_reaction'],
      )!;
      state.received(scope, update);
      expect(state.reactionsFor(scope, 21), isNull);
      state.historyLoaded(scope, [
        DurableReactionRow.decode({'row_id': 22, 'role': 'user'})!,
      ]);
      expect(state.reactionsFor(scope, 22), isEmpty);
      state.historyLoaded(scope, [
        DurableReactionRow.decode(fixture['transcript_row'])!,
      ]);
      expect(state.reactionsFor(scope, 21)!.single.emoji, '👍');
    },
  );

  test('reported reaction snapshots replace lists and empty clears badges', () {
    final scope = ReactionScope(
      connection: Object(),
      lineage: Object(),
      profile: 'work',
    );
    final state = ReactionState()..adopt(scope);
    addTearDown(state.dispose);
    state.historyLoaded(scope, [
      DurableReactionRow.decode({'row_id': 21, 'role': 'user'})!,
    ]);
    final update = MessageReactionSnapshot.decode(fixture['message_reaction'])!;
    state.received(scope, update);
    state.received(scope, update);
    expect(state.reactionsFor(scope, 21), hasLength(1));
    state.received(
      scope,
      MessageReactionSnapshot.decode({
        'row_id': 21,
        'role': 'user',
        'reactions': [],
      })!,
    );
    expect(state.reactionsFor(scope, 21), isEmpty);
  });

  test('identity-free acknowledgements never attach badges to any row', () {
    final scope = ReactionScope(
      connection: Object(),
      lineage: Object(),
      profile: 'work',
    );
    final state = ReactionState()..adopt(scope);
    addTearDown(state.dispose);
    state.historyLoaded(scope, [
      DurableReactionRow.decode({'row_id': 21, 'role': 'user'})!,
      DurableReactionRow.decode({'row_id': 22, 'role': 'user'})!,
    ]);
    state.signal(scope, SessionAcknowledgement.vibe);
    expect(state.acknowledgement, SessionAcknowledgement.vibe);
    expect(state.reactionsFor(scope, 21), isEmpty);
    expect(state.reactionsFor(scope, 22), isEmpty);
  });

  test('profile and stored-session lineage isolate durable IDs', () {
    final connection = Object(), lineage = Object();
    final scope = ReactionScope(
      connection: connection,
      lineage: lineage,
      profile: 'work',
    );
    final otherProfile = ReactionScope(
      connection: connection,
      lineage: lineage,
      profile: 'other',
    );
    final otherLineage = ReactionScope(
      connection: connection,
      lineage: Object(),
      profile: 'work',
    );
    final state = ReactionState()..adopt(scope);
    addTearDown(state.dispose);
    state.historyLoaded(scope, [
      DurableReactionRow.decode({'row_id': 21, 'role': 'user'})!,
    ]);
    final update = MessageReactionSnapshot.decode(fixture['message_reaction'])!;
    state.received(otherProfile, update);
    state.received(otherLineage, update);
    expect(state.reactionsFor(scope, 21), isEmpty);
  });

  test('new live snapshots override older history metadata and pending storage is bounded', () {
    final scope = ReactionScope(
      connection: Object(),
      lineage: Object(),
      profile: 'work',
    );
    final state = ReactionState(maxPending: 1)..adopt(scope);
    addTearDown(state.dispose);
    state.received(
      scope,
      MessageReactionSnapshot.decode({
        'row_id': 21,
        'role': 'user',
        'reactions': [
          {'emoji': '👍', 'author': 'agent'},
        ],
      })!,
    );
    state.received(
      scope,
      MessageReactionSnapshot.decode({
        'row_id': 22,
        'role': 'user',
        'reactions': [
          {'emoji': '🎉', 'author': 'agent'},
        ],
      })!,
    );
    expect(state.pendingCount, 1);
    state.historyLoaded(scope, [
      DurableReactionRow.decode({'row_id': 21, 'role': 'user'})!,
      DurableReactionRow.decode({
        'row_id': 22,
        'role': 'user',
        'display_metadata': {
          'reactions': [
            {'emoji': '👎', 'author': 'agent'},
          ],
        },
      })!,
    ]);
    expect(state.reactionsFor(scope, 21), isEmpty);
    expect(state.reactionsFor(scope, 22)!.single.emoji, '🎉');
  });

  test('role cannot replace durable identity or redirect an existing row', () {
    expect(
      DurableReactionRow.decode({'role': 'user', 'text': 'No durable ID'}),
      isNull,
    );
    final scope = ReactionScope(
      connection: Object(),
      lineage: Object(),
      profile: 'work',
    );
    final state = ReactionState()..adopt(scope);
    addTearDown(state.dispose);
    state.historyLoaded(scope, [
      DurableReactionRow.decode({'row_id': 21, 'role': 'user'})!,
    ]);
    state.received(
      scope,
      MessageReactionSnapshot.decode({
        'row_id': 21,
        'role': 'assistant',
        'reactions': [
          {'emoji': '👍', 'author': 'agent'},
        ],
      })!,
    );
    expect(state.reactionsFor(scope, 21), isEmpty);
  });

  test(
    'reaction row identity rejects aliases and malformed full snapshots',
    () {
      expect(DurableReactionRow.decode({'id': 21, 'role': 'user'}), isNull);
      expect(
        DurableReactionRow.decode({'_row_id': 21, 'role': 'user'}),
        isNull,
      );
      expect(
        MessageReactionSnapshot.decode({
          'row_id': '21',
          'role': 'user',
          'reactions': [],
        }),
        isNull,
      );
      expect(
        MessageReactionSnapshot.decode({
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': '👍'},
          ],
        }),
        isNull,
      );
    },
  );

  test(
    'a role hint cannot redirect an unknown durable ID to another message',
    () {
      final scope = ReactionScope(
        connection: Object(),
        lineage: Object(),
        profile: 'work',
      );
      final state = ReactionState()..adopt(scope);
      addTearDown(state.dispose);
      state.historyLoaded(scope, [
        DurableReactionRow.decode({'row_id': 21, 'role': 'assistant'})!,
      ]);
      state.received(
        scope,
        MessageReactionSnapshot.decode({
          'row_id': 99,
          'role': 'assistant',
          'reactions': [
            {'emoji': '👍', 'author': 'agent'},
          ],
        })!,
      );
      expect(state.reactionsFor(scope, 21), isEmpty);
      expect(state.pendingCount, 1);
    },
  );

  test('cold start restores only verified transcript reaction metadata', () {
    final scope = ReactionScope(
      connection: Object(),
      lineage: Object(),
      profile: 'work',
    );
    final state = ReactionState()..adopt(scope);
    addTearDown(state.dispose);
    state.historyLoaded(scope, [
      DurableReactionRow.decode(fixture['transcript_row'])!,
    ]);
    expect(state.reactionsFor(scope, 21)!.single.author, 'agent');
    state.adopt(
      ReactionScope(connection: Object(), lineage: Object(), profile: 'work'),
    );
    expect(state.reactionsFor(scope, 21), isNull);
    expect(state.acknowledgement, isNull);
  });

  test(
    'reaction logs exclude emoji, author, durable identity and timestamp',
    () {
      final seen = <Map<String, Object>>[];
      final scope = ReactionScope(
        connection: Object(),
        lineage: Object(),
        profile: 'private-profile',
      );
      final state = ReactionState(
        events: (name, [attributes = const {}]) {
          seen.add(Map.from(attributes));
          throw StateError('Telemetry unavailable');
        },
      )..adopt(scope);
      addTearDown(state.dispose);
      state.historyLoaded(scope, [
        DurableReactionRow.decode({'row_id': 21, 'role': 'user'})!,
      ]);
      expect(
        state.received(
          scope,
          MessageReactionSnapshot.decode(fixture['message_reaction'])!,
        ),
        isTrue,
      );
      expect(seen, [
        {'feature': 'reactions', 'outcome': 'applied', 'count': 1},
      ]);
    },
  );
  test(
    'conflicting history role cannot inherit a live badge from the prior role',
    () {
      final scope = ReactionScope(
        connection: Object(),
        lineage: Object(),
        profile: 'work',
      );
      final state = ReactionState()..adopt(scope);
      addTearDown(state.dispose);
      state.historyLoaded(scope, [
        const DurableReactionRow(rowId: 21, role: 'user'),
      ]);
      state.received(
        scope,
        MessageReactionSnapshot.decode({
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': '👍', 'author': 'agent'},
          ],
        })!,
      );
      state.historyLoaded(scope, [
        const DurableReactionRow(rowId: 21, role: 'assistant'),
      ]);
      expect(state.reactionsFor(scope, 21, role: 'assistant'), isNull);
    },
  );
  test('unverified future transcript role cannot become canonical reaction identity', () {
    expect(
      DurableReactionRow.decode({
        'row_id': 21,
        'role': 'future-role',
        'display_metadata': {'reactions': []},
      }),
      isNull,
    );
  });

  test('unverified future reaction role remains optional and cannot queue a guessed row', () {
    expect(
      MessageReactionSnapshot.decode({
        'row_id': 21,
        'role': 'future-role',
        'reactions': [],
      }),
      isNull,
    );
  });
}
