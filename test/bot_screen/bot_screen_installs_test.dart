import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_otel/flutter_otel.dart' show noopAppEventLogger;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/install/bot_screen_installs.dart';
import 'package:hermes_app/src/bot_screen/install/install_state.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_gateway.dart';
import '../support/recording_tracer.dart';
import 'bot_screen_repository_test.dart' show statusJson;

const _key = '/home/u/.hermes/profiles/work';
const _command = 'sudo apt-get install -y tigervnc-standalone-server';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late BotScreenInstalls installs;
  late FakeAsync async;
  late RecordingTracer tracer;
  final logged = <String>[];
  final asked = <String>[];
  final askedProfiles = <String>[];

  /// What the password prompt answers; null is Cancel.
  String? password = 'hunter2';

  /// Held back to keep the prompt open.
  Completer<String?>? holdPrompt;

  void settle() => async.flushMicrotasks();

  void log(String line, {String key = _key}) {
    gateway.event('display.install.log', '', {
      'profile_key': key,
      'line': line,
    });
    settle();
  }

  void done(int code, {String key = _key, Map<String, Object?>? status}) {
    gateway.event('display.install.done', '', {
      'profile_key': key,
      'code': code,
      'status': status ?? statusJson(extra: {'installed': code == 0}),
    });
    settle();
  }

  Map<String, Object?> sudoAnswer(String id) =>
      gateway.responses.firstWhere((r) => r['id'] == id);

  void sudo(String id, {String key = _key}) {
    gateway.serverRequest(id, 'display.install.sudo', '', {'profile_key': key});
    settle();
  }

  InstallState? stateOf([String profile = 'work']) =>
      installs.stateFor(profile);

  /// The JSON-RPC error code the app answered the request with.
  int? errorCode(String id) =>
      ((sudoAnswer(id)['error'] as Map?)?['code']) as int?;

  const notRequested = -32602;
  const methodNotFound = -32601;
  const internalError = -32603;

  ConnectionTelemetry telemetryOf() => ConnectionTelemetry(
    tracer: tracer,
    events: (name, [attributes = const {}]) => logged.add('$name $attributes'),
    serverAttributes: const {'hermes.version': '0.22.0'},
  );

  BotScreenInstalls makeInstalls(SudoPasswordAsker askPassword) =>
      BotScreenInstalls(
        repository: BotScreenRepository(
          transport.requestKeepingConnection,
          installRpc: transport.requestKeepingConnectionOnClient,
          telemetry: telemetryOf(),
        ),
        connectionEvents: transport.connectionEvents,
        registerServerRequestHandler: transport.registerServerRequestHandler,
        askPassword: askPassword,
        host: 'hermes.example.com',
        telemetry: telemetryOf(),
      );

  Future<String?> defaultAsk(String host, String profile, Future<void> ended) {
    asked.add(host);
    askedProfiles.add(profile);
    if (holdPrompt case final hold?) return hold.future;
    return Future.value(password);
  }

  /// Runs [body] under fake time with the installs of a gateway whose
  /// `display.install` starts the install of profile `work`.
  void scenario(void Function() body, {bool transportTelemetry = false}) {
    fakeAsync((zone) {
      async = zone;
      logged.clear();
      asked.clear();
      askedProfiles.clear();
      password = 'hunter2';
      holdPrompt = null;
      tracer = RecordingTracer();
      gateway = FakeGateway();
      gateway.handlers['display.install'] = (_) => {
        'started': true,
        'command': _command,
        'profile_key': _key,
      };
      gateway.handlers['display.status'] = (_) =>
          statusJson(extra: {'installed': false});
      transport = HermesGatewayTransport(
        connect: gateway.connect,
        telemetry: transportTelemetry ? telemetryOf().gateway() : null,
        events: transportTelemetry ? telemetryOf().events : noopAppEventLogger,
      );
      installs = makeInstalls(defaultAsk);
      try {
        body();
      } finally {
        installs.dispose();
        transport.close();
        settle();
      }
    });
  }

  /// Presses Install on Server for `work` and lets the answer arrive.
  void install() {
    installs.start('work', profileKey: _key);
    settle();
  }

  test('Install on Server sends display.install for the profile', () {
    scenario(() {
      install();

      expect(gateway.requestOf('display.install')['params'], {
        'profile': 'work',
      });
      expect(stateOf(), isA<InstallRunning>());
      expect(stateOf('other'), isNull);
    });
  });

  test('a second press while one runs sends nothing', () {
    scenario(() {
      install();
      install();

      expect(
        gateway.methods.where((m) => m == 'display.install'),
        hasLength(1),
      );
    });
  });

  test('a refusal becomes a result with the server\'s message', () {
    scenario(() {
      gateway.handlers['display.install'] = (_) =>
          throw const FakeRpcError(5300, 'an install is already running');

      install();

      final state = stateOf() as InstallEnded;
      final result = state.result as InstallRefused;
      expect(result.message, 'an install is already running');
      expect(logged.single, startsWith('bot_screen.install'));
    });
  });

  test('log lines of its key keep the last 6, other keys are ignored', () {
    scenario(() {
      install();

      for (var i = 1; i <= 8; i++) {
        log('line $i');
      }
      log('someone else', key: '/other');

      final running = stateOf() as InstallRunning;
      expect(running.lines, [for (var i = 3; i <= 8; i++) 'line $i']);
    });
  });

  group('done', () {
    test('0 ends as installed, carrying the fresh status', () {
      scenario(() {
        install();

        done(0);

        final ended = stateOf() as InstallEnded;
        expect(ended.result, isA<InstallInstalled>());
        expect(ended.status?.installed, isTrue);
      });
    });

    test('-1 is cancelled', () {
      scenario(() {
        install();
        done(-1);

        expect((stateOf() as InstallEnded).result, isA<InstallCancelled>());
      });
    });

    test('-2 is no sudo, with the status\' install command', () {
      scenario(() {
        install();
        done(
          -2,
          status: statusJson(
            extra: {'installed': false, 'install_command': _command},
          ),
        );

        final result = (stateOf() as InstallEnded).result as InstallNoSudo;
        expect(result.command, _command);
      });
    });

    test('-2 falls back to the command the install started with', () {
      scenario(() {
        install();
        done(-2, status: statusJson(extra: {'installed': false}));

        final result = (stateOf() as InstallEnded).result as InstallNoSudo;
        expect(result.command, _command);
      });
    });

    test('any other code failed, with the last lines', () {
      scenario(() {
        install();
        log('E: unable to locate package');
        done(100);

        final result = (stateOf() as InstallEnded).result as InstallFailed;
        expect(result.lines, ['E: unable to locate package']);
      });
    });

    test('for another key changes nothing', () {
      scenario(() {
        install();
        done(0, key: '/other');

        expect(stateOf(), isA<InstallRunning>());
      });
    });

    test('before the answer to display.install still ends it', () {
      scenario(() {
        gateway.silent.add('display.install');
        installs.start('work', profileKey: _key);
        settle();
        log('early');
        done(0);

        expect(stateOf(), isA<InstallEnded>());

        gateway.replyTo(gateway.requestOf('display.install'), {
          'started': true,
          'profile_key': _key,
        });
        settle();

        expect(stateOf(), isA<InstallEnded>());
      });
    });
  });

  group('the sudo password', () {
    test('a request for a running install shows the prompt and answers the '
        'value once', () {
      scenario(() {
        install();

        sudo('srq-1');

        expect(asked, ['hermes.example.com']);
        expect(sudoAnswer('srq-1')['result'], {'value': 'hunter2'});
        expect((stateOf() as InstallRunning).askedPassword, isTrue);
        expect(gateway.responses, hasLength(1));
      });
    });

    test('Cancel answers an empty value', () {
      scenario(() {
        password = null;
        install();

        sudo('srq-1');

        expect(sudoAnswer('srq-1')['result'], {'value': ''});
      });
    });

    test('a request for another key is refused and shows nothing', () {
      scenario(() {
        install();

        sudo('srq-1', key: '/other');

        expect(asked, isEmpty);
        expect(errorCode('srq-1'), notRequested);
      });
    });

    test('a request while nothing installs is refused at once', () {
      scenario(() {
        gateway.handlers['display.status'] = (_) => statusJson();
        transport.request('display.status');
        settle();

        sudo('srq-1');

        expect(asked, isEmpty);
        expect(errorCode('srq-1'), methodNotFound);
      });
    });

    test('a request while a prompt is open is refused', () {
      scenario(() {
        holdPrompt = Completer<String?>();
        install();

        sudo('srq-1');
        sudo('srq-2');

        expect(asked, hasLength(1));
        expect(errorCode('srq-2'), notRequested);
        expect(gateway.responses.where((r) => r['id'] == 'srq-1'), isEmpty);

        holdPrompt!.complete('pw');
        settle();

        expect(sudoAnswer('srq-1')['result'], {'value': 'pw'});
      });
    });

    test('the prompt is told when the install ends first', () {
      scenario(() {
        Future<void>? ended;
        installs.dispose();
        installs = makeInstalls((host, profile, signal) {
          ended = signal;
          return Completer<String?>().future;
        });
        install();
        sudo('srq-1');
        var closed = false;
        ended!.then((_) => closed = true);

        done(-1);

        expect(closed, isTrue);
      });
    });

    test('after the install ended, a request is refused again', () {
      scenario(() {
        install();
        done(0);

        sudo('srq-1');

        expect(asked, isEmpty);
        expect(errorCode('srq-1'), methodNotFound);
      });
    });

    test('a request on another connection is refused', () {
      scenario(() {
        install();
        gateway.drop();
        settle();
        // The status read after the loss reconnects.
        async.elapse(const Duration(seconds: 1));

        sudo('srq-1');

        expect(asked, isEmpty);
        expect(errorCode('srq-1'), notRequested);
      });
    });

    test('the question names the host and the profile', () {
      scenario(() {
        install();

        sudo('srq-1');

        expect(asked, ['hermes.example.com']);
        expect(askedProfiles, ['work']);
      });
    });

    test('a request that arrives before the answer to display.install waits '
        'for the connection to be known, then is answered', () {
      scenario(() {
        gateway.silent.add('display.install');
        installs.start('work', profileKey: _key);
        settle();

        sudo('srq-1');
        expect(asked, isEmpty);
        expect(gateway.responses, isEmpty);

        gateway.replyTo(gateway.requestOf('display.install'), {
          'started': true,
          'command': _command,
          'profile_key': _key,
        });
        settle();

        expect(asked, hasLength(1));
        expect(sudoAnswer('srq-1')['result'], {'value': 'hunter2'});
      });
    });

    test('a refused install does not leave a waiting request unanswered', () {
      scenario(() {
        gateway.silent.add('display.install');
        installs.start('work', profileKey: _key);
        settle();
        sudo('srq-1');

        gateway.replyTo(gateway.requestOf('display.install'), {
          'started': true,
          'profile_key': '/not/the/key',
        });
        settle();

        expect(asked, isEmpty);
        expect(errorCode('srq-1'), notRequested);
      });
    });

    test('the same request id again while its prompt is open is refused and '
        'leaves the prompt alone', () {
      scenario(() {
        holdPrompt = Completer<String?>();
        install();

        sudo('srq-1');
        sudo('srq-1');

        expect(asked, hasLength(1));
        final answers = gateway.responses.where((r) => r['id'] == 'srq-1');
        expect(answers, hasLength(1));
        expect((answers.single['error'] as Map)['code'], notRequested);

        holdPrompt!.complete('pw');
        settle();

        expect(
          gateway.responses.where((r) => r['result'] != null).single['result'],
          {'value': 'pw'},
        );
      });
    });

    test('two profiles can be asked at once, each answered on its own '
        'request', () {
      scenario(() {
        final holds = <String, Completer<String?>>{};
        installs.dispose();
        installs = makeInstalls((host, profile, ended) {
          askedProfiles.add(profile);
          return (holds[profile] = Completer<String?>()).future;
        });
        gateway.handlers['display.install'] = (params) => {
          'started': true,
          'command': _command,
          'profile_key': '/keys/${params['profile']}',
        };
        installs.start('work', profileKey: '/keys/work');
        installs.start('home', profileKey: '/keys/home');
        settle();

        sudo('srq-w', key: '/keys/work');
        sudo('srq-h', key: '/keys/home');
        expect(askedProfiles, ['work', 'home']);

        holds['home']!.complete('home-pw');
        settle();
        holds['work']!.complete('work-pw');
        settle();

        expect(sudoAnswer('srq-h')['result'], {'value': 'home-pw'});
        expect(sudoAnswer('srq-w')['result'], {'value': 'work-pw'});
      });
    });

    test('a request the server withdraws closes its prompt and frees the '
        'install for the next one', () {
      scenario(() {
        final signals = <Future<void>>[];
        final holds = <Completer<String?>>[];
        installs.dispose();
        installs = makeInstalls((host, profile, ended) {
          signals.add(ended);
          return (holds..add(Completer<String?>())).last.future;
        });
        install();
        sudo('srq-1');
        var closed = false;
        signals.single.then((_) => closed = true);

        gateway.event('request.cancel', '', {
          'id': 'srq-1',
          'method': 'display.install.sudo',
          'reason': 'timeout',
        });
        settle();

        expect(closed, isTrue);
        sudo('srq-2');
        expect(signals, hasLength(2));
        holds[1].complete('pw');
        settle();
        expect(sudoAnswer('srq-2')['result'], {'value': 'pw'});
        // The first prompt finishing late must not undo the second's state.
        holds[0].complete('late');
        settle();
        expect((stateOf() as InstallRunning).askedPassword, isTrue);
      });
    });

    test('a withdrawal of another request or method changes nothing', () {
      scenario(() {
        final signals = <Future<void>>[];
        installs.dispose();
        installs = makeInstalls((host, profile, ended) {
          signals.add(ended);
          return Completer<String?>().future;
        });
        install();
        sudo('srq-1');
        var closed = false;
        signals.single.then((_) => closed = true);

        gateway.event('request.cancel', '', {
          'id': 'srq-other',
          'method': 'display.install.sudo',
        });
        gateway.event('request.cancel', '', {
          'id': 'srq-1',
          'method': 'approval',
        });
        settle();

        expect(closed, isFalse);
      });
    });

    test('an asker that throws answers an internal error without its text and '
        'logs a fixed word', () {
      scenario(() {
        installs.dispose();
        installs = makeInstalls((host, profile, ended) async {
          throw StateError('hunter2 leaked into a message');
        });
        install();

        sudo('srq-1');

        expect(errorCode('srq-1'), internalError);
        expect(
          (sudoAnswer('srq-1')['error'] as Map)['message'],
          isNot(contains('hunter2')),
        );
        expect(logged, ['bot_screen.install.prompt_failed {}']);
        // The prompt failing does not free a running install from asking
        // again.
        sudo('srq-2');
        expect(errorCode('srq-2'), internalError);
      });
    });
  });

  group('a missed done broadcast', () {
    test('a status that says installed ends it when the app resumes', () {
      scenario(() {
        install();
        gateway.handlers['display.status'] = (_) =>
            statusJson(extra: {'installed': true});

        installs.resumed();
        settle();

        expect((stateOf() as InstallEnded).result, isA<InstallInstalled>());
      });
    });

    test('resuming while the status says not installed keeps it running', () {
      scenario(() {
        install();

        installs.resumed();
        settle();

        expect(stateOf(), isA<InstallRunning>());
        expect(gateway.methods, contains('display.status'));
      });
    });

    test('a lost connection reads the status, and installed ends it', () {
      scenario(() {
        install();
        gateway.handlers['display.status'] = (_) =>
            statusJson(extra: {'installed': true});

        gateway.drop();
        settle();
        async.elapse(const Duration(seconds: 1));

        expect((stateOf() as InstallEnded).result, isA<InstallInstalled>());
      });
    });

    test('nothing is read when no install runs', () {
      scenario(() {
        installs.resumed();
        settle();

        expect(gateway.requests, isEmpty);
      });
    });

    test('22 minutes without done end it as unknown', () {
      scenario(() {
        install();

        async.elapse(const Duration(minutes: 21, seconds: 59));
        expect(stateOf(), isA<InstallRunning>());
        async.elapse(const Duration(seconds: 2));

        expect((stateOf() as InstallEnded).result, isA<InstallMayStillRun>());
      });
    });

    test('22 minutes later a status that says installed wins', () {
      scenario(() {
        install();
        gateway.handlers['display.status'] = (_) =>
            statusJson(extra: {'installed': true});

        async.elapse(const Duration(minutes: 22, seconds: 1));

        expect((stateOf() as InstallEnded).result, isA<InstallInstalled>());
      });
    });
  });

  group('telemetry', () {
    test('the log and the span carry the outcome and whether a password was '
        'asked, and nothing else', () {
      scenario(() {
        install();
        log('Reading package lists…');
        sudo('srq-1');
        done(0);

        expect(logged, [
          'bot_screen.install {outcome: installed, asked_password: true}',
        ]);
        final span = tracer.spans.single;
        expect(span.name, 'bot_screen.install');
        expect(span.ended, isTrue);
        expect(span.attributes, {
          'hermes.version': '0.22.0',
          'outcome': 'installed',
          'asked_password': true,
        });
      });
    });

    test('every ending has its outcome', () {
      for (final (code, outcome) in [
        (-1, 'cancelled'),
        (-2, 'no_sudo'),
        (1, 'failed'),
      ]) {
        scenario(() {
          install();
          done(code);

          expect(tracer.spans.single.attributes['outcome'], outcome);
          expect(logged.single, contains('outcome: $outcome'));
        });
      }
    });

    test('a refusal and an unanswered request are refused and error', () {
      scenario(() {
        gateway.handlers['display.install'] = (_) =>
            throw const FakeRpcError(5300, 'busy');
        install();

        expect(tracer.spans.single.attributes['outcome'], 'refused');
        expect(tracer.spans.single.ended, isTrue);
        expect(logged.single, contains('outcome: refused'));
      });
      scenario(() {
        gateway.silent.add('display.install');
        installs.start('work', profileKey: _key);
        async.elapse(const Duration(seconds: 11));

        expect(tracer.spans.single.attributes['outcome'], 'error');
        expect(logged.single, contains('outcome: error'));
      });
    });

    test('the timeout path ends the span as unknown', () {
      scenario(() {
        install();

        async.elapse(const Duration(minutes: 22, seconds: 1));

        expect(tracer.spans.single.attributes['outcome'], 'unknown');
        expect(tracer.spans.single.ended, isTrue);
        expect(logged.single, contains('outcome: unknown'));
      });
    });

    test('with the gateway telemetry on too, nothing recorded holds the '
        'password, the command, the lines, the host or the key', () {
      scenario(() {
        install();
        log('secret path /home/u/x');
        sudo('srq-1');
        // A failed read logs bot_screen.read_failed, and a request refused for
        // want of a handler is reported as unmapped.
        gateway.handlers['display.status'] = (_) =>
            throw const FakeRpcError(5300, 'secret path /home/u/x');
        installs.resumed();
        settle();
        done(0);
        sudo('srq-2');

        final everything = [
          ...logged,
          for (final span in tracer.spans) ...[
            span.name,
            ...span.attributes.values.map((v) => '$v'),
            ...span.events,
          ],
        ].join('\n');
        expect(everything, contains('bot_screen.install'));
        expect(everything, contains('gateway.event_unmapped'));
        for (final secret in [
          'hunter2',
          'apt-get',
          'secret path',
          'hermes.example.com',
          _key,
        ]) {
          expect(everything, isNot(contains(secret)));
        }
      }, transportTelemetry: true);
    });

    test('neither the password, the command, the lines nor the host are '
        'recorded', () {
      scenario(() {
        install();
        log('secret path /home/u/x');
        sudo('srq-1');
        done(-2);

        final everything = [
          ...logged,
          for (final span in tracer.spans) ...[
            span.name,
            ...span.attributes.values.map((v) => '$v'),
            ...span.events,
          ],
        ].join('\n');
        for (final secret in [
          'hunter2',
          'apt-get',
          'secret path',
          'hermes.example.com',
          _key,
        ]) {
          expect(everything, isNot(contains(secret)));
        }
      });
    });
  });
}
