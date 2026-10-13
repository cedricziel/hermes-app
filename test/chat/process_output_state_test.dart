import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';

void main() {
  test('interleaved output stays within process and attachment', () {
    final state = ProcessOutputState();
    final attachment = Object();
    state.adopt(attachment);
    state.apply(
      const ProcessOutputUpdate('one', chunk: 'first'),
      attachment: attachment,
    );
    state.apply(
      const ProcessOutputUpdate('two', chunk: 'other'),
      attachment: attachment,
    );
    state.apply(
      const ProcessOutputUpdate('one', chunk: ' second'),
      attachment: attachment,
    );
    expect(state.cards.map((card) => card.text), ['first second', 'other']);
    expect(
      state.apply(
        const ProcessOutputUpdate('one', chunk: 'stale'),
        attachment: Object(),
      ),
      ProcessOutputOutcome.stale,
    );
    state.adopt(Object());
    expect(state.cards, isEmpty);
  });
  test('UTF8 tail stays bounded without broken multi-byte characters', () {
    final state = ProcessOutputState();
    final attachment = Object();
    state.adopt(attachment);
    state.apply(
      ProcessOutputUpdate('one', chunk: '${'😀' * 18000}tail!'),
      attachment: attachment,
    );
    final card = state.cards.single;
    expect(utf8.encode(card.text).length, lessThanOrEqualTo(64 * 1024));
    expect(card.text, endsWith('tail!'));
    expect(card.text, isNot(contains('\uFFFD')));
    expect(card.omitted, isTrue);
  });
  test('eviction prefers closed cards and discloses omission', () {
    final state = ProcessOutputState();
    final attachment = Object();
    state.adopt(attachment);
    for (var index = 0; index < 16; index++) {
      state.apply(
        ProcessOutputUpdate('$index', chunk: '$index'),
        attachment: attachment,
      );
    }
    state.apply(
      const ProcessOutputUpdate('7', closed: true),
      attachment: attachment,
    );
    state.apply(
      const ProcessOutputUpdate('next', chunk: 'new'),
      attachment: attachment,
    );
    expect(state.cards, hasLength(16));
    expect(state.cards.any((card) => card.processId == '7'), isFalse);
    expect(state.cards.any((card) => card.processId == '0'), isTrue);
    expect(state.omittedCards, isTrue);
    state.apply(
      const ProcessOutputUpdate('active', chunk: 'new'),
      attachment: attachment,
    );
    expect(state.cards.any((card) => card.processId == '0'), isFalse);
  });
  test('close before output stays closed without inventing exit results', () {
    final state = ProcessOutputState();
    final attachment = Object();
    state.adopt(attachment);
    state.apply(
      const ProcessOutputUpdate('one', closed: true),
      attachment: attachment,
    );
    expect(state.cards.single.closed, isTrue);
    expect(state.cards.single.text, isEmpty);
    state.apply(
      const ProcessOutputUpdate('one', chunk: 'late'),
      attachment: attachment,
    );
    expect(state.cards.single.closed, isTrue);
    expect(state.cards.single.text, 'late');
    state.clear();
    expect(state.cards, isEmpty);
  });
  test('optional decoding refuses missing identity or malformed chunks', () {
    expect(
      ProcessOutputUpdate.decode('agent.terminal.output', {'chunk': 'x'}),
      isNull,
    );
    expect(
      ProcessOutputUpdate.decode('agent.terminal.output', {
        'process_id': 'x',
        'chunk': 3,
      }),
      isNull,
    );
    expect(
      ProcessOutputUpdate.decode('terminal.close', {'process_id': 'x'})!.closed,
      isTrue,
    );
  });
}
