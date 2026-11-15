import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show LogRecord, Logger;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing_controller.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing_telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_hermes_server.dart';
import '../../support/recorded_breadcrumbs.dart';
import '../../support/recorded_events.dart';
import '../../support/recording_tracer.dart';
import 'whatsapp_fixtures.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

const _profile = 'atlas';
const _platformsPath = '/api/messaging/platforms';
final _t0 = DateTime.utc(2026, 11, 15, 12);

FakeResponse _ok(Object? body) => (status: 200, body: body);

Map<String, Object?> _payload({
  String id = waId,
  required String status,
  String? qr,
  String? accountName,
  String? accountPhone,
  String? error,
}) => {
  'pairing_id': id,
  'status': status,
  'qr_payload': qr,
  'expires_at': waExpiresAt,
  'mode': 'bot',
  'allowed_users': '',
  'account_id': accountPhone == null ? null : '$accountPhone:7@s.whatsapp.net',
  'account_name': accountName,
  'account_phone': accountPhone,
  'error': error,
};

Map<String, Object?> _platforms({required bool enabled}) => {
  'platforms': [
    {'id': 'telegram', 'name': 'Telegram', 'enabled': true},
    {'id': 'whatsapp', 'name': 'WhatsApp', 'enabled': enabled},
  ],
};

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late RecordedBreadcrumbs trail;
  late WhatsAppPairingController controller;
  var notified = 0;

  // What the fake server answers; each test changes only what it needs.
  late FutureOr<FakeResponse> Function(RequestOptions) startReply;
  late FutureOr<FakeResponse> Function(RequestOptions) statusReply;
  late FutureOr<FakeResponse> Function(RequestOptions) applyReply;
  late FutureOr<FakeResponse> Function(RequestOptions) cancelReply;
  late FutureOr<FakeResponse> Function(RequestOptions) platformsReply;

  int count(String method, String path) =>
      server.requestsTo(method, path).length;
  int polls() => count('GET', waStatusPath);
  int cancels() => count('DELETE', waStatusPath);
  int applies() => count('POST', waApplyPath);
  int starts() => count('POST', waStartPath);

  FutureOr<FakeResponse> hang(RequestOptions _) =>
      Completer<FakeResponse>().future;

  FutureOr<FakeResponse> down(RequestOptions r) =>
      throw DioException.connectionError(requestOptions: r, reason: 'down');

  WhatsAppPairingTelemetry telemetry() => WhatsAppPairingTelemetry(
    ConnectionTelemetry(
      events: events.call,
      tracer: tracer,
      serverAttributes: const {'hermes.version': '0.14.2'},
    ),
    trail.breadcrumbs,
  );

  WhatsAppPairingController build(
    FakeAsync? async, {
    bool handset = false,
    bool? followsWindowFocus,
    HermesMessagingRepository? repository,
    WhatsAppPairingTelemetry? withTelemetry,
    String profile = _profile,
  }) {
    final clock = async?.getClock(_t0);
    controller = WhatsAppPairingController(
      repository: repository ?? HermesMessagingRepository(server.client().raw),
      profile: profile,
      handset: handset,
      followsWindowFocus: followsWindowFocus,
      telemetry: withTelemetry ?? telemetry(),
      now: clock?.now,
    )..addListener(() => notified++);
    return controller;
  }

  /// Lets the real Dio pipeline run to its end on the fake clock.
  void settle(FakeAsync async, [Duration by = Duration.zero]) {
    async.elapse(by + const Duration(milliseconds: 1));
    async.flushMicrotasks();
  }

  /// Presses Start and lets the answer in.
  void begin(FakeAsync async) {
    unawaited(controller.start());
    settle(async);
  }

  /// The phone has a code to scan and the polling is running.
  void waiting(FakeAsync async, {bool handset = false}) {
    startReply = (_) => _ok(waStartFresh);
    statusReply = (_) => _ok(waStatusWaiting);
    build(async, handset: handset);
    begin(async);
    settle(async, const Duration(seconds: 2));
  }

  void linked(FakeAsync async) {
    startReply = (_) => _ok(waStartAlreadyLinked);
    build(async);
    begin(async);
  }

  void finish(FakeAsync async) {
    expect(controller.requestFinish(), isTrue);
    unawaited(controller.confirmFinish());
    settle(async);
  }

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    events = RecordedEvents();
    trail = RecordedBreadcrumbs();
    notified = 0;
    startReply = (_) => _ok(waStartFresh);
    statusReply = (_) => _ok(waStatusWaiting);
    applyReply = (_) => _ok(waApplyRestartStarted);
    cancelReply = (_) => _ok(waCancelOk);
    platformsReply = (_) => _ok(_platforms(enabled: true));
    server
      ..onRequest('POST', waStartPath, (r) => startReply(r))
      ..onRequest('GET', waStatusPath, (r) => statusReply(r))
      ..onRequest('POST', waApplyPath, (r) => applyReply(r))
      ..onRequest('DELETE', waStatusPath, (r) => cancelReply(r))
      ..onRequest('GET', _platformsPath, (r) => platformsReply(r));
  });

  group('allowed numbers', () {
    test('phone numbers are accepted and sent normalised', () {
      fakeAsync((async) {
        build(async);
        controller.setAllowedUsers(' +1 555 555 0100 , 15555550101,, ');
        begin(async);
        expect(jsonBody(server.requests.single), {
          'mode': 'bot',
          'allowed_users': '+15555550100,15555550101',
          'profile': _profile,
        });
      });
    });

    test('a blank list is not sent', () {
      fakeAsync((async) {
        build(async);
        controller.setMode(WhatsAppMode.selfChat);
        begin(async);
        expect(jsonBody(server.requests.single), {
          'mode': 'self-chat',
          'profile': _profile,
        });
      });
    });

    test('everyone, JIDs, LIDs and words are refused and nothing is sent', () {
      fakeAsync((async) {
        build(async);
        final cases = <String, WhatsAppNumbersProblem>{
          '*': WhatsAppNumbersProblem.everyone,
          '+15555550100, *': WhatsAppNumbersProblem.everyone,
          '15555550100@s.whatsapp.net': WhatsAppNumbersProblem.address,
          '12345678901234@lid': WhatsAppNumbersProblem.address,
          'alice': WhatsAppNumbersProblem.notPhoneNumber,
          '+': WhatsAppNumbersProblem.notPhoneNumber,
          '++15555550100': WhatsAppNumbersProblem.notPhoneNumber,
          '1555-555-0100': WhatsAppNumbersProblem.notPhoneNumber,
          '123': WhatsAppNumbersProblem.notPhoneNumber,
          '1234567890123456': WhatsAppNumbersProblem.notPhoneNumber,
        };
        for (final MapEntry(:key, :value) in cases.entries) {
          controller.setAllowedUsers(key);
          begin(async);
          expect(controller.numbersProblem, value, reason: key);
          expect(controller.phase, WhatsAppPairingPhase.setup, reason: key);
        }
        expect(server.requests, isEmpty);
        controller.setAllowedUsers('+15555550100');
        expect(controller.numbersProblem, isNull);
      });
    });
  });

  group('start', () {
    test('sends nothing until Start, then one request with the profile', () {
      fakeAsync((async) {
        build(async)
          ..open()
          ..setMode(WhatsAppMode.selfChat);
        settle(async, const Duration(minutes: 1));
        expect(server.requests, isEmpty);
        expect(controller.phase, WhatsAppPairingPhase.setup);
        begin(async);
        expect(starts(), 1);
        expect(jsonBody(server.requests.single), {
          'mode': 'self-chat',
          'profile': _profile,
        });
        expect(controller.phase, WhatsAppPairingPhase.working);
        expect(controller.workStage, WhatsAppWorkStage.starting);
        expect(trail.named('whatsapp.pair.opened'), hasLength(1));
      });
    });

    test('a second press while it runs sends nothing', () {
      fakeAsync((async) {
        startReply = hang;
        build(async);
        unawaited(controller.start());
        unawaited(controller.start());
        settle(async);
        expect(starts(), 1);
        expect(controller.phase, WhatsAppPairingPhase.starting);
      });
    });

    test('already linked is connected with the account and no polling', () {
      fakeAsync((async) {
        linked(async);
        expect(controller.phase, WhatsAppPairingPhase.connected);
        expect(controller.alreadyLinked, isTrue);
        expect(controller.account?.name, waAccountName);
        expect(controller.qr, isNull);
        expect(controller.polling, isFalse);
        settle(async, const Duration(minutes: 1));
        expect(polls(), 0);
      });
    });

    test('no answer for 10 s is a lost answer and is never resent', () {
      fakeAsync((async) {
        startReply = hang;
        build(async);
        unawaited(controller.start());
        settle(async, const Duration(seconds: 9));
        expect(controller.phase, WhatsAppPairingPhase.starting);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.startLost);
        settle(async, const Duration(minutes: 10));
        expect(starts(), 1);
        expect(polls(), 0);
      });
    });

    test('a dropped connection on start is a lost answer too', () {
      fakeAsync((async) {
        startReply = down;
        build(async);
        begin(async);
        expect(controller.phase, WhatsAppPairingPhase.startLost);
        settle(async, const Duration(minutes: 1));
        expect(starts(), 1);
      });
    });

    test('Start again returns to the form with the same mode and numbers; '
        'only a press sends', () {
      fakeAsync((async) {
        startReply = hang;
        build(async)
          ..setMode(WhatsAppMode.selfChat)
          ..setAllowedUsers('+15555550100');
        unawaited(controller.start());
        settle(async, const Duration(seconds: 11));
        expect(controller.canStartAgain, isTrue);
        controller.startAgain();
        expect(controller.phase, WhatsAppPairingPhase.setup);
        expect(controller.mode, WhatsAppMode.selfChat);
        expect(controller.allowedUsers, '+15555550100');
        settle(async, const Duration(minutes: 1));
        expect(starts(), 1);
        startReply = (_) => _ok(waStartFresh);
        begin(async);
        expect(starts(), 2);
        expect(controller.phase, WhatsAppPairingPhase.working);
      });
    });

    test('a late answer to a lost start is cancelled once, not adopted', () {
      fakeAsync((async) {
        final late = Completer<FakeResponse>();
        startReply = (_) => late.future;
        build(async);
        unawaited(controller.start());
        settle(async, const Duration(seconds: 11));
        expect(controller.phase, WhatsAppPairingPhase.startLost);
        late.complete(_ok(waStartFresh));
        settle(async);
        expect(controller.phase, WhatsAppPairingPhase.startLost);
        expect(cancels(), 1);
        expect(polls(), 0);
      });
    });

    test('a 404 about the profile is profileDeleted, not an old server', () {
      fakeAsync((async) {
        startReply = (_) => (status: 404, body: waProfileGone);
        build(async);
        begin(async);
        expect(controller.phase, WhatsAppPairingPhase.profileDeleted);
        expect(events.named('whatsapp.pair.unavailable'), isEmpty);
      });
    });

    test('a route-missing 404 and a 405 are unsupported, logged once', () {
      fakeAsync((async) {
        final shared = telemetry();
        startReply = (_) => (status: 404, body: waRouteMissing);
        build(async, withTelemetry: shared);
        begin(async);
        expect(controller.phase, WhatsAppPairingPhase.unsupported);
        startReply = (_) => (status: 405, body: {'detail': 'x'});
        build(async, withTelemetry: shared);
        begin(async);
        expect(controller.phase, WhatsAppPairingPhase.unsupported);
        expect(events.named('whatsapp.pair.unavailable'), hasLength(1));
      });
    });

    test('a refused start stays on the form with the failure and the text', () {
      fakeAsync((async) {
        startReply = (_) => (status: 400, body: waBadMode);
        build(async);
        begin(async);
        expect(controller.phase, WhatsAppPairingPhase.setup);
        expect(
          controller.startFailure?.kind,
          WhatsAppPairingFailureKind.badRequest,
        );
        expect(controller.startFailure?.serverText?.text, contains('mode'));
        // Editing the form takes the failure away.
        controller.setMode(WhatsAppMode.selfChat);
        expect(controller.startFailure, isNull);
        expect(starts(), 1);
      });
    });

    test(
      'a 401 is a failed start that sends nothing more and says nothing',
      () {
        fakeAsync((async) {
          startReply = (_) => (status: 401, body: waUnauthorized);
          build(async);
          begin(async);
          expect(controller.phase, WhatsAppPairingPhase.setup);
          expect(
            controller.startFailure?.kind,
            WhatsAppPairingFailureKind.unexpected,
          );
          expect(starts(), 1);
        });
      },
    );
  });

  group('polling', () {
    test('every 2 s while in front and unlocked, never overlapping', () {
      fakeAsync((async) {
        startReply = (_) => _ok(waStartFresh);
        statusReply = (_) => _ok(waStatusStarting);
        build(async);
        begin(async);
        expect(polls(), 0);
        settle(async, const Duration(seconds: 2));
        expect(polls(), 1);
        settle(async, const Duration(seconds: 4));
        expect(polls(), 3);
        // An answer that is slow holds the next ticks back.
        final slow = Completer<FakeResponse>();
        statusReply = (_) => slow.future;
        settle(async, const Duration(seconds: 2));
        expect(polls(), 4);
        settle(async, const Duration(seconds: 6));
        expect(polls(), 4);
      });
    });

    test('stages follow the status: installing, starting, waiting', () {
      fakeAsync((async) {
        statusReply = (_) => _ok(waStatusInstalling);
        startReply = (_) => _ok(waStartFresh);
        build(async);
        begin(async);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.working);
        expect(controller.workStage, WhatsAppWorkStage.installing);
        statusReply = (_) => _ok(waStatusWaiting);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.qr?.value, waQr, reason: 'a computer needs no tap');
        statusReply = (_) => _ok(waStatusUnknown);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.working);
        expect(controller.workStage, WhatsAppWorkStage.other);
      });
    });

    test('a new code replaces the shown one at once', () {
      fakeAsync((async) {
        waiting(async);
        expect(controller.qr?.value, waQr);
        statusReply = (_) => _ok(waStatusWaitingRotated);
        settle(async, const Duration(seconds: 2));
        expect(controller.qr?.value, contains('CCCC'));
      });
    });

    test('pauses in the background and resumes at once with the line', () {
      fakeAsync((async) {
        waiting(async);
        expect(polls(), 1);
        controller.setInForeground(false);
        settle(async, const Duration(minutes: 1));
        expect(polls(), 1);
        expect(controller.polling, isFalse);
        expect(controller.qr, isNull);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.hidden);
        controller.setInForeground(true);
        expect(controller.pausedLine, isTrue);
        settle(async);
        expect(polls(), 2, reason: 'goes at once on return');
        expect(controller.pausedLine, isFalse, reason: 'until the answer');
        expect(controller.qr?.value, waQr);
      });
    });

    test('nothing polls while App Lock is locked, also when the app returns '
        'in front; unlocking resumes with the line', () {
      fakeAsync((async) {
        waiting(async);
        controller.cover();
        controller.setInForeground(false);
        settle(async, const Duration(minutes: 1));
        controller.setInForeground(true);
        settle(async, const Duration(minutes: 1));
        expect(polls(), 1);
        expect(controller.polling, isFalse);
        controller.uncover();
        expect(controller.pausedLine, isTrue);
        settle(async);
        expect(polls(), 2);
        expect(controller.pausedLine, isFalse);
        expect(controller.polling, isTrue);
      });
    });

    test('a poll in flight when pausing has its outcome discarded', () {
      fakeAsync((async) {
        waiting(async);
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        settle(async, const Duration(seconds: 2));
        expect(polls(), 2);
        controller.setInForeground(false);
        gate.complete(_ok(waStatusConnectedAfterScan));
        settle(async);
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.account, isNull);
      });
    });

    test('a final status stops the polling', () {
      fakeAsync((async) {
        final finals = <(Object, WhatsAppPairingPhase)>[
          (_ok(waStatusConnectedAfterScan), WhatsAppPairingPhase.connected),
          (_ok(waStatusErrorExited), WhatsAppPairingPhase.failed),
          (_ok(waStatusSuperseded), WhatsAppPairingPhase.superseded),
          ((status: 410, body: waExpiredBody), WhatsAppPairingPhase.expired),
          (_ok(_payload(status: 'expired')), WhatsAppPairingPhase.expired),
        ];
        for (final (answer, phase) in finals) {
          server.requests.clear();
          statusReply = (_) => answer as FakeResponse;
          startReply = (_) => _ok(waStartFresh);
          build(async);
          begin(async);
          settle(async, const Duration(seconds: 2));
          expect(controller.phase, phase, reason: '$answer');
          expect(controller.polling, isFalse);
          final before = polls();
          settle(async, const Duration(minutes: 1));
          expect(polls(), before);
          expect(controller.qr, isNull);
          controller.dispose();
        }
      });
    });

    test('an error status keeps the category and the server text', () {
      fakeAsync((async) {
        statusReply = (_) => _ok(waStatusErrorInstall);
        build(async);
        begin(async);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.failed);
        expect(controller.failReason, WhatsAppFailReason.installFailed);
        expect(controller.serverText?.text, isNotEmpty);
        expect(events.named('whatsapp.pair.ended'), [
          {'status': 'error'},
        ]);
      });
    });

    test('a failed poll keeps the state, flags it, and polls on', () {
      fakeAsync((async) {
        waiting(async);
        statusReply = down;
        settle(async, const Duration(seconds: 2));
        expect(controller.pollFailing, isTrue);
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        settle(async, const Duration(seconds: 6));
        expect(polls(), 5);
        statusReply = (_) => _ok(waStatusWaiting);
        settle(async, const Duration(seconds: 2));
        expect(controller.pollFailing, isFalse);
      });
    });

    test('a 5xx, a hung answer and a 401 are failed polls, never a sign-out '
        'or a bug report', () {
      fakeAsync((async) {
        final reported = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);
        waiting(async);
        for (final reply in <FutureOr<FakeResponse> Function(RequestOptions)>[
          (_) => (status: 503, body: 'down'),
          hang,
          (_) => (status: 401, body: waUnauthorized),
        ]) {
          statusReply = reply;
          settle(async, const Duration(seconds: 14));
          expect(controller.pollFailing, isTrue);
          expect(controller.phase, WhatsAppPairingPhase.waiting);
          expect(controller.closed, isFalse);
          statusReply = (_) => _ok(waStatusWaiting);
          settle(async, const Duration(seconds: 14));
          expect(controller.pollFailing, isFalse);
        }
        expect(reported, isEmpty);
      });
    });

    test('a 404 is the setup being gone', () {
      fakeAsync((async) {
        waiting(async);
        statusReply = (_) => (status: 404, body: waRecordGone);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.gone);
        expect(controller.goneDuringApply, isFalse);
        expect(controller.polling, isFalse);
        expect(controller.qr, isNull);
      });
    });

    test('a countdown that ran out while paused ends locally on return', () {
      fakeAsync((async) {
        waiting(async);
        controller.setInForeground(false);
        settle(async, const Duration(minutes: 11));
        final before = polls();
        controller.setInForeground(true);
        settle(async);
        expect(controller.phase, WhatsAppPairingPhase.expired);
        expect(polls(), before);
        expect(controller.polling, isFalse);
        expect(events.named('whatsapp.pair.ended'), [
          {'status': 'expired'},
        ]);
        expect(cancels(), 0);
      });
    });

    test('the time left counts down to the fixed deadline', () {
      fakeAsync((async) {
        waiting(async);
        expect(controller.timeLeft!.inSeconds, inInclusiveRange(596, 598));
        settle(async, const Duration(minutes: 1));
        expect(controller.timeLeft!.inSeconds, inInclusiveRange(536, 538));
      });
    });
  });

  group('the code', () {
    test('a handset needs the tap, and again after each hide', () {
      fakeAsync((async) {
        waiting(async, handset: true);
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.needsTap);
        expect(controller.qr, isNull);
        controller.revealQr();
        expect(controller.qr?.value, waQr);
        controller.setInForeground(false);
        expect(controller.qr, isNull);
        controller.setInForeground(true);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.needsTap);
        controller.revealQr();
        expect(controller.qr?.value, waQr);
        controller.cover();
        controller.uncover();
        settle(async);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.needsTap);
        controller.revealQr();
        expect(controller.qr?.value, waQr);
      });
    });

    test('the tap does nothing while hidden by the system', () {
      fakeAsync((async) {
        waiting(async, handset: true);
        controller.setInForeground(false);
        controller.revealQr();
        controller.setInForeground(true);
        expect(controller.qr, isNull);
      });
    });

    test('a computer shows it at once, hides it in the background and on '
        'losing focus, and shows it again when back', () {
      fakeAsync((async) {
        waiting(async);
        expect(controller.qr?.value, waQr);
        controller.setWindowFocused(false);
        expect(controller.qr, isNull);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.hidden);
        controller.setWindowFocused(true);
        expect(controller.qr?.value, waQr);
        controller.setInForeground(false);
        expect(controller.qr, isNull);
        controller.setInForeground(true);
        expect(controller.qr?.value, waQr);
      });
    });

    test('a handset ignores window focus', () {
      fakeAsync((async) {
        waiting(async, handset: true);
        controller.revealQr();
        controller.setWindowFocused(false);
        expect(controller.qr?.value, waQr);
      });
    });

    test('hideCode hides until revealQr, on a computer too', () {
      fakeAsync((async) {
        waiting(async);
        controller.hideCode();
        expect(controller.qr, isNull);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.needsTap);
        controller.revealQr();
        expect(controller.qr?.value, waQr);
      });
    });

    test(
      'App Lock drops the code from memory and the next read restores it',
      () {
        fakeAsync((async) {
          waiting(async);
          controller.cover();
          expect(controller.qr, isNull);
          expect(controller.codeVisibility, WhatsAppCodeVisibility.hidden);
          statusReply = (_) => _ok(waStatusWaitingRotated);
          controller.uncover();
          settle(async);
          expect(controller.qr?.value, contains('CCCC'));
        });
      },
    );

    test('App Lock drops the account and the server text, and the next read '
        'brings them back', () {
      fakeAsync((async) {
        linked(async);
        expect(controller.account?.phone, waPhone);
        statusReply = (_) => _ok(waStatusConnected);
        controller.cover();
        expect(controller.account, isNull);
        settle(async, const Duration(minutes: 1));
        expect(polls(), 0);
        controller.uncover();
        settle(async);
        expect(polls(), 1);
        expect(controller.account?.phone, waPhone);
        expect(controller.polling, isFalse);
        settle(async, const Duration(minutes: 1));
        expect(polls(), 1);
      });
    });

    test('a start answered while locked keeps no code', () {
      fakeAsync((async) {
        startReply = (_) => _ok(_payload(status: 'waiting', qr: waQr));
        build(async);
        unawaited(controller.start());
        controller.cover();
        settle(async);
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.qr, isNull);
        controller.uncover();
        settle(async);
        expect(controller.qr?.value, waQr);
      });
    });
  });

  group('Finish', () {
    test('asks first and sends nothing until confirmed', () {
      fakeAsync((async) {
        linked(async);
        expect(controller.canFinish, isTrue);
        expect(controller.requestFinish(), isTrue);
        expect(controller.applyStatus, WhatsAppApplyStatus.asking);
        settle(async, const Duration(minutes: 1));
        expect(applies(), 0);
        controller.cancelFinish();
        expect(controller.applyStatus, WhatsAppApplyStatus.idle);
        unawaited(controller.confirmFinish());
        settle(async);
        expect(applies(), 0, reason: 'confirm without a question is nothing');
      });
    });

    test('is offered only when connected', () {
      fakeAsync((async) {
        waiting(async);
        expect(controller.canFinish, isFalse);
        expect(controller.requestFinish(), isFalse);
        unawaited(controller.confirmFinish());
        settle(async);
        expect(applies(), 0);
      });
    });

    test('the confirmed apply goes once with the profile in query and body '
        'and keeps the numbers the start stored', () {
      fakeAsync((async) {
        startReply = (_) => _ok(waStartAlreadyLinked);
        build(async)
          ..setMode(WhatsAppMode.selfChat)
          ..setAllowedUsers('+15555550100');
        begin(async);
        finish(async);
        final request = server.requestsTo('POST', waApplyPath).single;
        expect(request.queryParameters, {'profile': _profile});
        final body = jsonBody(request)! as Map<String, Object?>;
        expect(body['profile'], _profile);
        expect(body['mode'], 'self-chat');
        expect(
          body.containsKey('allowed_users'),
          isFalse,
          reason: 'null keeps the list the start stored; "" would discard it',
        );
      });
    });

    test('saved with a restart requested', () {
      fakeAsync((async) {
        linked(async);
        finish(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.saved);
        expect(controller.restartRequested, isTrue);
        expect(controller.applyResult?.restartStarted, isTrue);
        expect(trail.named('whatsapp.pair.applied'), [
          {'restart': 'requested'},
        ]);
        final span = tracer.spans.last;
        expect(span.name, 'whatsapp.pair.apply');
        expect(span.attributes['outcome'], 'saved');
        expect(span.attributes['restart'], 'requested');
        expect(span.attributes['hermes.version'], '0.14.2');
      });
    });

    test('saved with the restart not started is not "requested"', () {
      fakeAsync((async) {
        applyReply = (_) => _ok(waApplyRestartFailed);
        linked(async);
        finish(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.saved);
        expect(controller.restartRequested, isFalse);
        expect(tracer.spans.last.attributes['restart'], 'not_requested');
      });
    });

    test('leaving after the save sends no cancel', () {
      fakeAsync((async) {
        linked(async);
        finish(async);
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 0);
      });
    });

    test('a second press while it runs sends nothing, and back is off', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        applyReply = (_) => gate.future;
        linked(async);
        expect(controller.requestFinish(), isTrue);
        unawaited(controller.confirmFinish());
        unawaited(controller.confirmFinish());
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.applying);
        expect(controller.requestFinish(), isFalse);
        expect(controller.canLeave, isFalse);
        unawaited(controller.leave());
        settle(async);
        expect(controller.closed, isFalse);
        expect(applies(), 1);
        gate.complete(_ok(waApplyRestartStarted));
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.saved);
        expect(controller.canLeave, isTrue);
        expect(applies(), 1);
      });
    });

    test('no answer for 10 s is a lost answer; nothing is resent and Finish '
        'is not offered again', () {
      fakeAsync((async) {
        applyReply = hang;
        linked(async);
        finish(async);
        settle(async, const Duration(seconds: 9));
        expect(controller.applyStatus, WhatsAppApplyStatus.applying);
        settle(async, const Duration(seconds: 2));
        expect(controller.applyStatus, WhatsAppApplyStatus.lostAnswer);
        settle(async, const Duration(minutes: 5));
        expect(applies(), 1);
        expect(controller.canFinish, isFalse);
        expect(controller.requestFinish(), isFalse);
        expect(controller.canCheck, isTrue);
        expect(controller.canLeave, isTrue);
        expect(tracer.spans.last.attributes['outcome'], 'lost_answer');
      });
    });

    test('a dropped connection and a 200 without ok are lost answers', () {
      fakeAsync((async) {
        applyReply = down;
        linked(async);
        finish(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.lostAnswer);
        controller.dispose();
        applyReply = (_) => _ok(const {'platform': 'whatsapp'});
        linked(async);
        finish(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.lostAnswer);
        expect(tracer.spans.last.attributes['outcome'], 'unconfirmed');
      });
    });

    test('leaving after a lost answer sends no cancel and no apply', () {
      fakeAsync((async) {
        applyReply = down;
        linked(async);
        finish(async);
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 0);
        expect(applies(), 1);
      });
    });

    test('Check finds WhatsApp enabled for the profile', () {
      fakeAsync((async) {
        applyReply = down;
        linked(async);
        finish(async);
        unawaited(controller.check());
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.checkEnabled);
        final request = server.requestsTo('GET', _platformsPath).single;
        expect(request.queryParameters, {'profile': _profile});
        expect(applies(), 1);
      });
    });

    test('Check finding it not enabled offers Start again, not Finish', () {
      fakeAsync((async) {
        applyReply = down;
        platformsReply = (_) => _ok(_platforms(enabled: false));
        linked(async);
        finish(async);
        unawaited(controller.check());
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.checkNotEnabled);
        expect(controller.canFinish, isFalse);
        expect(controller.canStartAgain, isTrue);
        controller.startAgain();
        expect(controller.phase, WhatsAppPairingPhase.setup);
        expect(controller.applyStatus, WhatsAppApplyStatus.idle);
      });
    });

    test('Check that cannot read ends in 10 s as not confirmed and may be '
        'pressed again; the apply stays unsent', () {
      fakeAsync((async) {
        applyReply = down;
        platformsReply = hang;
        linked(async);
        finish(async);
        unawaited(controller.check());
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.checking);
        expect(controller.canCheck, isFalse);
        settle(async, const Duration(seconds: 11));
        expect(controller.applyStatus, WhatsAppApplyStatus.checkFailed);
        platformsReply = (_) => (status: 500, body: 'x');
        expect(controller.canCheck, isTrue);
        unawaited(controller.check());
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.checkFailed);
        expect(applies(), 1);
      });
    });

    test('a refusal shows the text, stays, and Finish asks again', () {
      fakeAsync((async) {
        applyReply = (_) => (status: 409, body: waNotConnected);
        linked(async);
        finish(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.refused);
        expect(
          controller.applyFailure?.kind,
          WhatsAppPairingFailureKind.notConnected,
        );
        expect(
          controller.applyFailure?.serverText?.text,
          contains('connected'),
        );
        expect(controller.phase, WhatsAppPairingPhase.connected);
        settle(async, const Duration(minutes: 1));
        expect(applies(), 1);
        expect(controller.canFinish, isTrue);
        expect(controller.requestFinish(), isTrue);
        controller.cancelFinish();
        expect(controller.applyStatus, WhatsAppApplyStatus.refused);
      });
    });

    test('400 and 500 are refusals too', () {
      fakeAsync((async) {
        for (final (status, body) in <(int, Object)>[
          (400, waBadMode),
          (500, waSaveFailed),
        ]) {
          applyReply = (_) => (status: status, body: body);
          linked(async);
          finish(async);
          expect(controller.applyStatus, WhatsAppApplyStatus.refused);
          expect(controller.applyFailure?.serverText, isNotNull);
          controller.dispose();
        }
      });
    });

    test(
      'a 404 says the setup is gone while applying, and offers Start again',
      () {
        fakeAsync((async) {
          applyReply = (_) => (status: 404, body: waRecordGone);
          linked(async);
          finish(async);
          expect(controller.phase, WhatsAppPairingPhase.gone);
          expect(controller.goneDuringApply, isTrue);
          expect(controller.canStartAgain, isTrue);
          expect(applies(), 1);
          startReply = (_) => _ok(waStartAlreadyLinked);
          controller.startAgain();
          begin(async);
          expect(controller.phase, WhatsAppPairingPhase.connected);
          expect(controller.alreadyLinked, isTrue);
        });
      },
    );

    test('a 404 naming the profile is profileDeleted', () {
      fakeAsync((async) {
        applyReply = (_) => (status: 404, body: waProfileGone);
        linked(async);
        finish(async);
        expect(controller.phase, WhatsAppPairingPhase.profileDeleted);
      });
    });

    test('App Lock drops the question', () {
      fakeAsync((async) {
        linked(async);
        expect(controller.requestFinish(), isTrue);
        controller.cover();
        expect(controller.applyStatus, WhatsAppApplyStatus.idle);
        controller.uncover();
        settle(async);
        unawaited(controller.confirmFinish());
        settle(async);
        expect(applies(), 0);
      });
    });
  });

  group('leaving', () {
    test('while waiting sends one DELETE and drops the code and the id', () {
      fakeAsync((async) {
        waiting(async);
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 1);
        expect(controller.closed, isTrue);
        expect(controller.qr, isNull);
        unawaited(controller.leave());
        controller.dispose();
        settle(async, const Duration(minutes: 1));
        expect(cancels(), 1, reason: 'never twice');
        expect(polls(), 1, reason: 'and nothing polls any more');
        expect(events.named('whatsapp.pair.ended'), [
          {'status': 'cancelled'},
        ]);
      });
    });

    test('disposing is leaving', () {
      fakeAsync((async) {
        waiting(async);
        controller.dispose();
        settle(async);
        expect(cancels(), 1);
      });
    });

    test('a pairing that is already connected is dropped too, once', () {
      fakeAsync((async) {
        linked(async);
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 1);
      });
    });

    test('after a refusal the record is still live and is cancelled', () {
      fakeAsync((async) {
        applyReply = (_) => (status: 500, body: waSaveFailed);
        linked(async);
        finish(async);
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 1);
      });
    });

    test('an ended pairing has nothing to cancel', () {
      fakeAsync((async) {
        statusReply = (_) => _ok(waStatusErrorExited);
        build(async);
        begin(async);
        settle(async, const Duration(seconds: 2));
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 0);
      });
    });

    test('a failed cancel is ignored', () {
      fakeAsync((async) {
        for (final reply in <FutureOr<FakeResponse> Function(RequestOptions)>[
          down,
          (_) => (status: 500, body: 'x'),
          (_) => (status: 401, body: waUnauthorized),
          hang,
        ]) {
          cancelReply = reply;
          waiting(async);
          unawaited(controller.leave());
          settle(async, const Duration(seconds: 15));
          expect(controller.closed, isTrue);
          controller.dispose();
        }
      });
    });

    test('before a start answers, the pairing that began is cancelled when '
        'the answer comes', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        startReply = (_) => gate.future;
        build(async);
        unawaited(controller.start());
        settle(async);
        unawaited(controller.leave());
        settle(async);
        expect(cancels(), 0);
        gate.complete(_ok(waStartFresh));
        settle(async);
        expect(cancels(), 1);
        expect(polls(), 0);
      });
    });

    test('clear sends nothing and ignores late answers', () {
      fakeAsync((async) {
        waiting(async);
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        settle(async, const Duration(seconds: 2));
        controller.clear();
        expect(controller.closed, isTrue);
        expect(controller.qr, isNull);
        final seen = notified;
        gate.complete(_ok(waStatusConnectedAfterScan));
        settle(async, const Duration(minutes: 1));
        controller.dispose();
        settle(async);
        expect(cancels(), 0);
        expect(notified, seen);
        expect(controller.phase, isNot(WhatsAppPairingPhase.connected));
      });
    });

    test('nothing notifies after dispose', () {
      fakeAsync((async) {
        waiting(async);
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        settle(async, const Duration(seconds: 2));
        controller.dispose();
        gate.complete(_ok(waStatusConnectedAfterScan));
        settle(async, const Duration(minutes: 1));
      });
    });
  });

  group('state across App Lock and a lost apply', () {
    test('Finish is not offered while the read after unlock is out, and a '
        'saved apply never ends as gone', () {
      fakeAsync((async) {
        linked(async);
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        controller.cover();
        controller.uncover();
        settle(async);
        expect(controller.account, isNull);
        expect(controller.canFinish, isFalse);
        expect(controller.requestFinish(), isFalse);
        unawaited(controller.confirmFinish());
        settle(async);
        expect(applies(), 0);
        gate.complete(_ok(waStatusConnected));
        settle(async);
        expect(controller.account?.phone, waPhone);
        expect(controller.canFinish, isTrue);
      });
    });

    test('a poll still out when the apply is sent is ignored, and a 404 '
        'from it does not turn a saved apply into gone', () {
      fakeAsync((async) {
        linked(async);
        statusReply = (_) => _ok(waStatusConnected);
        controller.cover();
        controller.uncover();
        settle(async);
        // The refresh answered; now a connected record is not polled at all.
        settle(async, const Duration(minutes: 1));
        expect(polls(), 1);
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        finish(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.saved);
        gate.complete((status: 404, body: waRecordGone));
        settle(async, const Duration(minutes: 1));
        expect(controller.phase, WhatsAppPairingPhase.connected);
        expect(controller.applyStatus, WhatsAppApplyStatus.saved);
        expect(controller.canStartAgain, isFalse);
        expect(controller.polling, isFalse);
      });
    });

    test('a poll in flight when the apply is sent is discarded', () {
      fakeAsync((async) {
        waiting(async);
        statusReply = (_) => _ok(waStatusConnectedAfterScan);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.connected);
        // Cover and uncover leave a refresh read in flight.
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        controller.cover();
        controller.uncover();
        settle(async);
        gate.complete((status: 404, body: waRecordGone));
        settle(async);
        // The 404 of the read is a real "gone": nothing was applied.
        expect(controller.phase, WhatsAppPairingPhase.gone);
        expect(controller.goneDuringApply, isFalse);
      });
    });

    test('a connected record never expires locally on failed polls', () {
      fakeAsync((async) {
        linked(async);
        statusReply = down;
        controller.cover();
        controller.uncover();
        settle(async, const Duration(minutes: 11));
        expect(controller.pollFailing, isTrue);
        expect(controller.phase, WhatsAppPairingPhase.connected);
        statusReply = (_) => _ok(waStatusConnected);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.connected);
        expect(controller.account?.phone, waPhone);
      });
    });

    test('a failed record never expires locally on failed polls', () {
      fakeAsync((async) {
        statusReply = (_) => _ok(waStatusErrorInstall);
        build(async);
        begin(async);
        settle(async, const Duration(seconds: 2));
        controller.cover();
        statusReply = down;
        controller.uncover();
        settle(async, const Duration(minutes: 11));
        expect(controller.phase, WhatsAppPairingPhase.failed);
      });
    });

    test('a waiting record still expires locally on failed polls', () {
      fakeAsync((async) {
        waiting(async);
        statusReply = down;
        settle(async, const Duration(minutes: 11));
        expect(controller.phase, WhatsAppPairingPhase.expired);
      });
    });

    test('on a handset the next code after Start again needs the tap', () {
      fakeAsync((async) {
        waiting(async, handset: true);
        controller.revealQr();
        expect(controller.qr, isNotNull);
        statusReply = (_) => _ok(waStatusSuperseded);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.superseded);
        controller.startAgain();
        statusReply = (_) => _ok(waStatusWaiting);
        begin(async);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.needsTap);
        expect(controller.qr, isNull);
      });
    });

    test('a tap before there is a code to show reveals nothing', () {
      fakeAsync((async) {
        startReply = (_) => _ok(waStartFresh);
        statusReply = (_) => _ok(waStatusInstalling);
        build(async, handset: true);
        controller.revealQr();
        begin(async);
        controller.revealQr();
        statusReply = (_) => _ok(waStatusWaiting);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.needsTap);
        expect(controller.qr, isNull);
      });
    });

    test('an apply refused while covered is read again after unlock', () {
      fakeAsync((async) {
        linked(async);
        final gate = Completer<FakeResponse>();
        applyReply = (_) => gate.future;
        expect(controller.requestFinish(), isTrue);
        unawaited(controller.confirmFinish());
        settle(async);
        controller.cover();
        gate.complete((status: 409, body: waNotConnected));
        settle(async);
        expect(controller.applyStatus, WhatsAppApplyStatus.refused);
        expect(controller.account, isNull);
        expect(controller.debugHeld.serverText, isFalse);
        statusReply = (_) => _ok(waStatusConnected);
        controller.uncover();
        settle(async);
        expect(polls(), 1);
        expect(controller.account?.phone, waPhone);
        expect(controller.canFinish, isTrue);
      });
    });

    test('a lost apply stops the polling and a late poll is ignored', () {
      fakeAsync((async) {
        applyReply = hang;
        waiting(async);
        statusReply = (_) => _ok(waStatusConnectedAfterScan);
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.connected);
        // A poll from a refresh is out when the apply goes.
        controller.cover();
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        controller.uncover();
        settle(async);
        statusReply = (_) => _ok(waStatusConnectedAfterScan);
        gate.complete(_ok(waStatusConnectedAfterScan));
        settle(async);
        finish(async);
        settle(async, const Duration(seconds: 10));
        expect(controller.applyStatus, WhatsAppApplyStatus.lostAnswer);
        expect(controller.polling, isFalse);
        final before = polls();
        statusReply = (_) => (status: 404, body: waRecordGone);
        settle(async, const Duration(minutes: 1));
        expect(polls(), before);
        expect(controller.phase, WhatsAppPairingPhase.connected);
        expect(controller.applyStatus, WhatsAppApplyStatus.lostAnswer);
      });
    });

    test('a hung apply adopts no 404 from an earlier poll as gone', () {
      fakeAsync((async) {
        waiting(async);
        statusReply = (_) => _ok(waStatusConnectedAfterScan);
        settle(async, const Duration(seconds: 2));
        controller.cover();
        final gate = Completer<FakeResponse>();
        statusReply = (_) => gate.future;
        controller.uncover();
        settle(async);
        gate.complete(_ok(waStatusConnectedAfterScan));
        settle(async);
        applyReply = hang;
        final poll = Completer<FakeResponse>();
        statusReply = (_) => poll.future;
        finish(async);
        poll.complete((status: 404, body: waRecordGone));
        settle(async, const Duration(seconds: 10));
        expect(controller.phase, WhatsAppPairingPhase.connected);
        expect(controller.applyStatus, WhatsAppApplyStatus.lostAnswer);
      });
    });

    test('a computer-class window of handset size still hides on focus loss, '
        'a phone does not', () {
      fakeAsync((async) {
        waiting(async);
        controller.dispose();
        build(async, handset: true, followsWindowFocus: true);
        begin(async);
        settle(async, const Duration(seconds: 2));
        controller.revealQr();
        expect(controller.qr, isNotNull);
        controller.setWindowFocused(false);
        expect(controller.qr, isNull);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.hidden);
        controller.setWindowFocused(true);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.shown);
      });
    });

    test('canStart is false while covered', () {
      fakeAsync((async) {
        build(async);
        expect(controller.canStart, isTrue);
        controller.cover();
        expect(controller.canStart, isFalse);
        unawaited(controller.start());
        settle(async);
        expect(starts(), 0);
        controller.uncover();
        expect(controller.canStart, isTrue);
      });
    });

    test('a waiting record with no code held is hidden, not shown', () {
      fakeAsync((async) {
        waiting(async);
        controller.cover();
        statusReply = down;
        controller.uncover();
        settle(async, const Duration(seconds: 2));
        expect(controller.phase, WhatsAppPairingPhase.waiting);
        expect(controller.pollFailing, isTrue);
        expect(controller.qr, isNull);
        expect(controller.codeVisibility, WhatsAppCodeVisibility.hidden);
        expect(controller.debugHeld.code, isFalse);
      });
    });

    test('App Lock really drops the code, the id stays for polling', () {
      fakeAsync((async) {
        waiting(async);
        expect(controller.debugHeld.code, isTrue);
        controller.cover();
        expect(controller.debugHeld.code, isFalse);
        expect(controller.debugHeld.id, isTrue);
        statusReply = down;
        controller.uncover();
        settle(async, const Duration(seconds: 2));
        expect(controller.qr, isNull);
        expect(controller.debugHeld.code, isFalse);
      });
    });

    test('App Lock drops the server text of a failed pairing and of a '
        'refused apply and start', () {
      fakeAsync((async) {
        statusReply = (_) => _ok(waStatusErrorInstall);
        build(async);
        begin(async);
        settle(async, const Duration(seconds: 2));
        expect(controller.debugHeld.serverText, isTrue);
        controller.cover();
        expect(controller.serverText, isNull);
        expect(controller.debugHeld.serverText, isFalse);
      });
      fakeAsync((async) {
        applyReply = (_) => (status: 409, body: waNotConnected);
        linked(async);
        finish(async);
        expect(controller.debugHeld.serverText, isTrue);
        controller.cover();
        expect(controller.applyFailure, isNull);
        expect(controller.debugHeld.serverText, isFalse);
      });
      fakeAsync((async) {
        startReply = (_) => (status: 500, body: waSaveFailed);
        build(async);
        begin(async);
        expect(controller.startFailure?.serverText, isNotNull);
        controller.cover();
        expect(controller.startFailure, isNull);
        expect(controller.debugHeld.serverText, isFalse);
      });
    });

    test('closing drops the id, the code and the text', () {
      for (final close in <void Function()>[
        () => controller.clear(),
        () => controller.dispose(),
        () => unawaited(controller.leave()),
      ]) {
        fakeAsync((async) {
          waiting(async);
          expect(controller.debugHeld.id, isTrue);
          expect(controller.debugHeld.code, isTrue);
          close();
          settle(async);
          expect(controller.debugHeld, (
            code: false,
            id: false,
            serverText: false,
          ));
        });
      }
    });

    test('a late answer to a lost start after clear sends no cancel', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        startReply = (_) => gate.future;
        build(async);
        unawaited(controller.start());
        settle(async, const Duration(seconds: 10));
        expect(controller.phase, WhatsAppPairingPhase.startLost);
        controller.clear();
        gate.complete(_ok(waStartFresh));
        settle(async, const Duration(minutes: 1));
        expect(cancels(), 0);
        expect(polls(), 0);
      });
    });

    test('Finish is not offered while covered', () {
      fakeAsync((async) {
        linked(async);
        statusReply = (_) => _ok(waStatusConnected);
        expect(controller.canFinish, isTrue);
        controller.cover();
        expect(controller.canFinish, isFalse);
        expect(controller.requestFinish(), isFalse);
        controller.uncover();
        expect(controller.canFinish, isFalse, reason: 'the read is not in');
        settle(async);
        expect(controller.canFinish, isTrue);
      });
    });
  });

  group('telemetry', () {
    test('the spans, events and crumbs the proposal names', () {
      fakeAsync((async) {
        waiting(async);
        controller.open();
        expect(
          tracer.spans.map((s) => s.name),
          contains('whatsapp.pair.start'),
        );
        expect(tracer.spans.first.attributes['outcome'], 'started');
        expect(tracer.spans.first.attributes['hermes.version'], '0.14.2');
        expect(tracer.spans.first.ended, isTrue);
        statusReply = (_) => _ok(waStatusConnectedAfterScan);
        settle(async, const Duration(seconds: 2));
        expect(events.named('whatsapp.pair.ended'), [
          {'status': 'connected'},
        ]);
        finish(async);
        expect(trail.named('whatsapp.pair.opened'), hasLength(1));
      });
    });

    test('ended says connected, error, expired and superseded as words', () {
      fakeAsync((async) {
        final answers = <FakeResponse>[
          _ok(waStatusConnectedAfterScan),
          _ok(waStatusErrorNode),
          (status: 410, body: waExpiredBody),
          _ok(waStatusSuperseded),
        ];
        for (final answer in answers) {
          statusReply = (_) => answer;
          build(async);
          begin(async);
          settle(async, const Duration(seconds: 2));
          controller.dispose();
        }
        expect(events.named('whatsapp.pair.ended').map((e) => e['status']), [
          'connected',
          'error',
          'expired',
          'superseded',
        ]);
      });
    });

    test('start spans carry fixed outcome words', () {
      fakeAsync((async) {
        final cases =
            <(FutureOr<FakeResponse> Function(RequestOptions), String)>[
              ((_) => _ok(waStartAlreadyLinked), 'already_linked'),
              (down, 'lost_answer'),
              ((_) => (status: 404, body: waProfileGone), 'profile_gone'),
              ((_) => (status: 404, body: waRouteMissing), 'unsupported'),
              ((_) => (status: 400, body: waBadMode), 'refused'),
            ];
        for (final (reply, outcome) in cases) {
          startReply = reply;
          build(async);
          begin(async);
          expect(tracer.spans.last.attributes['outcome'], outcome);
          controller.dispose();
        }
      });
    });

    test('a bug in the repository is reported and the screen leaves the '
        'spinner', () {
      fakeAsync((async) {
        final reported = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);
        build(async, repository: _Broken(server.client().raw));
        begin(async);
        expect(controller.phase, isNot(WhatsAppPairingPhase.starting));
        expect(reported, isNotEmpty);
        expect(reported.single.context.toString(), contains('whatsapp.pair'));
      });
    });
  });

  group('privacy', () {
    const qrMarker = 'QRPAYLOADMARKER-9f3';
    const idMarker = 'PairingIdMARKER_77x';
    const numberMarker = '15557771234';
    const accountMarker = 'AccountNameMARKER';
    const textMarker = 'ServerTextMARKER /srv/hermes/private';
    const profileMarker = 'profilemarker';
    const markers = [
      qrMarker,
      idMarker,
      numberMarker,
      accountMarker,
      textMarker,
      'ServerTextMARKER',
      profileMarker,
    ];

    test('none of them reaches a span, a log, a breadcrumb, an exception or '
        'a bug report', () {
      fakeAsync((async) {
        final logger = _RecordingLogger();
        final dio = server.dio()
          ..interceptors.add(httpInterceptor(logger, tracer));
        final reported = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);

        final statusPath = '$waBase/$idMarker';
        final applyPath = '$statusPath/apply';
        var phase = 'waiting';
        server
          ..onRequest(
            'POST',
            waStartPath,
            (_) => _ok(_payload(id: idMarker, status: 'starting')),
          )
          ..onRequest('GET', statusPath, (_) {
            return switch (phase) {
              'waiting' => _ok(
                _payload(id: idMarker, status: 'waiting', qr: qrMarker),
              ),
              'connected' => _ok(
                _payload(
                  id: idMarker,
                  status: 'connected',
                  accountName: accountMarker,
                  accountPhone: numberMarker,
                ),
              ),
              'error' => _ok(
                _payload(id: idMarker, status: 'error', error: textMarker),
              ),
              _ => (status: 401, body: waUnauthorized),
            };
          })
          ..onRequest(
            'POST',
            applyPath,
            (_) => (status: 500, body: {'detail': textMarker}),
          )
          ..onRequest('DELETE', statusPath, (_) => _ok(waCancelOk));

        build(
          async,
          handset: false,
          repository: HermesMessagingRepository(HermesApiClient(dio).raw),
          profile: profileMarker,
        );
        controller
          ..open()
          ..setAllowedUsers('+$numberMarker');
        begin(async);
        settle(async, const Duration(seconds: 2));
        expect(controller.qr?.value, qrMarker);
        controller
          ..cover()
          ..uncover();
        settle(async, const Duration(seconds: 2));
        controller.setWindowFocused(false);
        controller.setWindowFocused(true);
        phase = 'unauthorized';
        settle(async, const Duration(seconds: 2));
        phase = 'connected';
        settle(async, const Duration(seconds: 2));
        expect(controller.account?.name, accountMarker);
        finish(async);
        expect(controller.applyFailure?.serverText?.text, textMarker);
        unawaited(controller.leave());
        settle(async);

        // A failed run too, and its text.
        phase = 'error';
        build(
          async,
          repository: HermesMessagingRepository(HermesApiClient(dio).raw),
          profile: profileMarker,
        );
        begin(async);
        settle(async, const Duration(seconds: 2));
        expect(controller.serverText?.text, textMarker);
        controller.dispose();
        settle(async);

        final seen = [
          for (final s in tracer.spans) ...[
            s.name,
            ...s.attributes.keys,
            ...s.attributes.values.map((v) => '$v'),
            ...s.events,
            ...s.eventDetails,
            '${s.statusDescription}',
          ],
          for (final r in logger.records) ...[
            r.body,
            ...r.attributes.values.map((v) => '$v'),
          ],
          trail.text,
          for (final name in events.namesStartingWith('')) name,
          for (final e in events.namesStartingWith('whatsapp'))
            '${events.named(e)}',
          for (final d in reported) '${d.exception} ${d.stack} ${d.context}',
          controller.toString(),
        ].join('\n');
        for (final marker in markers) {
          expect(seen, isNot(contains(marker)), reason: marker);
        }
        expect(
          tracer.spans
              .where((s) => s.attributes['http.route'] != null)
              .map((s) => s.attributes['http.route'])
              .toSet(),
          {'/api/messaging'},
        );
        expect(
          tracer.spans.map((s) => s.name),
          contains('whatsapp.pair.apply'),
        );
      });
    });

    test('the breadcrumb trail holds only the fixed names', () {
      fakeAsync((async) {
        startReply = (_) => _ok(waStartFresh);
        statusReply = (_) => _ok(waStatusWaiting);
        build(async)
          ..open()
          ..open();
        begin(async);
        settle(async, const Duration(seconds: 2));
        controller
          ..setInForeground(false)
          ..setInForeground(true);
        settle(async);
        statusReply = (_) => _ok(waStatusConnectedAfterScan);
        settle(async, const Duration(seconds: 2));
        finish(async);
        expect(
          [for (final (name, _) in trail.all) name],
          [
            'whatsapp.pair.opened',
            'whatsapp.pair.qr_shown',
            'whatsapp.pair.qr_shown',
            'whatsapp.pair.applied',
          ],
        );
      });
    });
  });
}

/// A repository whose start has a bug: not a failed request.
class _Broken extends HermesMessagingRepository {
  _Broken(super.api);

  @override
  HermesMessagingRepository forProfile(String? profile) => this;

  @override
  Future<WhatsAppPairingStart> startWhatsAppPairing({
    required WhatsAppMode mode,
    String? allowedUsers,
  }) => throw StateError('a bug');
}
