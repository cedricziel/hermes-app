import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';

void main() {
  test('nested notification retirement clears details and disposes once', () {
    final scope = SideResultScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: 'work',
    );
    final state = SideResultState()..adopt(scope);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    var nested = false;
    state.addListener(() {
      if (!nested) {
        nested = true;
        state.notifyListeners();
      } else {
        state.dispose();
        state.dispose();
        expect(state.results, isEmpty);
        expect(state.hasScope(scope), isFalse);
      }
    });
    try {
      state.received(
        scope,
        SideResult.decode('background.complete', {
          'task_id': 'one',
          'text': 'Reported',
        })!,
      );
      state.dispose();
      state.notifyListeners();
      expect(errors, isEmpty);
    } finally {
      FlutterError.onError = previous;
      state.dispose();
    }
  });

  test(
    'side completions decode required identity and preserve empty answers',
    () {
      expect(
        SideResult.decode('background.complete', {
          'task_id': '',
          'text': 'Ignored',
        }),
        isNull,
      );
      expect(
        SideResult.decode('btw.complete', {'task_id': 'one', 'text': 42}),
        isNull,
      );
      final result = SideResult.decode('btw.complete', {
        'task_id': 'one',
        'text': '',
        'question': 'What changed?',
      })!;
      expect(result.kind, SideResultKind.btw);
      expect(result.text, isEmpty);
      expect(result.question, 'What changed?');
    },
  );

  test('side snapshots replace only the matching task and kind', () {
    final scope = SideResultScope(
      connection: Object(),
      sessionId: 'runtime',
      profile: 'work',
    );
    final state = SideResultState()..adopt(scope);
    addTearDown(state.dispose);
    state.received(
      scope,
      SideResult.decode('background.complete', {
        'task_id': 'one',
        'text': 'First',
      })!,
    );
    state.received(
      scope,
      SideResult.decode('btw.complete', {
        'task_id': 'one',
        'text': 'Separate',
      })!,
    );
    state.received(
      scope,
      SideResult.decode('background.complete', {
        'task_id': 'one',
        'text': 'Replacement',
      })!,
    );
    expect(state.results.map((result) => result.text), [
      'Replacement',
      'Separate',
    ]);
  });

  test('side result ownership rejects another session and clears connection replacement', () {
    final connection = Object();
    final scope = SideResultScope(
      connection: connection,
      sessionId: 'one',
      profile: 'work',
    );
    final other = SideResultScope(
      connection: connection,
      sessionId: 'two',
      profile: 'work',
    );
    final state = SideResultState()..adopt(scope);
    addTearDown(state.dispose);
    final result = SideResult.decode('background.complete', {
      'task_id': 'one',
      'text': 'Result',
    })!;
    state.received(other, result);
    expect(state.results, isEmpty);
    state.received(scope, result);
    state.adopt(
      SideResultScope(connection: Object(), sessionId: 'one', profile: 'work'),
    );
    expect(state.results, isEmpty);
  });

  test('side results log fixed outcomes without answer or task identity', () {
    final seen = <Map<String, Object>>[];
    final scope = SideResultScope(
      connection: Object(),
      sessionId: 'private-id',
      profile: 'private-profile',
    );
    final state = SideResultState(
      events: (name, [attributes = const {}]) {
        seen.add(Map.from(attributes));
        throw StateError('Telemetry unavailable');
      },
    )..adopt(scope);
    addTearDown(state.dispose);
    expect(
      state.received(
        scope,
        SideResult.decode('btw.complete', {
          'task_id': 'private-task',
          'text': 'Private answer',
          'question': 'Private question',
        })!,
      ),
      isTrue,
    );
    expect(seen, [
      {'feature': 'side_results', 'outcome': 'applied', 'count': 1},
    ]);
  });
}
