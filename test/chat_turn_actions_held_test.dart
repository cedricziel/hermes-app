import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_notification_service.dart';

/// Retry, Edit and Branch while the server may still run the turn: they wait,
/// the actions say why, nothing is sent, and a "busy" answer is told as what it
/// is. `prompt.submit` stays at one in every test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late FakeNotificationService notifications;
  late AttentionNotifier attention;
  late ChatController chat;
  late ChatThread thread;
  late FakeSend send;
  String? prefilled;

  setUp(() {
    transport = FakeChatTransport();
    notifications = FakeNotificationService();
    attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
      onPrefill: (text) => prefilled = text,
      reconnectRetry: const Duration(hours: 1),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  Future<void> startTurn() async {
    chat.newThread();
    thread = chat.selectedThread!;
    expect(chat.submit('Run the build', const []), isTrue);
    send = transport.sends.single;
    send
      ..emit(const ThreadBound('s1'))
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Starting the build. '))
      ..emit(const ToolStarted(name: 'terminal', id: 't1', summary: 'make'));
    await pumpEventQueue();
  }

  ChatMessage assistant() =>
      thread.messages.lastWhere((m) => m.role == ChatRole.assistant);

  /// The turn ends with [error]; [serverRuns] is what the server answers when
  /// asked which sessions are working.
  Future<void> end(Object error, {required bool serverRuns}) async {
    if (serverRuns) transport.active['s1'] = 'working';
    send.fail(error);
    await pumpEventQueue();
  }

  /// Retry and Edit are taken back: nothing is undone, nothing is sent.
  Future<void> expectNothingGoesOut() async {
    await chat.retry(thread);
    await chat.editLastPrompt(thread);
    await pumpEventQueue();
    expect(transport.undos, isEmpty);
    expect(transport.sends, hasLength(1));
  }

  group('while the server may still run the turn', () {
    test('a reply that is reconnecting holds Retry, Edit and Branch', () async {
      await startTurn();
      await end(const GatewayReplyLost(), serverRuns: true);

      expect(assistant().reconnecting, isTrue);
      expect(chat.canEditLastPrompt(thread), isFalse);
      expect(chat.canBranch(thread), isFalse);
      await expectNothingGoesOut();
    });

    test('a reply whose reconnect gave up (idle) holds them too', () async {
      await startTurn();
      await end(const GatewayReplyLost(), serverRuns: true);
      assistant().reconnectIdle = true;

      expect(chat.canEditLastPrompt(thread), isFalse);
      await expectNothingGoesOut();
    });

    test(
      '"couldn\'t confirm" holds them, with the reason on the actions',
      () async {
        await startTurn();
        await end(const GatewayReplyUnconfirmed(), serverRuns: true);

        expect(assistant().loss, ReplyLoss.unconfirmed);
        expect(assistant().serverMayRun, isTrue);
        expect(chat.turnActionsHeld(thread), isTrue);
        expect(chat.turnActionStatus(thread).held, isTrue);
        expect(chat.canEditLastPrompt(thread), isFalse);
        // Still offered, dimmed: the screen asks as if the hold were not there.
        expect(chat.canEditLastPrompt(thread, ignoringHold: true), isTrue);
        expect(chat.canBranch(thread), isFalse);
        await expectNothingGoesOut();
      },
    );

    test('a failure that came from the connection holds them and does not '
        'tell the person to send it again', () async {
      await startTurn();
      await end(const GatewayTurnEnded(), serverRuns: true);

      final reply = assistant();
      expect(reply.status, MessageStatus.error);
      expect(reply.loss, isNull);
      expect(chat.turnActionsHeld(thread), isTrue);
      await expectNothingGoesOut();
      final shown = chatMessageToFlyer(reply)
          .whereType<TextMessage>()
          .firstWhere((m) => m.id == reply.id);
      expect(shown.metadata, {kMetaFailure: kFailureMayStillRun});
    });

    test('they come back by themselves when the server lists the session as '
        'not running, and then Retry takes the turn back', () async {
      await startTurn();
      await end(const GatewayReplyUnconfirmed(), serverRuns: true);
      expect(chat.turnActionsHeld(thread), isTrue);

      transport.active.clear();
      expect(await chat.refreshActive(), isTrue);

      expect(chat.turnActionsHeld(thread), isFalse);
      expect(chat.turnActionStatus(thread).held, isFalse);
      expect(chat.canEditLastPrompt(thread), isTrue);
      await chat.retry(thread);
      await pumpEventQueue();
      expect(transport.undos, [('s1', true)]);
      expect(transport.sends, hasLength(2));
    });

    test('a server that cannot be asked keeps them held', () async {
      await startTurn();
      await end(const GatewayReplyUnconfirmed(), serverRuns: true);
      transport.active.clear();
      transport.activeError = const GatewayConnectionClosed();

      expect(await chat.refreshActive(), isFalse);

      expect(chat.turnActionsHeld(thread), isTrue);
      await expectNothingGoesOut();
    });
  });

  group('when the server definitely does not have the turn', () {
    for (final (name, error, loss) in <(String, Object, ReplyLoss?)>[
      (
        'restarted',
        const GatewaySessionGone(4007, restarted: true),
        ReplyLoss.restarted,
      ),
      (
        'not on the server',
        const GatewaySessionGone(4007),
        ReplyLoss.notOnServer,
      ),
      (
        'a failure the server answered',
        const GatewayRpcException(5000, 'boom'),
        null,
      ),
      ('a plain failure of the app', StateError('boom'), null),
    ]) {
      test('$name leaves Retry and Edit available', () async {
        await startTurn();
        // Even a server that still lists the session does not hold them: it
        // answered, or the turn is not its any more.
        await end(error, serverRuns: true);

        expect(assistant().loss, loss);
        expect(assistant().serverMayRun, isFalse);
        expect(chat.turnActionsHeld(thread), isFalse);
        expect(chat.turnActionStatus(thread).held, isFalse);
        expect(chat.canEditLastPrompt(thread), isTrue);
        await chat.retry(thread);
        await pumpEventQueue();
        expect(transport.undos, [('s1', true)]);
        expect(transport.sends, hasLength(2));
      });
    }

    test('a failure the server reported while the connection broke is an '
        'answer too', () async {
      await startTurn();
      send.emit(const ReplyErrored('rate limited'));
      await end(const GatewayTurnEnded(), serverRuns: true);

      expect(assistant().error, 'rate limited');
      expect(chat.turnActionsHeld(thread), isFalse);
    });
  });

  group('a "busy" answer is told as what it is', () {
    /// A reply the server does not have, so Retry is offered and goes out.
    Future<void> settled() async {
      await startTurn();
      await end(
        const GatewaySessionGone(4007, restarted: true),
        serverRuns: false,
      );
      transport.undoError = const GatewayRpcException(4009, 'session busy');
    }

    test('Retry: no "couldn\'t try again", nothing resent', () async {
      await settled();

      await chat.retry(thread);
      await pumpEventQueue();

      final problem = chat.turnActionStatus(thread).problem;
      expect(
        problem,
        const TurnActionProblem(TurnAction.retry, TurnProblemKind.busy),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        problem!.text(l10n),
        'Hermes is still working on this. Try again when it is done.',
      );
      expect(problem.text(l10n), isNot(contains("couldn't")));
      expect(transport.sends, hasLength(1));
    });

    test('Edit says the same and puts nothing in the composer', () async {
      await settled();

      await chat.editLastPrompt(thread);
      await pumpEventQueue();

      expect(
        chat.turnActionStatus(thread).problem,
        const TurnActionProblem(TurnAction.edit, TurnProblemKind.busy),
      );
      expect(prefilled, isNull);
      expect(transport.sends, hasLength(1));
    });

    test('Branch says the same', () async {
      await settled();
      transport.branchError = const GatewayRpcException(4009, 'session busy');

      await chat.branch(thread);
      await pumpEventQueue();

      expect(
        chat.turnActionStatus(thread).problem,
        const TurnActionProblem(TurnAction.branch, TurnProblemKind.busy),
      );
      expect(transport.sends, hasLength(1));
    });

    test('any other refusal is still told as a refusal', () async {
      await settled();
      transport.undoError = const GatewayRpcException(4000, 'invalid params');

      await chat.retry(thread);
      await pumpEventQueue();

      expect(
        chat.turnActionStatus(thread).problem,
        const TurnActionProblem(TurnAction.retry, TurnProblemKind.rejected),
      );
    });

    test('the next prompt clears it', () async {
      await settled();
      await chat.retry(thread);
      await pumpEventQueue();
      expect(chat.turnActionStatus(thread).problem, isNotNull);

      transport.undoError = null;
      chat.submit('Again', const []);
      await pumpEventQueue();

      expect(chat.turnActionStatus(thread).problem, isNull);
    });
  });

  group('the words are the locale\'s', () {
    test('every notice has an English and a German sentence', () {
      for (final code in ['en', 'de']) {
        final l10n = lookupAppLocalizations(Locale(code));
        final texts = [
          l10n.chatReplyFailedGeneric,
          l10n.chatReplyFailedMayStillRun,
          l10n.chatReplyFailedProfileUnavailable,
          l10n.chatTurnBusy,
          l10n.chatTurnHeld,
          for (final action in TurnAction.values) ...[
            l10n.chatTurnRejected(action.name),
            l10n.chatTurnUnreachable(action.name),
          ],
        ];
        for (final text in texts) {
          expect(text, isNotEmpty, reason: code);
        }
        expect(texts.toSet(), hasLength(texts.length), reason: code);
      }
      final en = lookupAppLocalizations(const Locale('en'));
      final de = lookupAppLocalizations(const Locale('de'));
      expect(
        en.chatReplyFailedGeneric,
        'Something went wrong. Try sending it again.',
      );
      expect(de.chatReplyFailedGeneric, isNot(en.chatReplyFailedGeneric));
      expect(de.chatTurnBusy, isNot(en.chatTurnBusy));
      expect(de.chatTurnHeld, isNot(en.chatTurnHeld));
    });
  });

  group('tool calls of a reply the client lost the connection under', () {
    for (final (name, error) in <(String, Object)>[
      ('a turn found over with nothing to show', const GatewayTurnEnded()),
      ('a restart', const GatewayTurnEnded(restarted: true)),
      ('a session that is gone', const GatewaySessionGone(4007)),
      ('a server that could not say', const GatewayReplyUnconfirmed()),
    ]) {
      test('are not marked failed after $name', () async {
        await startTurn();
        await end(error, serverRuns: false);

        expect(assistant().toolCalls.single.status, ToolCallStatus.cancelled);
        expect(transport.sends, hasLength(1));
      });
    }

    test('are marked failed only when the server reported the error', () async {
      await startTurn();
      send.emit(const ReplyErrored('The command failed.'));
      await end(const GatewayTurnEnded(), serverRuns: false);

      expect(assistant().toolCalls.single.status, ToolCallStatus.error);
    });
  });

  group('a late completion of a reply settled as lost', () {
    setUp(() {
      // Away from the chat, so the notifications are posted.
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      addTearDown(
        () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
    });

    test('is told once as the success it is, after the failure', () async {
      await startTurn();
      await end(const GatewayReplyUnconfirmed(), serverRuns: true);
      await pumpEventQueue();
      expect(notifications.shown.map((n) => n.body), ['Reply failed']);

      transport.followUpStreams['s1']!
        ..emit(const ThreadNeedsRefetch())
        ..emit(const ReplyCompleted('The build finished.'));
      await pumpEventQueue();

      expect(assistant().status, MessageStatus.sent);
      expect(assistant().serverMayRun, isFalse);
      expect(notifications.shown.map((n) => n.body), [
        'Reply failed',
        'The build finished.',
      ]);
      expect(transport.sends, hasLength(1));
    });

    test('is not told twice when it failed again', () async {
      await startTurn();
      await end(const GatewayReplyUnconfirmed(), serverRuns: true);
      await pumpEventQueue();

      transport.followUpStreams['s1']!
        ..emit(const ThreadNeedsRefetch())
        ..emit(const ReplyCompleted('', failed: true));
      await pumpEventQueue();

      expect(notifications.shown.map((n) => n.body), ['Reply failed']);
      expect(transport.sends, hasLength(1));
    });
  });
}
