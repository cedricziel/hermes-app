import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

/// What the app does with a frame Hermes' gateway contract lists.
enum Use {
  /// `mapGatewayEvent` turns it into a `ChatEvent`.
  shown,

  /// The RPC client or transport reads it; it never reaches the chat.
  transport,

  /// Relevant to this app, but nothing shows it yet.
  gap,

  /// Drives a Hermes desktop or TUI feature this app does not have.
  notForThisApp,
}

/// Every notification in `openrpc/hermes-gateway.openrpc.json`.
const notifications = <String, (Use, String)>{
  'message.start': (Use.shown, 'opens the reply'),
  'message.delta': (Use.shown, 'reply text'),
  'message.interim': (Use.shown, 'sealed prose beside tool calls'),
  'message.complete': (Use.shown, 'ends the reply'),
  'reasoning.delta': (Use.shown, 'reasoning'),
  'reasoning.available': (Use.shown, 'reasoning, non-streaming providers'),
  'thinking.delta': (Use.shown, 'provider waits only, as the status line'),
  'tool.generating': (Use.shown, 'tool call being prepared'),
  'tool.start': (Use.shown, 'tool call card'),
  'tool.complete': (Use.shown, 'tool call result'),
  'session.title': (Use.shown, 'thread title'),
  'session.info': (Use.shown, 'settles the turn, re-keys the thread'),
  'error': (Use.shown, 'reply failure'),
  'status.update': (
    Use.shown,
    'compacting reply status and inspectable transient session waits',
  ),
  'approval.cancelled': (Use.shown, 'withdraws approval cards'),
  'request.cancel': (Use.shown, 'withdraws an input request card'),
  'subagent.spawn_requested': (Use.shown, 'subagent row'),
  'subagent.start': (Use.shown, 'subagent row'),
  'subagent.progress': (Use.shown, 'subagent row'),
  'subagent.tool': (Use.shown, 'subagent row'),
  'subagent.thinking': (Use.shown, 'subagent row'),
  'subagent.complete': (Use.shown, 'subagent row'),
  'gateway.ready': (Use.transport, 'replay epoch'),
  'review.summary': (
    Use.shown,
    'what the background review saved, under the reply',
  ),
  'tool.output_risk': (
    Use.shown,
    'tool output flagged for injection or secrets',
  ),
  'todo.updated': (Use.shown, 'read-only authoritative plan snapshot'),
  'notice': (Use.shown, 'session notice line'),
  'notification.show': (Use.shown, 'credit and slow-start warnings'),
  'notification.clear': (Use.shown, 'withdraws a notification.show'),
  'session.usage': (Use.shown, 'scoped session counters'),
  'session.control.update': (Use.shown, 'goal, loop and heartbeat snapshots'),
  'session.reclaimed': (Use.shown, 'runtime invalidation and explicit reopen'),
  'session.resume_progress': (Use.shown, 'hydration phase and status'),
  'moa.reference': (Use.shown, 'mixture-of-agents reference output'),
  'moa.aggregating': (Use.shown, 'mixture-of-agents progress'),
  'moa.progress': (Use.shown, 'mixture-of-agents progress'),
  'moa.phase': (Use.shown, 'mixture-of-agents progress'),
  'message.reaction': (Use.gap, 'the agent reacted to a message'),
  'reaction': (Use.gap, "reaction to the user's message"),
  'agent.terminal.output': (Use.shown, 'bounded process output card'),
  'terminal.close': (Use.shown, 'process closed without exit inference'),
  'background.complete': (Use.shown, 'separate background result card'),
  'btw.complete': (Use.shown, 'separate side question answer card'),
  'connection.request': (Use.shown, 'scoped connector operation request'),
  'connection.update': (
    Use.shown,
    'scoped or read-only account operation snapshot',
  ),
  'billing.step_up.verification': (Use.gap, 'device-flow code to approve'),
  'sessions.changed': (Use.gap, 'could refresh the thread list'),
  'cron.changed': (Use.gap, 'could refresh Schedules'),
  'platforms.changed': (Use.gap, 'could refresh Messaging'),
  'pairing.changed': (Use.gap, 'could refresh Messaging pairing'),
  'projects.changed': (Use.notForThisApp, 'desktop projects'),
  'skin.changed': (Use.notForThisApp, 'TUI/desktop skin'),
  'setup.ready': (Use.notForThisApp, 'desktop free-tier setup'),
  'free_tier.challenge': (Use.notForThisApp, 'desktop free-tier setup'),
  'tip.show': (Use.notForThisApp, 'desktop tip bubble'),
  'layout.apply': (Use.notForThisApp, 'desktop layout'),
  'pane.reveal': (Use.notForThisApp, 'desktop layout'),
  'preview.open': (Use.notForThisApp, 'desktop preview pane'),
  'preview.close': (Use.notForThisApp, 'desktop preview pane'),
  'preview.restart.progress': (Use.notForThisApp, 'desktop preview pane'),
  'preview.restart.complete': (Use.notForThisApp, 'desktop preview pane'),
  'browser.progress': (Use.notForThisApp, 'desktop browser'),
  'browser.controller.command': (Use.notForThisApp, 'desktop browser'),
  'browser.controller.cancel': (Use.notForThisApp, 'desktop browser'),
  'voice.status': (Use.notForThisApp, 'desktop voice'),
  'voice.partial': (Use.notForThisApp, 'desktop voice'),
  'voice.transcript': (Use.notForThisApp, 'desktop voice'),
  'voice.interrupted': (Use.notForThisApp, 'desktop voice'),
  'wake.detected': (Use.notForThisApp, 'desktop voice'),
  'pet.changed': (Use.notForThisApp, 'desktop pet'),
  'pet.generate.progress': (Use.notForThisApp, 'desktop pet'),
  'pet.hatch.progress': (Use.notForThisApp, 'desktop pet'),
  'display.status': (Use.notForThisApp, 'desktop Bot Screen'),
  'display.lease': (Use.notForThisApp, 'desktop Bot Screen'),
  'display.install.log': (Use.notForThisApp, 'desktop Bot Screen'),
  'display.install.done': (Use.notForThisApp, 'desktop Bot Screen'),
  'bot_relay.outbox.pending': (Use.notForThisApp, 'desktop bot relay'),
};

/// Frames the mapper still handles that the contract no longer lists: since
/// the server-request protocol, approvals and questions arrive as requests.
const legacy = {
  'approval.request',
  'clarify.request',
  'secret.request',
  'sudo.request',
  'approval.expire',
  'clarify.expire',
  'secret.expire',
  'sudo.expire',
};

/// The server requests the transport refuses at once.
const refusedRequests = <String, String>{
  'display.install.sudo': 'desktop Bot Screen',
  'preview.act': 'desktop preview pane',
  'preview.read': 'desktop preview pane',
  'setup_choose': 'desktop setup',
  'terminal.read': 'desktop terminal',
  'tour': 'desktop guided tour',
  'window.read': 'desktop window bridge',
};

/// A payload the mapper shows, for frames it drops when the payload is empty.
const samples = <String, Map<String, Object?>>{
  'connection.request': {
    'op_id': 'operation',
    'seq': 1,
    'deadline_at': 1893456060.0,
    'timeout_seconds': 60.0,
    'targets': [],
  },
  'connection.update': {
    'op_id': 'operation',
    'seq': 2,
    'deadline_at': 1893456060.0,
    'targets': [],
    'settled': false,
    'owner': {'type': 'session', 'session_id': 's'},
  },

  'moa.reference': {
    'label': 'Advisor',
    'text': 'Reference',
    'index': 0,
    'count': 2,
  },
  'moa.progress': {'label': 'Advisor', 'refs_done': 1, 'refs_total': 2},
  'moa.phase': {
    'phase': 'aggregator',
    'refs_done': 2,
    'refs_total': 2,
    'aggregator': 'Reported',
  },
  'moa.aggregating': {'aggregator': 'Reported'},
  'todo.updated': {'revision': 1, 'todos': []},
  'background.complete': {'task_id': 'task', 'text': 'Reported answer'},
  'btw.complete': {
    'task_id': 'task',
    'text': 'Reported answer',
    'question': 'Reported question',
  },
  'agent.terminal.output': {'process_id': 'worker', 'chunk': 'Reported output'},
  'terminal.close': {'process_id': 'worker'},
  'tool.output_risk': {
    'tool_id': 'tool',
    'name': 'terminal',
    'risk': 'secret',
    'findings': ['Redacted'],
    'redacted': true,
  },
  'notice': {'message': 'Session notice'},
  'notification.show': {
    'text': 'Credit notice',
    'level': 'warn',
    'kind': 'sticky',
  },
  'notification.clear': {'key': 'credit'},
  'review.summary': {'text': 'Memory updated'},
  'status.update': {'kind': 'compacting', 'text': 'compacting'},
  'session.control.update': {
    'control': {
      'goal': null,
      'loop': null,
      'heartbeat': null,
      'revision': '',
      'updated_at': 0,
    },
  },
  'session.reclaimed': {
    'session_id': 's',
    'stored_session_id': 'stored',
    'reason': 'Another client reopened the session',
  },
  'session.resume_progress': {'phase': 'history', 'status': 'loading'},
  'subagent.spawn_requested': {'subagent_id': 'c1', 'goal': 'g'},
  'subagent.start': {'subagent_id': 'c1', 'goal': 'g'},
  'subagent.progress': {'subagent_id': 'c1', 'goal': 'g'},
  'subagent.tool': {'subagent_id': 'c1', 'goal': 'g'},
  'subagent.thinking': {'subagent_id': 'c1', 'goal': 'g'},
  'subagent.complete': {'subagent_id': 'c1', 'goal': 'g'},
};

Object? map(String type) => mapGatewayEvent(
  GatewayEvent(type: type, sessionId: 's', payload: samples[type] ?? const {}),
);

void main() {
  final contract = jsonDecode(
    File('openrpc/hermes-gateway.openrpc.json').readAsStringSync(),
  ) as Map<String, Object?>;
  Set<String> names(String key) => {
    for (final entry in contract[key]! as List)
      (entry as Map)['name'] as String,
  };

  test('every notification in the contract is classified', () {
    expect(notifications.keys.toSet(), names('x-notifications'));
  });

  test('the frames classified as shown are the ones the mapper maps', () {
    for (final MapEntry(key: type, value: (use, _)) in notifications.entries) {
      expect(map(type), use == Use.shown ? isNotNull : isNull, reason: type);
    }
  });

  test('legacy frames are mapped and absent from the contract', () {
    for (final type in legacy) {
      expect(map(type), isNotNull, reason: type);
    }
    expect(legacy.intersection(names('x-notifications')), isEmpty);
  });

  test('every server request in the contract is answered or refused', () {
    expect({
      ...handledServerRequests,
      ...refusedRequests.keys,
    }, names('x-server-requests'));
    expect(
      handledServerRequests.intersection(refusedRequests.keys.toSet()),
      isEmpty,
    );
  });
}
