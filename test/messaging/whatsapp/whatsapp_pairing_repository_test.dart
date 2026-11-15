import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/whatsapp/whatsapp_pairing.dart';

import '../../support/fake_hermes_server.dart';
import 'whatsapp_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late HermesMessagingRepository repository;
  const id = WhatsAppPairingId(waId);

  setUp(() {
    server = FakeHermesServer();
    repository = HermesMessagingRepository(
      server.client().raw,
      profile: 'atlas',
    );
  });

  Future<WhatsAppPairingFailureKind> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on WhatsAppPairingFailure catch (failure) {
      return failure.kind;
    }
    fail('expected a WhatsAppPairingFailure');
  }

  DioException connectionLoss(RequestOptions request) =>
      DioException.connectionError(requestOptions: request, reason: 'down');

  group('start', () {
    test('sends mode, allowed_users and profile, once', () async {
      server.on('POST', waStartPath, waStartFresh);
      await repository.startWhatsAppPairing(
        mode: WhatsAppMode.selfChat,
        allowedUsers: '+15555550100',
      );
      final request = server.requests.single;
      expect(request.path, waStartPath);
      expect(request.queryParameters, isEmpty);
      expect(jsonBody(request), {
        'mode': 'self-chat',
        'allowed_users': '+15555550100',
        'profile': 'atlas',
      });
    });

    test('without a profile or numbers sends only the mode', () async {
      server.on('POST', waStartPath, waStartFresh);
      await HermesMessagingRepository(server.client().raw)
          .startWhatsAppPairing(mode: WhatsAppMode.bot);
      expect(jsonBody(server.requests.single), {'mode': 'bot'});
    });

    test('a fresh start is working, with the id and the deadline', () async {
      server.on('POST', waStartPath, waStartFresh);
      final started = await repository.startWhatsAppPairing(
        mode: WhatsAppMode.bot,
      );
      expect(started.id, const WhatsAppPairingId(waId));
      expect(
        started.snapshot.state,
        const WhatsAppWorking(WhatsAppWorkStage.starting),
      );
      expect(started.snapshot.expiresAt, DateTime.utc(2026, 11, 15, 12, 10));
    });

    test('an already linked folder is connected with the account', () async {
      server.on('POST', waStartPath, waStartAlreadyLinked);
      final started = await repository.startWhatsAppPairing(
        mode: WhatsAppMode.bot,
      );
      final state = started.snapshot.state;
      expect(state, isA<WhatsAppConnected>());
      final account = (state as WhatsAppConnected).account;
      expect(account.name, waAccountName);
      expect(account.phone, waPhone);
    });

    test('404 about the profile is profileGone', () async {
      server.on('POST', waStartPath, waProfileGone, status: 404);
      expect(
        await failureOf(
          repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
        ),
        WhatsAppPairingFailureKind.profileGone,
      );
    });

    test('any other 404, and a 405, is unsupported', () async {
      for (final (status, body) in <(int, Object?)>[
        (404, waRouteMissing),
        (404, {'error': 'x'}),
        (404, 'Not Found'),
        (405, {'detail': 'Method Not Allowed'}),
      ]) {
        server.on('POST', waStartPath, body, status: status);
        expect(
          await failureOf(
            repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
          ),
          WhatsAppPairingFailureKind.unsupported,
          reason: '$status $body',
        );
      }
    });

    test('refusals and errors map to their kinds', () async {
      final cases = <(int, Object?, WhatsAppPairingFailureKind)>[
        (400, waBadMode, WhatsAppPairingFailureKind.badRequest),
        (400, waProfileBadName, WhatsAppPairingFailureKind.badRequest),
        (422, waValidation, WhatsAppPairingFailureKind.validation),
        (500, waSaveFailed, WhatsAppPairingFailureKind.server),
        (503, 'down', WhatsAppPairingFailureKind.server),
        (418, 'tea', WhatsAppPairingFailureKind.unexpected),
      ];
      for (final (status, body, kind) in cases) {
        server.on('POST', waStartPath, body, status: status);
        expect(
          await failureOf(
            repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
          ),
          kind,
          reason: '$status',
        );
      }
    });

    test('the detail of a 400, 409 or 500 is kept for the screen', () async {
      for (final (status, body) in <(int, Map<String, Object?>)>[
        (400, waBadMode),
        (400, waProfileBadName),
        (500, waSaveFailed),
      ]) {
        server.on('POST', waStartPath, body, status: status);
        try {
          await repository.startWhatsAppPairing(mode: WhatsAppMode.bot);
          fail('expected a failure');
        } on WhatsAppPairingFailure catch (failure) {
          expect(failure.serverText?.text, body['detail']);
          expect('$failure', isNot(contains('a b')));
          expect(failure.message, isNot(contains(body['detail'] as String)));
        }
      }
    });

    test('a detail that is not a string, or a 404, keeps no text', () async {
      for (final (status, body) in <(int, Object?)>[
        (422, waValidation),
        (400, {'detail': 5}),
        (400, {'detail': ''}),
        (404, waProfileGone),
        (503, {'detail': 'down'}),
      ]) {
        server.on('POST', waStartPath, body, status: status);
        try {
          await repository.startWhatsAppPairing(mode: WhatsAppMode.bot);
          fail('expected a failure');
        } on WhatsAppPairingFailure catch (failure) {
          expect(failure.serverText, isNull, reason: '$status');
        }
      }
    });

    test('a lost answer is lostAnswer and is not sent again', () async {
      server.onRequest('POST', waStartPath, (r) => throw connectionLoss(r));
      expect(
        await failureOf(
          repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
        ),
        WhatsAppPairingFailureKind.lostAnswer,
      );
      expect(server.requests, hasLength(1));
    });

    test('a 200 that does not parse is lostAnswer too', () async {
      server.onRequest(
        'POST',
        waStartPath,
        (r) => throw DioException(
          requestOptions: r,
          error: const FormatException('bad json'),
        ),
      );
      expect(
        await failureOf(
          repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
        ),
        WhatsAppPairingFailureKind.lostAnswer,
      );
      expect(server.requests, hasLength(1));
    });

    test('a 200 without a pairing id is malformed', () async {
      for (final body in <Object?>[
        {'status': 'starting'},
        {'pairing_id': 5, 'status': 'starting'},
        {'pairing_id': '', 'status': 'starting'},
        'plain',
        null,
      ]) {
        server.on('POST', waStartPath, body);
        expect(
          await failureOf(
            repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
          ),
          WhatsAppPairingFailureKind.malformed,
          reason: '$body',
        );
      }
    });

    test('a profile that cannot be one is refused without a request', () async {
      for (final name in ['', '.', '..', 'a/b', 'a?b', 'a#b', 'a%b', 'a\nb']) {
        expect(
          await failureOf(
            HermesMessagingRepository(
              server.client().raw,
              profile: name,
            ).startWhatsAppPairing(mode: WhatsAppMode.bot),
          ),
          WhatsAppPairingFailureKind.badRequest,
          reason: name,
        );
      }
      expect(server.requests, isEmpty);
    });

    test('a 401 is rethrown for the sign-in path', () async {
      server.on('POST', waStartPath, waUnauthorized, status: 401);
      await expectLater(
        repository.startWhatsAppPairing(mode: WhatsAppMode.bot),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
    });
  });

  group('status', () {
    Future<WhatsAppPairingState> stateOf(Object? body) async {
      server.on('GET', waStatusPath, body);
      return (await repository.whatsAppPairingStatus(id)).state;
    }

    test('puts the id in the path and sends no query or body', () async {
      server.on('GET', waStatusPath, waStatusWaiting);
      await repository.whatsAppPairingStatus(id);
      final request = server.requests.single;
      expect(request.path, waStatusPath);
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
    });

    test('installing and starting are working', () async {
      expect(
        await stateOf(waStatusInstalling),
        const WhatsAppWorking(WhatsAppWorkStage.installing),
      );
      expect(
        await stateOf(waStatusStarting),
        const WhatsAppWorking(WhatsAppWorkStage.starting),
      );
    });

    test('waiting carries the code', () async {
      final state = await stateOf(waStatusWaiting);
      expect(state, isA<WhatsAppWaitingForScan>());
      expect((state as WhatsAppWaitingForScan).qr.value, waQr);
      final rotated = await stateOf(waStatusWaitingRotated);
      expect((rotated as WhatsAppWaitingForScan).qr.value, isNot(waQr));
    });

    test('waiting without a code is still working', () async {
      for (final qr in <Object?>[null, '', 5]) {
        expect(
          await stateOf({...waStatusWaiting, 'qr_payload': qr}),
          const WhatsAppWorking(WhatsAppWorkStage.starting),
          reason: '$qr',
        );
      }
    });

    test('connected carries the account', () async {
      final state = await stateOf(waStatusConnectedAfterScan);
      final account = (state as WhatsAppConnected).account;
      expect(account.id, waAccountId);
      expect(account.name, waAccountName);
      expect(account.phone, waPhone);
    });

    test('connected is lenient about missing account fields', () async {
      final state = await stateOf({
        'pairing_id': waId,
        'status': 'connected',
        'account_name': 5,
      });
      final account = (state as WhatsAppConnected).account;
      expect((account.id, account.name, account.phone), (null, null, null));
    });

    test('an unknown or missing status is working', () async {
      expect(
        await stateOf(waStatusUnknown),
        const WhatsAppWorking(WhatsAppWorkStage.other),
      );
      expect(
        await stateOf({'pairing_id': waId}),
        const WhatsAppWorking(WhatsAppWorkStage.other),
      );
    });

    test('an error is a fixed category, never the server text', () async {
      final cases = {
        waStatusErrorNode: WhatsAppFailReason.nodeUnavailable,
        waStatusErrorInstall: WhatsAppFailReason.installFailed,
        waStatusErrorBridge: WhatsAppFailReason.bridgeMissing,
        waStatusErrorExited: WhatsAppFailReason.processExited,
        waStatusErrorOther: WhatsAppFailReason.other,
        {'pairing_id': waId, 'status': 'error'}: WhatsAppFailReason.other,
      };
      for (final MapEntry(key: body, value: reason) in cases.entries) {
        final state = await stateOf(body);
        expect(state, WhatsAppPairingFailed(reason), reason: '$body');
        expect('$state', isNot(contains('/srv')));
        expect('$state', isNot(contains('5555')));
      }
    });

    test(
      'the server text is kept for the screen, hidden from output',
      () async {
        server.on('GET', waStatusPath, waStatusErrorOther);
        final state =
            (await repository.whatsAppPairingStatus(id)).state
                as WhatsAppPairingFailed;
        expect(
          state.serverText?.text,
          'Something at /srv/x went wrong for +15555550123.',
        );
        expect('${state.serverText}', 'WhatsAppServerText(<hidden>)');
      },
    );

    test('an error without text has no server text', () async {
      server.on('GET', waStatusPath, {'pairing_id': waId, 'status': 'error'});
      final state =
          (await repository.whatsAppPairingStatus(id)).state
              as WhatsAppPairingFailed;
      expect(state.serverText, isNull);
    });

    test('a body naming another pairing is malformed, id not echoed', () async {
      for (final other in <Object?>['someone-else', 5, null]) {
        server.on('GET', waStatusPath, {
          ...waStatusWaiting,
          'pairing_id': other,
        });
        try {
          await repository.whatsAppPairingStatus(id);
          fail('expected a failure');
        } on WhatsAppPairingFailure catch (failure) {
          expect(failure.kind, WhatsAppPairingFailureKind.malformed);
          expect('$failure${failure.message}', isNot(contains('someone')));
        }
      }
    });

    test('a body without a pairing id is read as it is', () async {
      server.on('GET', waStatusPath, {'status': 'starting'});
      expect(
        (await repository.whatsAppPairingStatus(id)).state,
        const WhatsAppWorking(WhatsAppWorkStage.starting),
      );
    });

    test('cancelled is superseded', () async {
      expect(
        await stateOf(waStatusSuperseded),
        const WhatsAppPairingSuperseded(),
      );
    });

    test('an expired status in a 200 and a 410 are both expired', () async {
      expect(
        await stateOf({...waStatusStarting, 'status': 'expired'}),
        const WhatsAppPairingExpired(),
      );
      server.on('GET', waStatusPath, waExpiredBody, status: 410);
      expect(
        (await repository.whatsAppPairingStatus(id)).state,
        const WhatsAppPairingExpired(),
      );
    });

    test('404 is recordGone, even with a route-missing body', () async {
      for (final body in <Object?>[waRecordGone, waRouteMissing, 'Not Found']) {
        server.on('GET', waStatusPath, body, status: 404);
        expect(
          await failureOf(repository.whatsAppPairingStatus(id)),
          WhatsAppPairingFailureKind.recordGone,
          reason: '$body',
        );
      }
    });

    test('other statuses map to their kinds', () async {
      final cases = {
        405: WhatsAppPairingFailureKind.unsupported,
        500: WhatsAppPairingFailureKind.server,
        502: WhatsAppPairingFailureKind.server,
        418: WhatsAppPairingFailureKind.unexpected,
      };
      for (final MapEntry(key: status, value: kind) in cases.entries) {
        server.on('GET', waStatusPath, 'x', status: status);
        expect(
          await failureOf(repository.whatsAppPairingStatus(id)),
          kind,
          reason: '$status',
        );
      }
    });

    test('connection loss is unreachable, apart from a refusal', () async {
      server.onRequest('GET', waStatusPath, (r) => throw connectionLoss(r));
      expect(
        await failureOf(repository.whatsAppPairingStatus(id)),
        WhatsAppPairingFailureKind.unreachable,
      );
    });

    test('a body that is not an object is malformed', () async {
      for (final body in <Object?>[
        ['x'],
        'plain',
        null,
      ]) {
        server.on('GET', waStatusPath, body);
        expect(
          await failureOf(repository.whatsAppPairingStatus(id)),
          WhatsAppPairingFailureKind.malformed,
          reason: '$body',
        );
      }
    });

    test('a 401 is rethrown', () async {
      server.on('GET', waStatusPath, waUnauthorized, status: 401);
      await expectLater(
        repository.whatsAppPairingStatus(id),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('the id as one path segment', () {
    test('odd ids are refused without a request', () async {
      for (final value in [
        '',
        '.',
        '..',
        'a/b',
        '../x',
        'a?x=1',
        'a#b',
        '%2F',
        'a b',
        'a\nb',
      ]) {
        final odd = WhatsAppPairingId(value);
        expect(
          await failureOf(repository.whatsAppPairingStatus(odd)),
          WhatsAppPairingFailureKind.badRequest,
          reason: 'status "$value"',
        );
        expect(
          await failureOf(repository.applyWhatsAppPairing(odd)),
          WhatsAppPairingFailureKind.badRequest,
          reason: 'apply "$value"',
        );
        expect(
          await failureOf(repository.cancelWhatsAppPairing(odd)),
          WhatsAppPairingFailureKind.badRequest,
          reason: 'cancel "$value"',
        );
      }
      expect(server.requests, isEmpty);
    });

    test('a url-safe id is sent as one segment', () async {
      server.on('GET', '$waBase/Ab_-9', {
        ...waStatusWaiting,
        'pairing_id': 'Ab_-9',
      });
      await repository.whatsAppPairingStatus(const WhatsAppPairingId('Ab_-9'));
      final uri = server.requests.single.uri;
      expect(uri.pathSegments, [
        'api',
        'messaging',
        'whatsapp',
        'onboarding',
        'Ab_-9',
      ]);
    });
  });

  group('apply', () {
    test('sends the profile in the query and in the body', () async {
      server.on('POST', waApplyPath, waApplyRestartStarted);
      await repository.applyWhatsAppPairing(
        id,
        mode: WhatsAppMode.bot,
        allowedUsers: '+15555550100',
      );
      final request = server.requests.single;
      expect(request.path, waApplyPath);
      expect(request.queryParameters, {'profile': 'atlas'});
      expect(jsonBody(request), {
        'mode': 'bot',
        'allowed_users': '+15555550100',
        'profile': 'atlas',
      });
    });

    test('without a profile sends neither, and omits unset fields', () async {
      server.on('POST', waApplyPath, waApplyRestartStarted);
      await HermesMessagingRepository(server.client().raw)
          .applyWhatsAppPairing(id);
      final request = server.requests.single;
      expect(request.queryParameters, isEmpty);
      expect(jsonBody(request), <String, Object?>{});
    });

    test('a started restart is reported as such', () async {
      server.on('POST', waApplyPath, waApplyRestartStarted);
      final result = await repository.applyWhatsAppPairing(id);
      expect(
        (result.confirmed, result.restartStarted, result.needsRestart),
        (true, true, false),
      );
    });

    test('a failed restart still saved, and needs one', () async {
      server.on('POST', waApplyPath, waApplyRestartFailed);
      final result = await repository.applyWhatsAppPairing(id);
      expect(
        (result.confirmed, result.restartStarted, result.needsRestart),
        (true, false, true),
      );
    });

    test('a 200 without ok: true is not confirmed', () async {
      for (final body in <Object?>[
        {'ok': false},
        <String, Object?>{},
        'fine',
        null,
      ]) {
        server.on('POST', waApplyPath, body);
        final result = await repository.applyWhatsAppPairing(id);
        expect(result.confirmed, isFalse, reason: '$body');
        expect(result.restartStarted, isFalse);
        expect(result.needsRestart, isTrue);
      }
    });

    test('refusals map to their kinds', () async {
      final cases = <(int, Object?, WhatsAppPairingFailureKind)>[
        (404, waRecordGone, WhatsAppPairingFailureKind.recordGone),
        (404, waRouteMissing, WhatsAppPairingFailureKind.recordGone),
        (404, waProfileGone, WhatsAppPairingFailureKind.profileGone),
        (409, waNotConnected, WhatsAppPairingFailureKind.notConnected),
        (410, waExpiredBody, WhatsAppPairingFailureKind.expired),
        (400, waBadMode, WhatsAppPairingFailureKind.badRequest),
        (422, waValidation, WhatsAppPairingFailureKind.validation),
        (500, waSaveFailed, WhatsAppPairingFailureKind.server),
        (405, 'no', WhatsAppPairingFailureKind.unsupported),
      ];
      for (final (status, body, kind) in cases) {
        server.on('POST', waApplyPath, body, status: status);
        expect(
          await failureOf(repository.applyWhatsAppPairing(id)),
          kind,
          reason: '$status $body',
        );
      }
    });

    test('the detail of a 400, 409 or 500 is kept for the screen', () async {
      for (final (status, body) in <(int, Map<String, Object?>)>[
        (400, waBadMode),
        (409, waNotConnected),
        (500, waSaveFailed),
      ]) {
        server.on('POST', waApplyPath, body, status: status);
        try {
          await repository.applyWhatsAppPairing(id);
          fail('expected a failure');
        } on WhatsAppPairingFailure catch (failure) {
          expect(failure.serverText?.text, body['detail']);
          expect('$failure ${failure.message}', isNot(contains('setup')));
        }
      }
    });

    test('a lost answer is lostAnswer and is never resent', () async {
      server.onRequest('POST', waApplyPath, (r) => throw connectionLoss(r));
      expect(
        await failureOf(repository.applyWhatsAppPairing(id)),
        WhatsAppPairingFailureKind.lostAnswer,
      );
      expect(server.requests, hasLength(1));
    });

    test('a 401 is rethrown', () async {
      server.on('POST', waApplyPath, waUnauthorized, status: 401);
      await expectLater(
        repository.applyWhatsAppPairing(id),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('cancel', () {
    test('deletes the record, with no profile', () async {
      server.on('DELETE', waStatusPath, waCancelOk);
      await repository.cancelWhatsAppPairing(id);
      final request = server.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, waStatusPath);
      expect(request.queryParameters, isEmpty);
    });

    test('a 404 is as good as done', () async {
      server.on('DELETE', waStatusPath, waRecordGone, status: 404);
      await repository.cancelWhatsAppPairing(id);
    });

    test('no answer is unreachable and nothing is resent', () async {
      server.onRequest('DELETE', waStatusPath, (r) => throw connectionLoss(r));
      expect(
        await failureOf(repository.cancelWhatsAppPairing(id)),
        WhatsAppPairingFailureKind.unreachable,
      );
      expect(server.requests, hasLength(1));
    });

    test('a 500 is the server kind, a 401 is rethrown', () async {
      server.on('DELETE', waStatusPath, 'x', status: 500);
      expect(
        await failureOf(repository.cancelWhatsAppPairing(id)),
        WhatsAppPairingFailureKind.server,
      );
      server.on('DELETE', waStatusPath, waUnauthorized, status: 401);
      await expectLater(
        repository.cancelWhatsAppPairing(id),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('nothing sensitive leaks', () {
    test('the id and the code have a fixed toString', () {
      expect('$id', isNot(contains(waId)));
      const qr = WhatsAppQrPayload(waQr);
      expect('$qr', isNot(contains('DEMO')));
      expect('${WhatsAppWaitingForScan(qr)}', isNot(contains('DEMO')));
      const account = WhatsAppLinkedAccount(
        id: waAccountId,
        name: waAccountName,
        phone: waPhone,
      );
      expect(
        '$account',
        allOf(isNot(contains(waPhone)), isNot(contains('Test'))),
      );
      expect(
        '${const WhatsAppConnected(account)}',
        allOf(isNot(contains(waPhone)), isNot(contains('Test'))),
      );
    });

    test(
      'failures carry a kind and no text of the server or the app',
      () async {
        server.on('POST', waStartPath, waProfileBadName, status: 400);
        try {
          await repository.startWhatsAppPairing(mode: WhatsAppMode.bot);
          fail('expected a failure');
        } on WhatsAppPairingFailure catch (failure) {
          for (final text in ['$failure', failure.message]) {
            expect(text, isNot(contains('a b')));
            expect(text, isNot(contains('atlas')));
          }
        }
        server.on('GET', waStatusPath, waRecordGone, status: 404);
        try {
          await repository.whatsAppPairingStatus(id);
          fail('expected a failure');
        } on WhatsAppPairingFailure catch (failure) {
          expect('$failure', isNot(contains(waId)));
          expect(failure.message, isNot(contains('Start a new setup')));
        }
      },
    );

    test('the holder prints a fixed string and its text only on .text', () {
      const held = WhatsAppServerText('/srv/secret 5555');
      expect('$held', 'WhatsAppServerText(<hidden>)');
      expect(held, const WhatsAppServerText('/srv/secret 5555'));
      const failed = WhatsAppPairingFailed(
        WhatsAppFailReason.other,
        serverText: held,
      );
      const failure = WhatsAppPairingFailure(
        WhatsAppPairingFailureKind.server,
        serverText: held,
      );
      for (final text in ['$failed', '$failure', failure.message]) {
        expect(text, allOf(isNot(contains('/srv')), isNot(contains('5555'))));
      }
      expect(failed, const WhatsAppPairingFailed(WhatsAppFailReason.other));
    });

    test('a refused answer is not echoed in a state either', () async {
      server.on('GET', waStatusPath, waStatusErrorOther);
      final snapshot = await repository.whatsAppPairingStatus(id);
      expect('$snapshot', isNot(contains('5555')));
      expect('$snapshot', isNot(contains('/srv')));
    });
  });

  group('error categories', () {
    test('match the server opening words, status prefix optional', () {
      final cases = {
        '500: Node.js preparation failed: x':
            WhatsAppFailReason.nodeUnavailable,
        'Node.js preparation failed: x': WhatsAppFailReason.nodeUnavailable,
        'npm install failed for WhatsApp bridge: x':
            WhatsAppFailReason.installFailed,
        '500: npm install failed: needs a newer version of node.js':
            WhatsAppFailReason.installFailed,
        '500: Installing WhatsApp bridge dependencies timed out':
            WhatsAppFailReason.installFailed,
        'Failed to install WhatsApp bridge dependencies.':
            WhatsAppFailReason.installFailed,
        '500: Installing WhatsApp bridge dependencies failed on node.js 12':
            WhatsAppFailReason.installFailed,
        'WhatsApp bridge script was not found at /x.':
            WhatsAppFailReason.bridgeMissing,
        '500: WhatsApp bridge script was not found at /x.':
            WhatsAppFailReason.bridgeMissing,
        'WhatsApp pairing process exited with code 1.':
            WhatsAppFailReason.processExited,
        'WhatsApp pairing process exited before pairing completed.':
            WhatsAppFailReason.processExited,
        'logged_out': WhatsAppFailReason.loggedOut,
        'Something else': WhatsAppFailReason.other,
        '': WhatsAppFailReason.other,
      };
      for (final MapEntry(key: text, value: reason) in cases.entries) {
        expect(whatsAppFailReason(text), reason, reason: text);
      }
      expect(whatsAppFailReason(null), WhatsAppFailReason.other);
    });
  });
}
