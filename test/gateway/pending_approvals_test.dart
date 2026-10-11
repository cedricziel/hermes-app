import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });

  tearDown(() => transport.close());

  void live(Map<String, String> sessionKeyToId) {
    gateway.handlers['session.active_list'] = (_) => {
      'sessions': [
        for (final entry in sessionKeyToId.entries)
          {'id': entry.value, 'session_key': entry.key, 'status': 'waiting'},
      ],
    };
  }

  test(
    'finds the live session by its stored id and lists its approvals',
    () async {
      live({'other': 'rt-0', 'stored-1': 'rt-1'});
      gateway.handlers['approval.pending'] = (params) => {
        'approvals': [
          {
            'request_id': 'r1',
            'command': 'rm -rf build',
            'description': 'Delete the build folder',
            'choices': ['once', 'deny'],
          },
        ],
      };

      final approvals = await transport.pendingApprovals(
        threadId: 'stored-1',
        profile: 'work',
      );

      expect(approvals, hasLength(1));
      expect(approvals.single.requestId, 'r1');
      expect(approvals.single.command, 'rm -rf build');
      expect(approvals.single.description, 'Delete the build folder');
      expect(approvals.single.choices, ['once', 'deny']);
      expect(gateway.requestOf('session.active_list')['params'], {
        'profile': 'work',
      });
      expect(gateway.requestOf('approval.pending')['params'], {
        'session_id': 'rt-1',
        'profile': 'work',
      });
    },
  );

  test('leaves the profile out when none is given', () async {
    live({'stored-1': 'rt-1'});
    gateway.handlers['approval.pending'] = (_) => {'approvals': <Object?>[]};

    await transport.pendingApprovals(threadId: 'stored-1');

    expect(gateway.requestOf('session.active_list')['params'], isEmpty);
    expect(gateway.requestOf('approval.pending')['params'], {
      'session_id': 'rt-1',
    });
  });

  test('has no approvals for a session that is not live', () async {
    live({'other': 'rt-0'});

    final approvals = await transport.pendingApprovals(threadId: 'stored-1');

    expect(approvals, isEmpty);
    expect(gateway.methods, isNot(contains('approval.pending')));
  });

  test(
    'skips rows without a request id and reads missing text as empty',
    () async {
      live({'stored-1': 'rt-1'});
      gateway.handlers['approval.pending'] = (_) => {
        'approvals': [
          {'command': 'no id'},
          'junk',
          {'request_id': '', 'command': 'empty id'},
          {'request_id': 'r2'},
        ],
      };

      final approvals = await transport.pendingApprovals(threadId: 'stored-1');

      expect(approvals.map((a) => a.requestId), ['r2']);
      expect(approvals.single.command, '');
      expect(approvals.single.choices, isEmpty);
    },
  );

  test('a server without approval.pending reports none', () async {
    live({'stored-1': 'rt-1'});
    gateway.handlers['approval.pending'] = (_) =>
        throw const FakeRpcError(-32601, 'method not found');

    expect(await transport.pendingApprovals(threadId: 'stored-1'), isEmpty);
  });
}
