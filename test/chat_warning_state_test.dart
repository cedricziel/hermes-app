import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';

void main() {
  test('keyed replacements withdraw only that notice', () {
    final state = ChatWarningState(changed: () {});
    state.show(const AgentNotice(text: 'First', key: 'credit'));
    state.show(const AgentNotice(text: 'Independent'));
    state.show(const AgentNotice(text: 'Replacement', key: 'credit'));
    expect(state.notices.map((n) => n.text), ['Independent', 'Replacement']);
    state.withdraw('credit');
    expect(state.notices.single.text, 'Independent');
  });

  test('replacement cancels its old expiry', () {
    fakeAsync((clock) {
      final state = ChatWarningState(changed: () {});
      state.show(
        const AgentNotice(text: 'First', key: 'k', kind: 'ttl', ttlMs: 100),
      );
      clock.elapse(const Duration(milliseconds: 50));
      state.show(
        const AgentNotice(
          text: 'Replacement',
          key: 'k',
          kind: 'ttl',
          ttlMs: 100,
        ),
      );
      clock.elapse(const Duration(milliseconds: 50));
      expect(state.notices.single.text, 'Replacement');
      clock.elapse(const Duration(milliseconds: 50));
      expect(state.notices, isEmpty);
    });
  });

  test('invalid ttl and sticky notices require dismissal', () {
    fakeAsync((clock) {
      final state = ChatWarningState(changed: () {});
      const invalid = AgentNotice(
        text: 'Invalid expiry',
        kind: 'ttl',
        ttlMs: -1,
      );
      state.show(invalid);
      state.show(const AgentNotice(text: 'Sticky', ttlMs: 1));
      clock.elapse(const Duration(days: 1));
      expect(state.notices, hasLength(2));
      state.dismiss(invalid);
      expect(state.notices.single.text, 'Sticky');
    });
  });

  test('runtime replacement clears notices and cancels timers', () {
    fakeAsync((clock) {
      var changes = 0;
      final state = ChatWarningState(changed: () => changes++);
      state.adopt('runtime-a');
      state.show(const AgentNotice(text: 'Old', kind: 'ttl', ttlMs: 10));
      state.adopt('runtime-b');
      final before = changes;
      clock.elapse(const Duration(seconds: 1));
      expect(state.notices, isEmpty);
      expect(changes, before);
    });
  });
}
