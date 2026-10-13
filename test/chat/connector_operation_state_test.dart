import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';

import 'connector_fixtures.dart';

void main() {
  test(
    'update before request retains full target snapshot and rejects stale seq',
    () {
      final attachment = Object();
      final state = ConnectorOperationsState()..adopt(attachment);
      final update = ConnectorOperationSnapshot.fromUpdate(
        connectionUpdateFixture,
      )!;
      state.apply(update, attachment: attachment);
      state.apply(
        ConnectorOperationSnapshot.fromRequest(
          connectionRequestFixture,
          runtimeId: 'runtime-a',
        )!,
        attachment: attachment,
      );
      expect(state.operations.single.seq, 4);
      expect(state.operations.single.timeoutSeconds, 60);
      expect(state.operations.single.toolCallId, 'synthetic-tool');
      expect(state.operations.single.targets.single.state, 'initiated');
      expect(state.operations.single.owner.sessionId, 'runtime-a');
      final account = ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'owner': {'type': 'account'},
      })!;
      state.apply(account, attachment: attachment);
      expect(state.operations, hasLength(2));
    },
  );
  test('late request fills missing metadata without replacing known values or progress', () {
    final attachment = Object();
    final state = ConnectorOperationsState()..adopt(attachment);
    final known = ConnectorOperationSnapshot.fromRequest({
      ...connectionRequestFixture,
      'seq': 4,
      'timeout_seconds': 50,
      'tool_call_id': null,
    }, runtimeId: 'runtime-a')!;
    state.apply(known, attachment: attachment);
    state.apply(
      ConnectorOperationSnapshot.fromRequest(
        connectionRequestFixture,
        runtimeId: 'runtime-a',
      )!,
      attachment: attachment,
    );
    final current = state.operations.single;
    expect(current.seq, 4);
    expect(current.timeoutSeconds, 50);
    expect(current.toolCallId, 'synthetic-tool');
    expect(current.deadlineAt, known.deadlineAt);
    expect(current.targets, same(known.targets));
  });

  test('pending resume preserves owner deadline and tool identity without reordering targets', () {
    final operation = ConnectorOperationSnapshot.fromPending(
      connectionRequestFixture,
      runtimeId: 'runtime-a',
    )!;
    expect(operation.timeoutSeconds, 60);
    expect(operation.toolCallId, 'synthetic-tool');
    expect(operation.deadlineAt, DateTime.utc(2030, 1, 1, 0, 1));
    expect(operation.targets.single.name, 'synthetic-connector');
    expect(
      ConnectorOperationSnapshot.fromPending(null, runtimeId: 'runtime-a'),
      isNull,
    );
    expect(
      ConnectorOperationSnapshot.fromRequest({
        ...connectionRequestFixture,
        'targets': 'malformed',
      }, runtimeId: 'runtime-a'),
      isNull,
    );
  });
  test(
    'attachment replacement clears prior snapshots and rejects late delivery',
    () {
      final attachment = Object();
      final state = ConnectorOperationsState()..adopt(attachment);
      final operation = ConnectorOperationSnapshot.fromUpdate(
        connectionUpdateFixture,
      )!;
      state.apply(operation, attachment: attachment);
      state.adopt(Object());
      expect(
        state.apply(operation, attachment: attachment),
        ConnectorSnapshotOutcome.stale,
      );
      expect(state.operations, isEmpty);
    },
  );
}
