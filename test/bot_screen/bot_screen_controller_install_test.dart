import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/install/bot_screen_installs.dart';
import 'package:hermes_app/src/bot_screen/install/install_state.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';
import 'bot_screen_repository_test.dart' show statusJson;

const _key = '/home/u/.hermes/profiles/work';

/// The controller shows the install of its profile, which lives in the app
/// level [BotScreenInstalls] and so outlives the controller.
void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late BotScreenInstalls installs;
  var installed = false;

  BotScreenController controller({bool withInstalls = true}) =>
      BotScreenController(
        BotScreenRepository(transport.requestKeepingConnection),
        transport.connectionEvents,
        profile: 'work',
        installs: withInstalls ? installs : null,
      );

  setUp(() {
    installed = false;
    gateway = FakeGateway();
    gateway.handlers['display.status'] = (_) => statusJson(
      running: false,
      extra: {
        'installed': installed,
        'install_command': 'sudo apt-get install -y x',
      },
    );
    gateway.handlers['display.install'] = (_) => {
      'started': true,
      'command': 'sudo apt-get install -y x',
      'profile_key': _key,
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    installs = BotScreenInstalls(
      repository: BotScreenRepository(
        transport.requestKeepingConnection,
        installRpc: transport.requestKeepingConnectionOnClient,
      ),
      connectionEvents: transport.connectionEvents,
      registerServerRequestHandler: transport.registerServerRequestHandler,
      askPassword: (host, profile, ended) async => null,
      host: 'hermes.example.com',
    );
  });

  tearDown(() async {
    installs.dispose();
    await transport.close();
  });

  Future<void> settle() => pumpEventQueue();

  Future<BotScreenController> watched() async {
    final screen = controller();
    addTearDown(screen.dispose);
    screen.watch();
    await settle();
    return screen;
  }

  test(
    'Install on Server is offered only with the installs of the app',
    () async {
      final screen = await watched();
      final without = controller(withInstalls: false);
      addTearDown(without.dispose);

      expect(screen.canInstall, isTrue);
      expect(without.canInstall, isFalse);
    },
  );

  test(
    'installing starts the install for its profile and the status key',
    () async {
      final screen = await watched();

      await screen.startInstall();

      final request = gateway.requestOf('display.install');
      expect(request['params'], {'profile': 'work'});
      expect(screen.install, isA<InstallRunning>());
      expect(BotScreenCardModel.from(screen), isA<BotScreenInstalling>());
    },
  );

  test('the install is still there for a controller made after the first '
      'was disposed', () async {
    final first = await watched();
    await first.startInstall();
    first.dispose();

    final second = await watched();

    expect(second.install, isA<InstallRunning>());
    expect(BotScreenCardModel.from(second), isA<BotScreenInstalling>());
  });

  test('a controller is told when its install changes', () async {
    final screen = await watched();
    await screen.startInstall();
    var heard = 0;
    screen.addListener(() => heard++);

    gateway.event('display.install.log', '', {
      'profile_key': _key,
      'line': 'Reading package lists…',
    });
    await settle();

    expect(heard, greaterThan(0));
    expect((BotScreenCardModel.from(screen) as BotScreenInstalling).lines, [
      'Reading package lists…',
    ]);
  });

  test('a finished install brings the status that came with done', () async {
    final screen = await watched();
    await screen.startInstall();
    expect(screen.status?.installed, isFalse);

    gateway.event('display.install.done', '', {
      'profile_key': _key,
      'code': 0,
      'status': statusJson(running: false, extra: {'installed': true}),
    });
    await settle();

    expect(screen.status?.installed, isTrue);
    expect(BotScreenCardModel.from(screen), isA<BotScreenOff>());
  });

  test('an install of another profile is not shown', () async {
    final screen = await watched();
    await installs.start('other', profileKey: '/other');
    await settle();

    expect(screen.install, isNull);
  });

  test('an install that ended before the controller was made is not applied '
      'on a later notification', () async {
    final first = await watched();
    await first.startInstall();
    gateway.event('display.install.done', '', {
      'profile_key': _key,
      'code': 0,
      'status': statusJson(running: false, extra: {'installed': true}),
    });
    await settle();
    expect(first.status?.installed, isTrue);
    first.dispose();
    // The packages were removed again since; the new controller reads that.
    installed = false;
    final second = await watched();
    expect(second.status?.installed, isFalse);

    // Another profile's install changes the installs, which tells everyone.
    await installs.start('other', profileKey: '/other');
    await settle();

    expect(second.status?.installed, isFalse);
  });
}
