import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/tool_result.dart';

void main() {
  group('toolResultStatus', () {
    test('a plain or successful result completed', () {
      expect(toolResultStatus('3 matches'), ToolCallStatus.completed);
      expect(toolResultStatus(null), ToolCallStatus.completed);
      expect(
        toolResultStatus({'output': 'a', 'exit_code': 0, 'error': null}),
        ToolCallStatus.completed,
      );
    });

    test('an error or a non-zero exit code failed', () {
      expect(
        toolResultStatus({'output': '', 'error': 'BLOCKED: denied'}),
        ToolCallStatus.error,
      );
      expect(
        toolResultStatus({'output': 'failing', 'exit_code': 3, 'error': null}),
        ToolCallStatus.error,
      );
    });

    test('a killed run was cancelled', () {
      expect(
        toolResultStatus({
          'output': 'partial\n[Command interrupted]',
          'exit_code': 130,
          'error': null,
        }),
        ToolCallStatus.cancelled,
      );
      expect(
        toolResultStatus('[execution interrupted - timed out]'),
        ToolCallStatus.cancelled,
      );
    });

    test('the marker quoted in a successful output is data', () {
      expect(
        toolResultStatus({
          'output': 'grep hit: [Command interrupted]',
          'exit_code': 0,
        }),
        ToolCallStatus.completed,
      );
      expect(
        toolResultStatus({
          'output': '[Command interrupted]\nthen more output',
          'exit_code': 1,
        }),
        ToolCallStatus.error,
      );
    });
  });

  test('toolResultError reads the error text', () {
    expect(toolResultError({'error': ' BLOCKED: denied '}), 'BLOCKED: denied');
    expect(toolResultError({'error': null}), isEmpty);
    expect(toolResultError('x'), isEmpty);
  });
}
