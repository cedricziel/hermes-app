import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/subagents/activity_selection.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';

void main() {
  test('a used Stop request is not asked again by a detail built anew', () {
    final selection = ActivitySelection();
    final connection = Object();
    selection.select(
      AgentKey(
        threadId: 't',
        profile: 'p',
        connection: connection,
        subagentId: 'a',
      ),
      stop: true,
    );
    expect(selection.stopRequested, isTrue);
    selection.consumeStop();
    expect(selection.stopRequested, isFalse);
    expect(selection.key, isNotNull);
  });
}
