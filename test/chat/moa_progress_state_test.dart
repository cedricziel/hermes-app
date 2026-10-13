import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/moa_progress_state.dart';

void main() {
  test('reported counts and aggregator never become inferred failures', () {
    final state = MoaProgressState();
    final attachment = Object(), turn = Object();
    state.adopt(attachment);
    state.apply(
      MoaUpdate.decode('moa.progress', {
        'label': 'Advisors',
        'refs_done': 1,
        'refs_total': 3,
      })!,
      attachment: attachment,
      turn: turn,
      eventIdentity: '1',
    );
    expect(state.cards.single.done, 1);
    expect(state.cards.single.total, 3);
    state.apply(
      MoaUpdate.decode('moa.phase', {
        'phase': 'aggregating',
        'refs_done': 5,
        'refs_total': 3,
        'aggregator': 'Model A',
      })!,
      attachment: attachment,
      turn: turn,
      eventIdentity: '2',
    );
    expect(state.cards.single.done, isNull);
    expect(state.cards.single.total, isNull);
    expect(state.cards.single.aggregator, 'Model A');
  });
  test('same labels without indices retain distinct references and deduplicate identity', () {
    final state = MoaProgressState();
    final attachment = Object(), turn = Object();
    state.adopt(attachment);
    final first = MoaUpdate.decode('moa.reference', {
      'label': 'Same',
      'text': 'first',
    })!;
    final second = MoaUpdate.decode('moa.reference', {
      'label': 'Same',
      'text': 'second',
    })!;
    state.apply(first, attachment: attachment, turn: turn, eventIdentity: '1');
    state.apply(second, attachment: attachment, turn: turn, eventIdentity: '2');
    state.apply(first, attachment: attachment, turn: turn, eventIdentity: '1');
    expect(state.cards.single.references.map((ref) => ref.text), [
      'first',
      'second',
    ]);
  });
  test(
    'indexed reference updates stay within their turn and settle keeps details',
    () {
      final state = MoaProgressState();
      final attachment = Object(), turn = Object(), next = Object();
      state.adopt(attachment);
      final first = MoaUpdate.decode('moa.reference', {
        'label': 'Advisor',
        'text': 'first',
        'index': 0,
      })!;
      final update = MoaUpdate.decode('moa.reference', {
        'label': 'Advisor',
        'text': 'updated',
        'index': 0,
      })!;
      state.apply(
        first,
        attachment: attachment,
        turn: turn,
        eventIdentity: '1',
      );
      state.apply(
        update,
        attachment: attachment,
        turn: turn,
        eventIdentity: '2',
      );
      state.apply(
        first,
        attachment: attachment,
        turn: turn,
        eventIdentity: '1',
      );
      state.finish(turn);
      state.apply(
        first,
        attachment: attachment,
        turn: next,
        eventIdentity: '3',
      );
      expect(state.cards.first.live, isFalse);
      expect(state.cards.first.references.single.text, 'updated');
      expect(state.cards.last.references.single.text, 'first');
      state.invalidateReferences();
      expect(
        state.cards.every(
          (card) => !card.referencesAvailable && card.references.isEmpty,
        ),
        isTrue,
      );
    },
  );
  test('late reference cannot reopen a turn completed before its first advisor event', () {
    final state = MoaProgressState();
    final attachment = Object(), turn = Object();
    state.adopt(attachment);
    state.finish(turn);
    final reference = MoaUpdate.decode('moa.reference', {
      'label': 'Advisor',
      'text': 'Late reference',
    })!;
    state.apply(
      reference,
      attachment: attachment,
      turn: turn,
      eventIdentity: 'late',
    );
    expect(state.cards.single.live, isFalse);
    expect(state.cards.single.references.single.text, 'Late reference');
  });

  test('stale ownership and malformed optional payloads cannot alter current state', () {
    final state = MoaProgressState();
    final attachment = Object();
    state.adopt(attachment);
    final update = MoaUpdate.decode('moa.aggregating', {
      'aggregator': 'Reported',
    })!;
    expect(
      state.apply(
        update,
        attachment: Object(),
        turn: Object(),
        eventIdentity: '1',
      ),
      MoaOutcome.stale,
    );
    expect(state.cards, isEmpty);
    expect(
      MoaUpdate.decode('moa.reference', {'label': 'x', 'text': []}),
      isNull,
    );
    expect(MoaUpdate.decode('unknown', {}), isNull);
  });
}
