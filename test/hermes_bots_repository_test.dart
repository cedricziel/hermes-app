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
