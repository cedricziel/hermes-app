import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/bots/hermes_bots_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesBotsRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesBotsRepository(server.client().raw);
  });

  group('load', () {
    test('maps each messaging platform to a bot', () async {
      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'telegram',
            name: 'Telegram',
            description: 'Run Hermes from Telegram.',
            enabled: true,
            configured: true,
            state: 'connected',
          ),
          platformRow(id: 'whatsapp', name: 'WhatsApp'),
        ]),
      );

      final bots = await repository.load();

      expect(bots.map((b) => b.id), ['telegram', 'whatsapp']);
      final telegram = bots.first;
      expect(telegram.name, 'Telegram');
      expect(telegram.description, 'Run Hermes from Telegram.');
      expect(telegram.enabled, isTrue);
      expect(telegram.configured, isTrue);
      expect(telegram.state, 'connected');
      expect(bots.last.enabled, isFalse);
      expect(bots.last.configured, isFalse);
    });

    test('carries a platform\'s error message', () async {
      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'telegram',
            name: 'Telegram',
            enabled: true,
            configured: true,
            state: 'error',
            errorMessage: 'Invalid bot token',
          ),
        ]),
      );

      final bots = await repository.load();

      expect(bots.single.errorMessage, 'Invalid bot token');
    });

    test('maps each platform\'s setup variables', () async {
      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'telegram',
            name: 'Telegram',
            envVars: [
              envVarRow(
                key: 'TELEGRAM_BOT_TOKEN',
                prompt: 'Telegram bot token',
                required: true,
                isSet: true,
                redactedValue: '1234...wxyz',
                description: 'Token from @BotFather',
                help: 'Paste the whole token',
                isPassword: true,
              ),
              envVarRow(key: 'TELEGRAM_ALLOWED_USERS', advanced: true),
            ],
          ),
        ]),
      );

      final vars = (await repository.load()).single.envVars;

      expect(vars.map((v) => v.key), [
        'TELEGRAM_BOT_TOKEN',
        'TELEGRAM_ALLOWED_USERS',
      ]);
      final token = vars.first;
      expect(token.label, 'Telegram bot token');
      expect(token.description, 'Token from @BotFather');
      expect(token.help, 'Paste the whole token');
      expect(token.required, isTrue);
      expect(token.isSet, isTrue);
      expect(token.redactedValue, '1234...wxyz');
      expect(token.isPassword, isTrue);
      expect(token.advanced, isFalse);
      expect(vars.last.isSet, isFalse);
      expect(vars.last.redactedValue, isNull);
      expect(vars.last.advanced, isTrue);
    });

    test('skips setup variables without a key', () async {
      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'telegram',
            name: 'Telegram',
            envVars: [
              envVarRow(key: 'TELEGRAM_BOT_TOKEN'),
              {'prompt': 'no key'},
            ],
          ),
        ]),
      );

      final bots = await repository.load();

      expect(bots.single.envVars.map((v) => v.key), ['TELEGRAM_BOT_TOKEN']);
    });

    test('returns no bots for an unexpected body', () async {
      server.on('GET', '/api/messaging/platforms', {'platforms': 'nope'});

      expect(await repository.load(), isEmpty);
    });

    test('surfaces a server error as a DioException', () async {
      server.on('GET', '/api/messaging/platforms', {
        'detail': 'boom',
      }, status: 500);

      expect(repository.load(), throwsA(isA<DioException>()));
    });
  });

  group('saveSetup', () {
    test('puts the values and the keys to clear, and nothing else', () async {
      server.on('PUT', '/api/messaging/platforms/telegram', {'ok': true});

      await repository.saveSetup(
        'telegram',
        env: {'TELEGRAM_BOT_TOKEN': '123456789:abc'},
        clear: ['TELEGRAM_ALLOWED_USERS'],
      );

      final request = server
          .requestsTo('PUT', '/api/messaging/platforms/telegram')
          .single;
      expect(jsonBody(request), {
        'env': {'TELEGRAM_BOT_TOKEN': '123456789:abc'},
        'clear_env': ['TELEGRAM_ALLOWED_USERS'],
      });
    });

    test('reports the reason the dashboard rejects a value', () async {
      server.on('PUT', '/api/messaging/platforms/telegram', {
        'detail': 'Telegram bot token must be the complete token',
      }, status: 400);

      expect(
        repository.saveSetup('telegram', env: {'TELEGRAM_BOT_TOKEN': 'abc'}),
        throwsA(
          isA<BotSetupRejected>().having(
            (e) => e.message,
            'message',
            'Telegram bot token must be the complete token',
          ),
        ),
      );
    });

    test('surfaces any other failure as a DioException', () async {
      server.on('PUT', '/api/messaging/platforms/telegram', {
        'detail': 'boom',
      }, status: 500);

      expect(
        repository.saveSetup('telegram', env: {'TELEGRAM_BOT_TOKEN': 'x'}),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('Telegram pairing', () {
    const start = '/api/messaging/telegram/onboarding/start';
    const pairing = '/api/messaging/telegram/onboarding/p1';

    test('starts a pairing and returns the link to open', () async {
      server.on('POST', start, telegramPairingStartBody());

      final started = await repository.startTelegramPairing();

      expect(started.id, 'p1');
      expect(started.deepLink, 'https://t.me/HermesBot?start=pair_p1');
      expect(jsonBody(server.requestsTo('POST', start).single), isEmpty);
    });

    test('refuses a start response without a pairing id or link', () async {
      server.on('POST', start, {'suggested_username': 'x'});

      expect(
        repository.startTelegramPairing(),
        throwsA(isA<FormatException>()),
      );
    });

    test('reports the setup service being unavailable', () async {
      server.on('POST', start, {
        'detail': 'Telegram setup service is unavailable. Try again shortly.',
      }, status: 502);

      expect(
        repository.startTelegramPairing(),
        throwsA(
          isA<BotSetupRejected>().having(
            (e) => e.message,
            'message',
            contains('unavailable'),
          ),
        ),
      );
    });

    test('a pairing nobody claimed yet is not ready', () async {
      server.on('GET', pairing, {
        'status': 'waiting',
        'expires_at': '2026-09-19T10:57:52.075Z',
      });

      final status = await repository.telegramPairingStatus('p1');

      expect(status.ready, isFalse);
      expect(status.botUsername, isNull);
    });

    test('a claimed pairing carries the bot and its owner', () async {
      server.on('GET', pairing, {
        'status': 'ready',
        'bot_username': 'hermes_1_bot',
        'owner_user_id': '4711',
        'expires_at': '2026-09-19T10:57:52.075Z',
      });

      final status = await repository.telegramPairingStatus('p1');

      expect(status.ready, isTrue);
      expect(status.botUsername, 'hermes_1_bot');
      expect(status.ownerUserId, '4711');
    });

    test('an expired pairing says so', () async {
      server.on('GET', pairing, {
        'detail': 'Telegram setup expired. Start a new setup.',
      }, status: 410);

      expect(
        repository.telegramPairingStatus('p1'),
        throwsA(
          isA<BotSetupRejected>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );
    });

    test('applying sends the allowed user ids', () async {
      server.on('POST', '$pairing/apply', {'ok': true});

      await repository.applyTelegramPairing('p1', ['4711', '42']);

      expect(jsonBody(server.requestsTo('POST', '$pairing/apply').single), {
        'allowed_user_ids': ['4711', '42'],
      });
    });

    test('applying reports why the dashboard refuses', () async {
      server.on('POST', '$pairing/apply', {
        'detail': 'Allowed Telegram user IDs must be numeric.',
      }, status: 400);

      expect(
        repository.applyTelegramPairing('p1', ['abc']),
        throwsA(isA<BotSetupRejected>()),
      );
    });

    test('cancelling drops the pairing', () async {
      server.on('DELETE', pairing, {'ok': true});

      await repository.cancelTelegramPairing('p1');

      expect(server.requestsTo('DELETE', pairing), hasLength(1));
    });
  });

  group('setEnabled', () {
    test('puts the new enabled flag on that platform', () async {
      server.on('PUT', '/api/messaging/platforms/telegram', {'ok': true});

      await repository.setEnabled('telegram', true);

      final request = server
          .requestsTo('PUT', '/api/messaging/platforms/telegram')
          .single;
      expect((jsonBody(request) as Map)['enabled'], isTrue);
    });

    test('surfaces a rejected change as a DioException', () async {
      server.on('PUT', '/api/messaging/platforms/telegram', {
        'detail': 'nope',
      }, status: 400);

      expect(
        repository.setEnabled('telegram', true),
        throwsA(isA<DioException>()),
      );
    });
  });
}
