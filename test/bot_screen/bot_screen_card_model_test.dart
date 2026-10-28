import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/install/install_state.dart';

final _jpeg = Uint8List.fromList([0xff, 0xd8, 1, 2]);

BotScreenStatus _status({
  bool supported = true,
  bool installed = true,
  bool running = true,
  String placement = 'gateway',
  String? installCommand,
  String? blocker,
  int? memoryMb,
  String? geometry = '1280x800',
  BotScreenLease lease = const BotScreenLease(),
}) => BotScreenStatus(
  supported: supported,
  installed: installed,
  running: running,
  placement: placement,
  installCommand: installCommand,
  blocker: blocker,
  memoryAvailableMb: memoryMb,
  geometry: geometry,
  lease: lease,
);

BotScreenCardModel? _model({
  BotScreenStatus? status,
  bool unsupported = false,
  bool starting = false,
  BotScreenFailure? startError,
  BotScreenFailure? failure,
  Uint8List? frame,
  bool suppressed = false,
  Set<String> ownViewerHashes = const {},
  InstallState? install,
  bool canInstall = true,
}) => BotScreenCardModel.fromState(
  status: status,
  unsupported: unsupported,
  starting: starting,
  startError: startError,
  failure: failure,
  frame: frame,
  suppressed: suppressed,
  ownViewerHashes: ownViewerHashes,
  install: install,
  canInstall: canInstall,
);

void main() {
  group('nothing to show', () {
    test('before the first answer', () {
      expect(_model(), isNull);
    });

    test('on a server without the Bot Screen feature', () {
      expect(_model(unsupported: true, status: _status()), isNull);
    });
  });

  group('the order of states', () {
    test('not offered comes first, over everything below', () {
      final model = _model(
        status: _status(
          supported: false,
          installed: false,
          blocker: 'No memory',
          running: false,
        ),
        starting: true,
        failure: BotScreenFailure.timeout,
      );

      expect(model, isA<BotScreenNotOffered>());
    });

    test('not installed comes before blocked', () {
      final model = _model(
        status: _status(installed: false, blocker: 'No memory', running: false),
      );

      expect(model, isA<BotScreenNotInstalled>());
    });

    test('blocked comes before starting', () {
      final model = _model(
        status: _status(blocker: 'No memory', running: false),
        starting: true,
      );

      expect(model, isA<BotScreenBlocked>());
    });

    test('starting comes before off', () {
      final model = _model(status: _status(running: false), starting: true);

      expect(model, isA<BotScreenStarting>());
    });

    test('off comes before error', () {
      final model = _model(
        status: _status(running: false),
        failure: BotScreenFailure.timeout,
      );

      expect(model, isA<BotScreenOff>());
    });

    test('error comes before the picture', () {
      final model = _model(
        status: _status(),
        failure: BotScreenFailure.display,
        frame: _jpeg,
      );

      expect(model, isA<BotScreenReadFailed>());
    });

    test('a failed status read with no status is an error', () {
      expect(
        _model(failure: BotScreenFailure.closed),
        isA<BotScreenReadFailed>(),
      );
    });
  });

  group('not installed', () {
    test('on the gateway carries the command', () {
      final model = _model(
        status: _status(
          installed: false,
          running: false,
          installCommand: 'hermes computer-use install',
        ),
      );

      expect(
        model,
        isA<BotScreenNotInstalled>()
            .having((m) => m.command, 'command', 'hermes computer-use install')
            .having((m) => m.sandbox, 'sandbox', isFalse),
      );
    });

    test('in a sandbox carries no command, even when the server sent one', () {
      final model = _model(
        status: _status(
          installed: false,
          running: false,
          placement: 'docker',
          installCommand: 'hermes computer-use install',
        ),
      );

      expect(
        model,
        isA<BotScreenNotInstalled>()
            .having((m) => m.command, 'command', isNull)
            .having((m) => m.sandbox, 'sandbox', isTrue),
      );
    });

    test('on the gateway without a command carries none', () {
      final model = _model(status: _status(installed: false, running: false));

      expect(
        model,
        isA<BotScreenNotInstalled>().having(
          (m) => m.command,
          'command',
          isNull,
        ),
      );
    });
  });

  group('blocked', () {
    test('carries the memory figure only when reported', () {
      final withMemory = _model(
        status: _status(blocker: 'Low memory', memoryMb: 312, running: false),
      );
      final without = _model(
        status: _status(blocker: 'Low memory', running: false),
      );

      expect(
        withMemory,
        isA<BotScreenBlocked>()
            .having((m) => m.text, 'text', 'Low memory')
            .having((m) => m.memoryMb, 'memoryMb', 312),
      );
      expect(
        without,
        isA<BotScreenBlocked>().having((m) => m.memoryMb, 'memoryMb', isNull),
      );
    });
  });

  group('off', () {
    test('carries why the last start failed', () {
      final model = _model(
        status: _status(running: false),
        startError: BotScreenFailure.timeout,
      );

      expect(
        model,
        isA<BotScreenOff>().having(
          (m) => m.startFailure,
          'startFailure',
          BotScreenFailure.timeout,
        ),
      );
    });
  });

  group('running', () {
    test('Hermes in control shows the frame', () {
      final model = _model(status: _status(), frame: _jpeg);

      expect(
        model,
        isA<BotScreenShowing>()
            .having((m) => m.bytes, 'bytes', _jpeg)
            .having((m) => m.aspectRatio, 'aspectRatio', 1280 / 800),
      );
    });

    test('before the first frame the card waits with no picture', () {
      final model = _model(status: _status());

      expect(
        model,
        isA<BotScreenShowing>().having((m) => m.bytes, 'bytes', isNull),
      );
    });

    test('a geometry with a colour depth takes its first two numbers', () {
      final model = _model(status: _status(geometry: '1280x800x24'));

      expect(
        model,
        isA<BotScreenShowing>().having(
          (m) => m.aspectRatio,
          'ratio',
          1280 / 800,
        ),
      );
    });

    test('an extreme geometry is clamped to between 0.5 and 3', () {
      final tall = _model(status: _status(geometry: '100x1000'));
      final wide = _model(status: _status(geometry: '3000x100'));

      expect(
        tall,
        isA<BotScreenShowing>().having((m) => m.aspectRatio, 'ratio', 0.5),
      );
      expect(
        wide,
        isA<BotScreenShowing>().having((m) => m.aspectRatio, 'ratio', 3),
      );
    });

    test('an unknown or unreadable geometry is 16:10', () {
      for (final geometry in [null, '', 'wide', '0x0', '1280x', '-1x5']) {
        final model = _model(status: _status(geometry: geometry));

        expect(
          model,
          isA<BotScreenShowing>().having(
            (m) => m.aspectRatio,
            'ratio',
            16 / 10,
          ),
          reason: '$geometry',
        );
      }
    });

    test('a person in control shows no picture, even with a stale frame', () {
      final model = _model(
        status: _status(
          lease: const BotScreenLease(holder: BotScreenHolder.human),
        ),
        frame: _jpeg,
      );

      expect(
        model,
        isA<BotScreenControlled>().having((m) => m.byYou, 'byYou', isFalse),
      );
    });

    test('a suppressed frame shows no picture', () {
      final model = _model(status: _status(), suppressed: true, frame: _jpeg);

      expect(model, isA<BotScreenControlled>());
    });

    test('a lease naming a viewer id this app holds says you', () {
      final model = _model(
        status: _status(
          lease: const BotScreenLease(
            holder: BotScreenHolder.human,
            viewerHash: 'abc123',
          ),
        ),
        ownViewerHashes: const {'abc123'},
      );

      expect(
        model,
        isA<BotScreenControlled>().having((m) => m.byYou, 'byYou', isTrue),
      );
    });

    test('another viewer\'s lease does not say you', () {
      final model = _model(
        status: _status(
          lease: const BotScreenLease(
            holder: BotScreenHolder.human,
            viewerHash: 'other',
          ),
        ),
        ownViewerHashes: const {'abc123'},
      );

      expect(
        model,
        isA<BotScreenControlled>().having((m) => m.byYou, 'byYou', isFalse),
      );
    });
  });

  group('whether the card is listed', () {
    test('a running screen is listed without any computer_use call', () {
      final model = _model(status: _status(), frame: _jpeg)!;

      expect(model.listed(usedByChat: false), isTrue);
    });

    test('a stopped screen is listed only when the chat used it', () {
      final model = _model(status: _status(running: false))!;

      expect(model.listed(usedByChat: false), isFalse);
      expect(model.listed(usedByChat: true), isTrue);
    });

    test('a read failure on an unknown screen is listed only for a chat '
        'that used it', () {
      final model = _model(failure: BotScreenFailure.closed)!;

      expect(model.listed(usedByChat: false), isFalse);
      expect(model.listed(usedByChat: true), isTrue);
    });

    test('a read failure on a running screen is listed', () {
      final model = _model(
        status: _status(),
        failure: BotScreenFailure.timeout,
      )!;

      expect(model.listed(usedByChat: false), isTrue);
    });

    test('a start in flight on a stopped screen is listed for a chat that '
        'used it', () {
      final model = _model(status: _status(running: false), starting: true)!;

      expect(model.listed(usedByChat: false), isFalse);
      expect(model.listed(usedByChat: true), isTrue);
    });
  });

  group('installing', () {
    BotScreenStatus missing({String? command = 'sudo apt-get install -y x'}) =>
        _status(installed: false, running: false, installCommand: command);

    test('an install that runs comes before not installed, with its lines', () {
      final model = _model(
        status: missing(),
        install: const InstallRunning(lines: ['one', 'two']),
      );

      expect(
        model,
        isA<BotScreenInstalling>().having((m) => m.lines, 'lines', [
          'one',
          'two',
        ]),
      );
      expect(model!.slug, 'installing');
    });

    test('not offered still comes before installing', () {
      final model = _model(
        status: _status(supported: false, installed: false),
        install: const InstallRunning(),
      );

      expect(model, isA<BotScreenNotOffered>());
    });

    test('Install on Server needs the gateway, a command and an installer', () {
      bool offered({
        String placement = 'gateway',
        String? command = 'sudo apt-get install -y x',
        bool canInstall = true,
      }) => (_model(
        status: _status(
          installed: false,
          running: false,
          placement: placement,
          installCommand: command,
        ),
        canInstall: canInstall,
      ) as BotScreenNotInstalled).canInstall;

      expect(offered(), isTrue);
      expect(offered(placement: 'docker'), isFalse);
      expect(offered(command: null), isFalse);
      expect(offered(canInstall: false), isFalse);
    });

    test('an ended install shows its result under not installed', () {
      final model = _model(
        status: missing(),
        install: const InstallEnded(InstallCancelled()),
      );

      expect(
        model,
        isA<BotScreenNotInstalled>().having(
          (m) => m.result,
          'result',
          isA<InstallCancelled>(),
        ),
      );
    });

    test('an install that finished shows no result', () {
      final model = _model(
        status: missing(),
        install: const InstallEnded(InstallInstalled()),
      );

      expect((model as BotScreenNotInstalled).result, isNull);
    });

    test('no sudo shows the command it carries when the status has none', () {
      final model = _model(
        status: missing(command: null),
        install: const InstallEnded(InstallNoSudo(command: 'sudo run this')),
      );

      expect((model as BotScreenNotInstalled).command, 'run this');
    });

    test('no sudo shows the command without sudo, and offers no installer', () {
      final model = _model(
        status: missing(command: 'sudo apt-get install -y x'),
        install: const InstallEnded(
          InstallNoSudo(command: 'sudo apt-get install -y x'),
        ),
      ) as BotScreenNotInstalled;

      expect(model.command, 'apt-get install -y x');
      expect(model.canInstall, isFalse);
      expect(model.result, isA<InstallNoSudo>());
    });

    test('a command that does not start with sudo is shown as it is', () {
      final model = _model(
        status: missing(command: 'pacman -S --noconfirm x'),
        install: const InstallEnded(InstallNoSudo()),
      ) as BotScreenNotInstalled;

      expect(model.command, 'pacman -S --noconfirm x');
    });

    test('a sandbox shows no result and no installer', () {
      final model = _model(
        status: _status(
          installed: false,
          running: false,
          placement: 'docker',
          installCommand: 'x',
        ),
        install: const InstallEnded(InstallCancelled()),
      ) as BotScreenNotInstalled;

      expect(model.result, isNull);
      expect(model.canInstall, isFalse);
    });

    test('once installed the state follows the status, not the install', () {
      final model = _model(
        status: _status(running: false),
        install: const InstallEnded(InstallInstalled()),
      );

      expect(model, isA<BotScreenOff>());
    });
  });
}
