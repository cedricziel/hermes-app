import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/account_key.dart';
import 'package:hermes_app/src/auth/auth_controller.dart'
    show kSavedServerUrlKey, normalizeServerUrl;
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/inline_reply.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart'
    show targetFromPayload, notificationPayload, notificationIdFor;
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart'
    show accountHashFor;
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';
import '../support/memory_token_store.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';
const _session = HermesSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: 4102444800,
  provider: 'basic',
  userId: 'u1',
  serverUrl: _url,
  mintedAt: 1000,
);

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue, reason: 'timed out waiting');
}

/// A transport whose close never answers, like a socket that hangs.
class _HangingCloseTransport extends FakeChatTransport {
  @override
  Future<void> close() {
    closed = true;
    return Completer<void>().future;
  }
}

/// A transport whose close waits for [gate].
class _GatedCloseTransport extends FakeChatTransport {
  _GatedCloseTransport(this.gate);
  final Future<void> gate;

  @override
  Future<void> close() async {
    closed = true;
    await gate;
  }
}

/// A transport whose connection cannot be built, so the body throws.
Never _boom(HeadlessHermes _) => throw StateError('no transport');

void main() {
  late FakeHermesServer server;
  late MemoryTokenStore store;
  late FakeChatTransport transport;
  late FakeNotificationService notifications;
  late NotificationSettings settings;
  late RecordedEvents events;
  late RecordingTracer tracer;
  late BreadcrumbTrail trail;
  late RunningReplies running;
  late DateTime clock;
  late String hash;
  var appLockAtArrival = false;
  var appLockAtPost = false;
  var inFront = false;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({kSavedServerUrlKey: _url});
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': true});
    store = MemoryTokenStore(_session);
    transport = FakeChatTransport();
    notifications = FakeNotificationService();
    settings = NotificationSettings();
    events = RecordedEvents();
    tracer = RecordingTracer();
    trail = BreadcrumbTrail();
    running = RunningReplies();
    clock = DateTime.utc(2026, 1, 1, 12);
    appLockAtArrival = false;
    appLockAtPost = false;
    inFront = false;
    hash = accountHashFor(accountKeyFor(normalizeServerUrl(_url)!, _session));
  });

  String payload({
    String thread = 'thread-1',
    String? profile = 'work',
    String? title = 'Trip plan',
    String? account,
    bool marker = true,
    String? job,
  }) => jsonEncode({
    if (job != null) 'j': job else 't': thread,
    'p': ?profile,
    if (marker) 'y': 1,
    'n': ?title,
    'a': account ?? hash,
  });

  /// Starts a reply; [lone] is the lone isolate's budget, otherwise the
  /// app's. [left] is what is left until `due`.
  Future<InlineReplyResult> reply(
    String? text, {
    String? body,
    Duration left = const Duration(seconds: 25),
    InlineReplyRoute route = InlineReplyRoute.lone,
    TargetPlatform platform = TargetPlatform.iOS,
    ChatTransport Function(HeadlessHermes)? transportFor,
    HeadlessDeps? deps,
    String engine = 'headless',
    bool withRunning = true,
  }) => sendInlineReply(
    payload: body ?? payload(),
    input: text,
    due: clock.add(left),
    now: () => clock,
    route: route,
    platform: platform,
    notifications: notifications,
    settings: settings,
    appLockAtArrival: () async {
      if (appLockAtArrival == true) return true;
      return false;
    },
    appLockBeforePost: () async => appLockAtPost,
    appInFront: () async => inFront,
    running: withRunning ? running : null,
    events: events.call,
    breadcrumbs: Breadcrumbs.of(trail),
    tracer: tracer,
    engine: engine,
    transportFor: transportFor ?? (_) => transport,
    deps:
        deps ??
        HeadlessDeps(
          tokenStore: store,
          prefs: SharedPreferencesAsync(),
          devServerUrl: '',
          adapter: server,
          telemetry: (attributes) => ConnectionTelemetry(tracer: tracer),
          closeGrace: const Duration(milliseconds: 50),
        ),
  );

  Future<FakeSend> sent() async {
    await _until(() => transport.sends.isNotEmpty);
    return transport.sends.single;
  }

  AttentionNotification only() {
    expect(notifications.shown, hasLength(1));
    return notifications.shown.single;
  }

  Map<Object?, Object?> payloadOf(AttentionNotification n) =>
      jsonDecode(notificationPayload(n)) as Map<Object?, Object?>;

  group('what is sent', () {
    test(
      'sends the text once, exactly as typed, queued, to the chat and profile',
      () async {
        const typed = '  Yes, book it \u{1F600}\n';
        final run = reply(typed);
        final send = await sent();
        send.onSubmitting!();
        transport.promptAccepted = true;
        send.emit(const ReplyCompleted('Done.'));

        final result = await run;

        expect(transport.sends, hasLength(1));
        expect(send.text, typed);
        expect(send.queued, isTrue);
        expect(send.threadId, 'thread-1');
        expect(send.profile, 'work');
        expect(send.onSubmitting, isNotNull);
        expect(result.outcome, InlineReplyOutcome.answered);
        expect(transport.closed, isTrue);
      },
    );

    test('a chat with no profile is still sent', () async {
      final run = reply('Yes', body: payload(profile: null));
      final send = await sent();
      send
        ..onSubmitting!()
        ..emit(const ReplyCompleted('ok'));
      transport.promptAccepted = true;
      await run;

      expect(send.profile, isNull);
      expect(send.queued, isTrue);
    });

    test('empty and whitespace input send and post nothing', () async {
      for (final text in [null, '', '  \n\t ']) {
        final result = await reply(text);
        expect(result.outcome, InlineReplyOutcome.ignored);
      }
      expect(transport.sends, isEmpty);
      expect(notifications.shown, isEmpty);
      expect(server.requests, isEmpty);
      expect(tracer.spans, isEmpty);
    });

    test(
      'a job target and a payload without the marker send nothing',
      () async {
        expect(
          (await reply('Yes', body: payload(job: 'j1'))).outcome,
          InlineReplyOutcome.ignored,
        );
        expect(
          (await reply('Yes', body: payload(marker: false))).outcome,
          InlineReplyOutcome.ignored,
        );
        expect(
          (await reply('Yes', body: 'plain-thread-id')).outcome,
          InlineReplyOutcome.ignored,
        );
        expect(transport.sends, isEmpty);
        expect(notifications.shown, isEmpty);
        expect(server.requests, isEmpty);
      },
    );

    test('never answers a request nor signs the user out', () async {
      final run = reply('Yes');
      final send = await sent();
      send
        ..onSubmitting!()
        ..emit(const ReplyCompleted('ok'));
      transport.promptAccepted = true;
      await run;

      expect(transport.openAnswers, isEmpty);
      expect(transport.approvalAnswers, isEmpty);
      expect(transport.clarifyAnswers, isEmpty);
      expect(store.session, isNotNull);
    });
  });

  group('App Lock', () {
    test('on at arrival: nothing sent or kept, "Open Hermes to reply." under Hermes', () async {
      appLockAtArrival = true;
      appLockAtPost = true;

      final result = await reply('Yes, book it');

      expect(result.outcome, InlineReplyOutcome.appLocked);
      expect(result.ending, ReplyEnding.appLocked);
      expect(result.endingPosted, isTrue);
      expect(transport.sends, isEmpty);
      expect(server.requests, isEmpty);
      final n = only();
      expect(n.title, 'Hermes');
      expect(n.body, kOpenToReplyBody);
      expect(n.draft, isNull);
      expect(n.threadId, 'thread-1');
      expect(n.profile, 'work');
      expect(notificationPayload(n), isNot(contains('Yes, book it')));
      // A run-less span.
      expect(tracer.spans, hasLength(1));
      expect(tracer.spans.single.name, 'background.task');
      expect(tracer.spans.single.attributes['task'], 'notification.reply');
      expect(tracer.spans.single.attributes['reply.outcome'], 'app_locked');
      expect(tracer.spans.single.ended, isTrue);
    });

    test('unreadable counts as on', () async {
      final result = await sendInlineReply(
        payload: payload(),
        input: 'Yes',
        due: clock.add(const Duration(seconds: 25)),
        now: () => clock,
        route: InlineReplyRoute.lone,
        platform: TargetPlatform.iOS,
        notifications: notifications,
        settings: settings,
        appLockAtArrival: () async => throw StateError('unreadable'),
        appLockBeforePost: () async => true,
        appInFront: () async => false,
        tracer: tracer,
        transportFor: (_) => transport,
      );

      expect(result.outcome, InlineReplyOutcome.appLocked);
      expect(transport.sends, isEmpty);
      expect(only().body, kOpenToReplyBody);
    });

    test('turned on before the ending: text and title are dropped', () async {
      final run = reply('Yes, book it');
      final send = await sent();
      appLockAtPost = true;
      send.fail(SendFailure(SendStep.connect, StateError('x')));
      await run;

      final n = only();
      expect(n.title, 'Hermes');
      expect(n.body, kReplyNotSentBody);
      expect(n.draft, isNull);
      expect(notificationPayload(n), isNot(contains('Yes')));
    });

    test(
      'turned on before "Couldn\'t confirm": it stays "Couldn\'t confirm"',
      () async {
        appLockAtPost = true;
        final run = reply('Yes', left: const Duration(milliseconds: 150));
        final send = await sent();
        send.onSubmitting!();
        await run;

        final n = only();
        expect(n.title, 'Hermes');
        expect(n.body, kReplyUnconfirmedBody);
      },
    );
  });

  group('the account', () {
    test('a mismatch posts "Reply not sent" and sends nothing', () async {
      final result = await reply('Yes', body: payload(account: 'deadbeef'));

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(transport.sends, isEmpty);
      final n = only();
      expect(n.body, kReplyNotSentBody);
      expect(n.draft, isNull);
      expect(n.title, 'Trip plan');
    });

    test('a payload with no account hash is refused too', () async {
      final body = jsonEncode({'t': 'thread-1', 'y': 1});
      final result = await reply('Yes', body: body);

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(transport.sends, isEmpty);
      expect(only().body, kReplyNotSentBody);
    });
  });

  group('endings by the run', () {
    test('signed out: "write it again", no text kept', () async {
      store.session = null;

      final result = await reply('Yes');

      expect(result.outcome, InlineReplyOutcome.failed);
      final n = only();
      expect(n.body, kReplyNotSentBody);
      expect(n.draft, isNull);
      expect(transport.sends, isEmpty);
    });

    test(
      'locked store: "write it again", the account was never verified',
      () async {
        store.unreadable = true;

        await reply('Yes, book it');

        final n = only();
        expect(n.body, kReplyNotSentBody);
        expect(n.draft, isNull);
        expect(payloadOf(n).containsKey('u'), isFalse);
        expect(transport.sends, isEmpty);
      },
    );

    test('unreachable server: "write it again", nothing sent', () async {
      server = FakeHermesServer();
      final result = await reply(
        'Yes',
        deps: HeadlessDeps(
          tokenStore: store,
          prefs: SharedPreferencesAsync(),
          devServerUrl: '',
          adapter: server,
          closeGrace: const Duration(milliseconds: 50),
        ),
      );

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(
        events.named('notification.reply').single['outcome'],
        'unreachable',
      );
      expect(only().body, kReplyNotSentBody);
      expect(transport.sends, isEmpty);
    });

    test('a throwing body before the submit: "write it again"', () async {
      final result = await reply('Yes', transportFor: _boom);

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(
        events.named('notification.reply').single['outcome'],
        'unreachable',
      );
      expect(only().body, kReplyNotSentBody);
      expect(only().draft, isNull);
    });

    test('the run ending with the prompt written and not acknowledged: '
        '"Couldn\'t confirm", no text', () async {
      // The hung close keeps the body from deciding first, so the run's own
      // timeout is what ends it.
      final hanging = _HangingCloseTransport();
      final run = reply(
        'Yes, book it',
        left: const Duration(milliseconds: 150),
        transportFor: (_) => hanging,
      );
      await _until(() => hanging.sends.isNotEmpty);
      hanging.sends.single.onSubmitting!();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.unconfirmed);
      final n = only();
      expect(n.body, kReplyUnconfirmedBody);
      expect(n.draft, isNull);
      expect(hanging.sends, hasLength(1));
    });

    test('the run ending with the prompt acknowledged is sent', () async {
      final hanging = _HangingCloseTransport();
      final run = reply(
        'Yes',
        left: const Duration(milliseconds: 150),
        transportFor: (_) => hanging,
      );
      await _until(() => hanging.sends.isNotEmpty);
      hanging.sends.single.onSubmitting!();
      hanging.promptAccepted = true;

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      final recorded = await running.read();
      expect(recorded.single.threadId, 'thread-1');
      expect(recorded.single.profile, 'work');
    });
  });

  group('the cutoff', () {
    test(
      'app route: the run ends at due - 6 s, and the cutoff decides once',
      () async {
        final run = reply(
          'Yes',
          route: InlineReplyRoute.app,
          left: const Duration(seconds: 6, milliseconds: 150),
          engine: 'foreground',
        );
        final send = await sent();
        final started = DateTime.now();

        final result = await run;

        expect(
          DateTime.now().difference(started).inMilliseconds,
          lessThan(2000),
        );
        expect(result.outcome, InlineReplyOutcome.failed);
        expect(result.ending, ReplyEnding.notSent);
        expect(result.endingPosted, isTrue);
        expect(only().body, isIn([kReplyNotSentKeptBody, kReplyNotSentBody]));
        expect(transport.closed, isTrue);

        // A callback after the cutoff cannot flip what was decided.
        send.onSubmitting!();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(notifications.shown, hasLength(1));
        expect(
          notifications.shown.single.body,
          isIn([kReplyNotSentKeptBody, kReplyNotSentBody]),
        );
      },
    );

    test('lone isolate: the run ends at due', () async {
      final run = reply('Yes', left: const Duration(milliseconds: 150));
      await sent();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(only().body, isIn([kReplyNotSentKeptBody, kReplyNotSentBody]));
    });

    test('written and not acknowledged at the cutoff: "Couldn\'t confirm" '
        'is posted after the cutoff, before due, with no text', () async {
      final run = reply(
        'Yes, book it',
        route: InlineReplyRoute.app,
        left: const Duration(seconds: 6, milliseconds: 150),
      );
      final send = await sent();
      send.onSubmitting!();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.unconfirmed);
      expect(result.endingPosted, isTrue);
      final n = only();
      expect(n.body, kReplyUnconfirmedBody);
      expect(n.draft, isNull);
      expect(notificationPayload(n), isNot(contains('Yes')));
      expect(transport.sends, hasLength(1));
    });

    test('app route posts no ending after due', () async {
      final run = reply(
        'Yes',
        route: InlineReplyRoute.app,
        left: const Duration(seconds: 6, milliseconds: 150),
      );
      final send = await sent();
      send.onSubmitting!();
      clock = clock.add(const Duration(seconds: 30));

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.unconfirmed);
      expect(result.ending, ReplyEnding.unconfirmed);
      expect(result.endingPosted, isFalse);
      expect(notifications.shown, isEmpty);
    });

    test('the lone isolate posts its ending even past due', () async {
      final run = reply('Yes', left: const Duration(milliseconds: 150));
      final send = await sent();
      send.onSubmitting!();
      clock = clock.add(const Duration(seconds: 30));

      final result = await run;

      expect(result.endingPosted, isTrue);
      expect(only().body, kReplyUnconfirmedBody);
    });

    test('acknowledged but unfinished at the cutoff: sent, no "Reply failed", '
        'recorded on iOS', () async {
      final run = reply('Yes', left: const Duration(milliseconds: 150));
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      final recorded = await running.read();
      expect(recorded, hasLength(1));
      expect(recorded.single.threadId, 'thread-1');
      expect(recorded.single.profile, 'work');
      expect(recorded.single.fromAsk, isTrue);
    });

    test('the same on macOS records nothing', () async {
      final run = reply(
        'Yes',
        left: const Duration(milliseconds: 150),
        platform: TargetPlatform.macOS,
        route: InlineReplyRoute.mac,
      );
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      expect(await running.read(), isEmpty);
    });
  });

  group('the answer', () {
    Future<InlineReplyResult> answered({String text = 'Booked it.'}) async {
      final run = reply('Yes');
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(ReplyCompleted(text));
      return run;
    }

    test('inside the window is announced while the app is not in front, '
        'marked first', () async {
      final result = await answered();

      expect(result.outcome, InlineReplyOutcome.answered);
      final n = only();
      expect(n.body, 'Booked it.');
      expect(n.title, 'Trip plan');
      expect(n.threadId, 'thread-1');
      expect(n.profile, 'work');
      final marked = await running.readAnnounced();
      expect(marked.single.threadId, 'thread-1');
      expect(await running.takeAnnounced('work', 'thread-1'), isTrue);
      expect(await running.read(), isEmpty);
    });

    test('is not announced while the app is in front', () async {
      inFront = true;

      final result = await answered();

      expect(result.outcome, InlineReplyOutcome.answered);
      expect(notifications.shown, isEmpty);
      expect(await running.readAnnounced(), isEmpty);
    });

    test(
      'is generic and under "Hermes" if App Lock came on meanwhile',
      () async {
        appLockAtPost = true;

        await answered(text: 'Secret plans');

        final n = only();
        expect(n.body, kReplyReadyBody);
        expect(n.title, 'Hermes');
      },
    );

    test('is not announced while notifications are off', () async {
      notifications.allowedAnswer = false;

      final result = await answered();

      expect(result.outcome, InlineReplyOutcome.answered);
      expect(notifications.shown, isEmpty);
    });

    test(
      'a failed or stopped turn is sent, never announced or recorded',
      () async {
        final run = reply('Yes');
        final send = await sent();
        send.onSubmitting!();
        transport.promptAccepted = true;
        send.emit(const ReplyCompleted('boom', failed: true));

        final result = await run;

        expect(result.outcome, InlineReplyOutcome.sent);
        expect(notifications.shown, isEmpty);
        expect(await running.read(), isEmpty);
      },
    );

    test('a folded prompt is sent and not recorded', () async {
      final run = reply('Yes');
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(const PromptFolded());

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      expect(await running.read(), isEmpty);
    });

    test('a result with no status (a clean end after the answer) is sent '
        'and not recorded', () async {
      final run = reply('Yes');
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.finish();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      expect(await running.read(), isEmpty);
    });
  });

  group('after the run ended', () {
    test('an answer found after the run\'s timeout is not announced', () async {
      final slowFront = Completer<bool>();
      final run = sendInlineReply(
        payload: payload(),
        input: 'Yes',
        due: clock.add(const Duration(milliseconds: 200)),
        now: () => clock,
        route: InlineReplyRoute.lone,
        platform: TargetPlatform.iOS,
        notifications: notifications,
        settings: settings,
        appLockAtArrival: () async => false,
        appLockBeforePost: () async => false,
        appInFront: () => slowFront.future,
        running: running,
        events: events.call,
        tracer: tracer,
        transportFor: (_) => transport,
        deps: HeadlessDeps(
          tokenStore: store,
          prefs: SharedPreferencesAsync(),
          devServerUrl: '',
          adapter: server,
          telemetry: (attributes) => ConnectionTelemetry(tracer: tracer),
          closeGrace: const Duration(milliseconds: 50),
        ),
      );
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(const ReplyCompleted('Booked it.'));

      final result = await run;
      // The orphaned announcement finds out late that nobody is in front.
      slowFront.complete(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      expect(await running.readAnnounced(), isEmpty);
      // Not announced, so the background check is told instead.
      expect(await running.read(), hasLength(1));
    });

    test(
      'a callback while the close is pending still counts as written',
      () async {
        final gate = Completer<void>();
        final gated = _GatedCloseTransport(gate.future);
        final run = reply(
          'Yes',
          left: const Duration(milliseconds: 150),
          transportFor: (_) => gated,
        );
        await _until(() => gated.sends.isNotEmpty);
        await _until(() => gated.closed);
        gated.sends.single.onSubmitting!();
        gate.complete();

        final result = await run;

        expect(result.outcome, InlineReplyOutcome.unconfirmed);
        expect(only().body, kReplyUnconfirmedBody);
      },
    );

    test('a frozen mark ignores a later callback', () {
      final mark = SubmitMark()..freeze();
      mark.markWritten();
      expect(mark.written, isFalse);
      final open = SubmitMark()..markWritten();
      expect(open.written, isTrue);
    });

    test(
      'a session reclaimed after the answer is recorded as running',
      () async {
        final run = reply('Yes');
        final send = await sent();
        send.onSubmitting!();
        transport.promptAccepted = true;
        send
          ..emit(const SessionReclaimed('r', 's', 'taken'))
          ..finish();

        final result = await run;

        expect(result.outcome, InlineReplyOutcome.sent);
        expect(notifications.shown, isEmpty);
        expect(await running.read(), hasLength(1));
      },
    );
  });

  group('failures by step', () {
    Future<InlineReplyResult> failing(
      Object error, {
      bool written = false,
      bool accepted = false,
    }) async {
      final run = reply('Yes, book it');
      final send = await sent();
      if (written) send.onSubmitting!();
      transport.promptAccepted = accepted;
      send.fail(error);
      return run;
    }

    for (final step in [SendStep.connect, SendStep.open, SendStep.attach]) {
      test('${step.name}: "Reply not sent", text kept', () async {
        final result = await failing(SendFailure(step, StateError('x')));

        expect(result.outcome, InlineReplyOutcome.failed);
        final n = only();
        expect(n.body, kReplyNotSentKeptBody);
        expect(n.draft, 'Yes, book it');
        expect(transport.sends, hasLength(1));
      });
    }

    test('a profile that is gone: "Reply not sent"', () async {
      final result = await failing(const ProfileUnavailableException());

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(only().body, kReplyNotSentKeptBody);
    });

    test('submit, even a rejection: "Couldn\'t confirm", no resend', () async {
      final result = await failing(
        SendFailure(SendStep.submit, StateError('rejected')),
        written: true,
      );

      expect(result.outcome, InlineReplyOutcome.unconfirmed);
      final n = only();
      expect(n.body, kReplyUnconfirmedBody);
      expect(n.draft, isNull);
      expect(transport.sends, hasLength(1));
    });

    test('reply: sent, recorded on iOS, nothing posted', () async {
      final result = await failing(
        SendFailure(SendStep.reply, StateError('dropped')),
        written: true,
        accepted: true,
      );

      expect(result.outcome, InlineReplyOutcome.sent);
      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
    });

    test(
      'a connect failure never claims "not sent" for a written prompt',
      () async {
        final result = await failing(
          SendFailure(SendStep.connect, StateError('x')),
          written: true,
        );

        expect(result.outcome, InlineReplyOutcome.unconfirmed);
        expect(only().body, kReplyUnconfirmedBody);
      },
    );

    test('SessionReclaimed before the submit: "Reply not sent"', () async {
      final run = reply('Yes');
      final send = await sent();
      send
        ..emit(const SessionReclaimed('r', 's', 'taken'))
        ..finish();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(only().body, kReplyNotSentKeptBody);
    });

    test('SessionReclaimed after the submit, before the answer: '
        '"Couldn\'t confirm"', () async {
      final run = reply('Yes');
      final send = await sent();
      send.onSubmitting!();
      send
        ..emit(const SessionReclaimed('r', 's', 'taken'))
        ..finish();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.unconfirmed);
      expect(only().body, kReplyUnconfirmedBody);
    });

    test('a clean end with no acknowledgement: "Couldn\'t confirm"', () async {
      final run = reply('Yes');
      final send = await sent();
      send.onSubmitting!();
      send.finish();

      final result = await run;

      expect(result.outcome, InlineReplyOutcome.unconfirmed);
      expect(only().body, kReplyUnconfirmedBody);
    });

    test('the ending replaces the chat notification (same id)', () async {
      await failing(SendFailure(SendStep.connect, StateError('x')));

      final n = only();
      expect(
        notificationIdFor(n.threadId, profile: n.profile),
        notificationIdFor('thread-1', profile: 'work'),
      );
    });
  });

  group('the kept text', () {
    Future<void> failsWith(String text) async {
      final run = reply(text);
      final send = await sent();
      send.fail(SendFailure(SendStep.connect, StateError('x')));
      await run;
    }

    test('120 user-perceived characters are kept and restore unsent', () async {
      final text = '\u{1F600}' * 120;
      await failsWith(text);

      final n = only();
      expect(n.body, kReplyNotSentKeptBody);
      final target = targetFromPayload(notificationPayload(n));
      expect(target?.draft, text);
      expect(target?.threadId, 'thread-1');
      expect(target?.profile, 'work');
      expect(target?.accountHash, hash);
      expect(n.title, 'Trip plan');
      expect(n.body, isNot(contains(text)));
      expect(transport.sends, hasLength(1));
    });

    test('longer text is not kept: "write it again"', () async {
      await failsWith('x' * 121);

      final n = only();
      expect(n.body, kReplyNotSentBody);
      expect(n.draft, isNull);
      expect(payloadOf(n).containsKey('u'), isFalse);
    });

    test(
      'the kept notification names the chat, text only in the payload',
      () async {
        await failsWith('Yes, book it');

        final n = only();
        expect(n.title, isNot(contains('Yes')));
        expect(n.body, isNot(contains('Yes')));
        expect(payloadOf(n)['u'], 'Yes, book it');
        expect(payloadOf(n)['a'], hash);
        expect(payloadOf(n)['t'], 'thread-1');
      },
    );

    test('nothing is kept for unconfirmed', () async {
      final run = reply('Yes');
      final send = await sent();
      send.onSubmitting!();
      send.fail(SendFailure(SendStep.submit, StateError('x')));
      await run;

      expect(payloadOf(only()).containsKey('u'), isFalse);
    });
  });

  group('notifications off', () {
    test('no ending and no text kept when the setting is off', () async {
      await settings.load();
      await settings.setEnabled(false);

      final result = await reply('Yes', transportFor: _boom);

      expect(result.outcome, InlineReplyOutcome.failed);
      expect(
        events.named('notification.reply').single['outcome'],
        'unreachable',
      );
      expect(result.endingPosted, isFalse);
      expect(notifications.shown, isEmpty);
    });

    test('no ending when the system denies permission', () async {
      notifications.allowedAnswer = false;

      final result = await reply('Yes', transportFor: _boom);

      expect(result.endingPosted, isFalse);
      expect(notifications.shown, isEmpty);
    });

    test('no "Open Hermes to reply." either', () async {
      appLockAtArrival = true;
      notifications.allowedAnswer = false;

      final result = await reply('Yes');

      expect(result.outcome, InlineReplyOutcome.appLocked);
      expect(result.endingPosted, isFalse);
      expect(notifications.shown, isEmpty);
    });
  });

  group('postEnding', () {
    test('is the one place an ending is posted', () async {
      final posted = await postEnding(
        notifications: notifications,
        settings: settings,
        appLockOn: () async => false,
        ending: ReplyEnding.notSent,
        threadId: 't',
        profile: 'p',
        title: 'Chat',
        draft: 'text',
        accountHash: hash,
      );

      expect(posted, isTrue);
      expect(only().body, kReplyNotSentKeptBody);
    });

    test('an unreadable App Lock drops text and title', () async {
      final posted = await postEnding(
        notifications: notifications,
        settings: settings,
        appLockOn: () async => throw StateError('x'),
        ending: ReplyEnding.notSent,
        threadId: 't',
        title: 'Chat',
        draft: 'text',
        accountHash: hash,
      );

      expect(posted, isTrue);
      final n = only();
      expect(n.title, 'Hermes');
      expect(n.body, kReplyNotSentBody);
      expect(n.draft, isNull);
    });
  });

  group('telemetry', () {
    const typed = 'SECRET typed words';

    void expectClean() {
      final everything = StringBuffer();
      for (final span in tracer.spans) {
        everything
          ..write(span.attributes)
          ..write(span.eventDetails);
      }
      for (final name in ['notification.reply']) {
        everything.write(events.named(name));
      }
      everything.write([
        for (final c in trail.recent) '${c.name} ${c.attributes}',
      ]);
      final text = everything.toString();
      expect(text, isNot(contains('SECRET')));
      expect(text, isNot(contains('Trip plan')));
      expect(text, isNot(contains('thread-1')));
      expect(text, isNot(contains('work')));
      expect(text, isNot(contains(hash)));
    }

    RecordingSpan taskSpan() =>
        tracer.spans.singleWhere((s) => s.name == 'background.task');

    test('answered: annotated on the run span, logged, a breadcrumb', () async {
      final run = reply(typed, engine: 'foreground');
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(const ReplyCompleted('Done'));
      await run;

      final span = taskSpan();
      expect(span.attributes['task'], 'notification.reply');
      expect(span.attributes['engine'], 'foreground');
      expect(span.attributes['reply.outcome'], 'answered');
      expect(span.ended, isTrue);
      expect(events.named('notification.reply'), [
        {'outcome': 'answered', 'route': 'lone'},
      ]);
      expect(trail.recent, isNotEmpty);
      expectClean();
    });

    test('sent', () async {
      final run = reply(typed);
      final send = await sent();
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(const PromptFolded());
      await run;

      expect(taskSpan().attributes['reply.outcome'], 'sent');
      expect(events.named('notification.reply').single['outcome'], 'sent');
      expectClean();
    });

    test('failed', () async {
      final run = reply(typed);
      final send = await sent();
      send.fail(SendFailure(SendStep.connect, StateError('x')));
      await run;

      expect(taskSpan().attributes['reply.outcome'], 'failed');
      expect(events.named('notification.reply').single['outcome'], 'failed');
      expectClean();
    });

    test('unconfirmed', () async {
      final run = reply(typed, route: InlineReplyRoute.app);
      final send = await sent();
      send.onSubmitting!();
      send.fail(SendFailure(SendStep.submit, StateError('x')));
      await run;

      expect(taskSpan().attributes['reply.outcome'], 'unconfirmed');
      expect(events.named('notification.reply').single, {
        'outcome': 'unconfirmed',
        'route': 'app',
      });
      expectClean();
    });

    test('app_locked: a run-less span, logged', () async {
      appLockAtArrival = true;
      await reply(typed, engine: 'foreground');

      expect(tracer.spans, hasLength(1));
      expect(taskSpan().attributes['reply.outcome'], 'app_locked');
      expect(taskSpan().attributes['engine'], 'foreground');
      expect(
        events.named('notification.reply').single['outcome'],
        'app_locked',
      );
      expect(trail.recent, isNotEmpty);
      expectClean();
    });

    test(
      'a run that ended first keeps the runtime outcome, logs its own',
      () async {
        store.session = null;
        await reply(typed);

        final span = taskSpan();
        expect(span.attributes.containsKey('reply.outcome'), isFalse);
        expect(span.attributes['outcome'], 'no_session');
        expect(
          events.named('notification.reply').single['outcome'],
          'signed_out',
        );
        expectClean();
      },
    );

    test(
      'a locked keychain is logged as store_locked, never "locked"',
      () async {
        store.unreadable = true;
        await reply(typed);

        expect(
          events.named('notification.reply').single['outcome'],
          'store_locked',
        );
      },
    );

    test('the headless engine writes no breadcrumb', () async {
      final run = reply(typed);
      final send = await sent();
      send.fail(SendFailure(SendStep.connect, StateError('x')));
      await run;

      expect(trail.recent, isEmpty);
    });
  });
}
