import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/native_login_flow.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';
import 'support/recorded_events.dart';

/// A gated dashboard offering one provider, with nobody signed in. Its
/// `/api/auth/me` answers with [me] and [meStatus] once [meGate] completes.
Future<HttpServer> _startDashboard({
  Object? me,
  int meStatus = 200,
  Future<void>? meGate,
  List<String?>? meAuthorization,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final isMe = request.uri.path == '/api/auth/me';
    if (isMe) {
      meAuthorization?.add(request.headers.value('authorization'));
      await meGate;
    }
    final body = switch (request.uri.path) {
      '/api/auth/me' => me,
      '/api/status' => {
        'auth_required': true,
        'auth_flows': ['native_pkce'],
      },
      '/api/auth/providers' => {
        'providers': [
          {'name': 'oidc', 'display_name': 'Company SSO'},
        ],
      },
      _ => null,
    };
    request.response
      ..statusCode = isMe
          ? meStatus
          : body == null
          ? 404
          : 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body ?? {}))
      ..close();
  });
  return server;
}

/// A [MemoryTokenStore] whose writes wait for [writeGate].
class _GatedTokenStore extends MemoryTokenStore {
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();

  @override
  Future<void> write(HermesSession next) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    await super.write(next);
  }
}

void main() {
  late HttpServer dashboard;
  late RecordedEvents events;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    events = RecordedEvents();
  });

  tearDown(() => dashboard.close(force: true));

  Future<AuthController> controllerWith(NativeLogin login) async {
    dashboard = await _startDashboard();
    final controller = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: 'http://127.0.0.1:${dashboard.port}',
      login: login,
      events: events.call,
    );
    await controller.bootstrap();
    expect(controller.state, HermesConnectionState.needsLogin);
    return controller;
  }

  test('cancelling returns to the login screen and is recorded', () async {
    final controller = await controllerWith((
      url, {
      provider,
      httpClient,
      cancelled,
    }) async {
      await cancelled;
      throw const NativeLoginCancelled();
    });

    final signIn = controller.signInWithProvider(controller.providers.single);
    expect(controller.state, HermesConnectionState.signingIn);
    controller.cancelSignIn();
    await signIn;

    expect(controller.state, HermesConnectionState.needsLogin);
    expect(events.namesStartingWith('auth.sign_in.'), [
      'auth.sign_in.started',
      'auth.sign_in.cancelled',
    ]);
  });

  test('a cancel that lands after the login returned discards it and stops the spinner', () async {
    final store = MemoryTokenStore();
    dashboard = await _startDashboard();
    final controller = AuthController(
      tokenStore: store,
      devServerUrl: 'http://127.0.0.1:${dashboard.port}',
      login: (url, {provider, httpClient, cancelled}) async {
        await cancelled;
        return const HermesSession(
          accessToken: 'at',
          refreshToken: 'rt',
          expiresAt: 4102444800,
          provider: 'oidc',
          userId: 'u1',
        );
      },
      events: events.call,
    );
    await controller.bootstrap();

    final signIn = controller.signInWithProvider(controller.providers.single);
    controller.cancelSignIn();
    await signIn;

    expect(controller.state, HermesConnectionState.needsLogin);
    expect(controller.errorMessage, isNull);
    expect(store.session, isNull);
    expect(events.namesStartingWith('auth.sign_in.'), [
      'auth.sign_in.started',
      'auth.sign_in.cancelled',
    ]);
  });

  test(
    'a flow failure shows its message and records only the reason',
    () async {
      final controller = await controllerWith(
        (url, {provider, httpClient, cancelled}) async =>
            throw NativeLoginException(
              'Sign-in timed out. Please try again.',
              reason: NativeLoginFailure.timeout,
            ),
      );

      await controller.signInWithProvider(controller.providers.single);

      expect(controller.state, HermesConnectionState.needsLogin);
      expect(controller.errorMessage, 'Sign-in timed out. Please try again.');
      final failed = events.named('auth.sign_in.failed').single;
      expect(failed['reason'], 'timeout');
      expect(failed.keys, isNot(contains('message')));
    },
  );

  test('an unexpected error cannot leave the spinner running', () async {
    final controller = await controllerWith(
      (url, {provider, httpClient, cancelled}) async =>
          throw PlatformException(code: 'closed'),
    );

    await controller.signInWithProvider(controller.providers.single);

    expect(controller.state, HermesConnectionState.needsLogin);
    final failed = events.named('auth.sign_in.failed').single;
    expect(failed['reason'], 'unexpected');
    expect(failed['exception.type'], 'PlatformException');
  });

  test(
    'a sign-in that finishes after the server was changed is discarded',
    () async {
      final finish = Completer<void>();
      final store = MemoryTokenStore();
      dashboard = await _startDashboard();
      final controller = AuthController(
        tokenStore: store,
        devServerUrl: 'http://127.0.0.1:${dashboard.port}',
        login: (url, {provider, httpClient, cancelled}) async {
          await finish.future;
          return const HermesSession(
            accessToken: 'at',
            refreshToken: 'rt',
            expiresAt: 4102444800,
            provider: 'oidc',
            userId: 'u1',
          );
        },
        events: events.call,
      );
      await controller.bootstrap();

      final signIn = controller.signInWithProvider(controller.providers.single);
      await controller.changeServer();
      finish.complete();
      await signIn;

      expect(controller.state, HermesConnectionState.needsServerUrl);
      expect(store.session, isNull);
    },
  );

  group('when /api/auth/me does not confirm a fresh sign-in', () {
    const session = HermesSession(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: 4102444800,
      provider: 'oidc',
      userId: 'u1',
    );

    late MemoryTokenStore store;

    Future<AuthController> signInAgainst({
      Object? me,
      int meStatus = 200,
      Future<void>? meGate,
      List<String?>? meAuthorization,
      MemoryTokenStore? tokenStore,
    }) async {
      store = tokenStore ?? MemoryTokenStore();
      dashboard = await _startDashboard(
        me: me,
        meStatus: meStatus,
        meGate: meGate,
        meAuthorization: meAuthorization,
      );
      final controller = AuthController(
        tokenStore: store,
        devServerUrl: 'http://127.0.0.1:${dashboard.port}',
        login: (url, {provider, httpClient, cancelled}) async => session,
        events: events.call,
      );
      await controller.bootstrap();
      return controller;
    }

    test('stores the session once the identity loads', () async {
      final controller = await signInAgainst(me: {'user_id': 'u1'});

      await controller.signInWithProvider(controller.providers.single);

      expect(controller.state, HermesConnectionState.ready);
      expect(controller.identity?.userId, 'u1');
      expect(store.session, session);
      expect(events.named('auth.sign_in.succeeded'), hasLength(1));
    });

    test('checks the identity with the new access token', () async {
      final authorization = <String?>[];
      final controller = await signInAgainst(
        me: {'user_id': 'u1'},
        meAuthorization: authorization,
      );

      await controller.signInWithProvider(controller.providers.single);

      expect(authorization, ['Bearer at']);
    });

    test('a server error is reported and nothing is stored', () async {
      final controller = await signInAgainst(
        me: {'detail': 'Profile store is down'},
        meStatus: 500,
      );

      await controller.signInWithProvider(controller.providers.single);

      expect(controller.state, HermesConnectionState.needsLogin);
      expect(controller.errorMessage, 'Profile store is down');
      expect(store.session, isNull);
      expect(
        events.named('auth.sign_in.failed').single['reason'],
        'profile_load',
      );
    });

    test('a rejected token is reported and nothing is stored', () async {
      final controller = await signInAgainst(
        me: {'detail': 'Not authenticated'},
        meStatus: 401,
      );

      await controller.signInWithProvider(controller.providers.single);

      expect(controller.state, HermesConnectionState.needsLogin);
      expect(controller.errorMessage, 'Not authenticated');
      expect(store.session, isNull);
    });

    test('a malformed body is reported and nothing is stored', () async {
      final controller = await signInAgainst(me: [1]);

      await controller.signInWithProvider(controller.providers.single);

      expect(controller.state, HermesConnectionState.needsLogin);
      expect(controller.errorMessage, 'Unexpected response from the server');
      expect(store.session, isNull);
      final failed = events.named('auth.sign_in.failed').single;
      expect(failed['reason'], 'profile_load');
    });

    test(
      'leaving the server while the identity loads stores nothing',
      () async {
        final gate = Completer<void>();
        final controller = await signInAgainst(
          me: {'user_id': 'u1'},
          meGate: gate.future,
        );

        final signIn = controller.signInWithProvider(
          controller.providers.single,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await controller.changeServer();
        gate.complete();
        await signIn;

        expect(controller.state, HermesConnectionState.needsServerUrl);
        expect(store.session, isNull);
      },
    );

    test(
      'leaving the server while the session is being stored keeps nothing',
      () async {
        final gated = _GatedTokenStore()..writeGate = Completer<void>();
        final controller = await signInAgainst(
          me: {'user_id': 'u1'},
          tokenStore: gated,
        );

        final signIn = controller.signInWithProvider(
          controller.providers.single,
        );
        await gated.writeStarted.future;
        final leaving = controller.changeServer();
        gated.writeGate!.complete();
        await Future.wait([signIn, leaving]);

        expect(controller.state, HermesConnectionState.needsServerUrl);
        expect(controller.identity, isNull);
        expect(store.session, isNull);
      },
    );
  });
}
