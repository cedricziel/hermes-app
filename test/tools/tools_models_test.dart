import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/tools_models.dart';

import 'tools_fixtures.dart';

void main() {
  group('the toolset list', () {
    test('parses every fixture row and ignores "available"', () {
      final list = ToolsetList.parse(toolsetsFixture);

      expect(list.skipped, 0);
      expect(list.toolsets.map((t) => t.name), ['web', 'terminal']);
      final web = list.toolsets.first;
      expect(web.label, 'Web Search & Scraping');
      expect(web.enabled, isTrue);
      expect(web.configured, isFalse);
      expect(web.tools, ['web_extract', 'web_search']);
      final terminal = list.toolsets.last;
      expect(terminal.enabled, isFalse);
    });

    test('skips and counts rows without a name', () {
      final list = ToolsetList.parse([
        {'label': 'No name'},
        {'name': ''},
        {'name': 7},
        'text',
        null,
        {'name': 'todo', 'enabled': true},
      ]);

      expect(list.toolsets.map((t) => t.name), ['todo']);
      expect(list.skipped, 5);
    });

    test('reads a flag that is not a boolean as false', () {
      final row = Toolset.tryParse({
        'name': 'file',
        'enabled': 'true',
        'configured': 1,
        'tools': ['read_file', 3, null],
      })!;

      expect(row.enabled, isFalse);
      expect(row.configured, isFalse);
      expect(row.tools, ['read_file']);
      expect(row.platform, 'cli');
      expect(row.label, 'file');
    });

    test('an answer that is not a list is an empty list', () {
      expect(ToolsetList.parse({'detail': 'x'}).toolsets, isEmpty);
      expect(ToolsetList.parse(null).toolsets, isEmpty);
    });
  });

  group('the provider matrix', () {
    test('parses providers, keys and install steps', () {
      final config = ToolsetConfig.parse(webConfigFixture);

      expect(config.hasCategory, isTrue);
      expect(config.activeProvider, 'Search Co');
      expect(config.providers, hasLength(2));
      final first = config.providers.first;
      expect(first.status, ToolsetProviderStatus.needsKeys);
      expect(first.isActive, isTrue);
      expect(first.capabilities, ['search', 'extract']);
      expect(first.envVars.single.key, 'SEARCHCO_API_KEY');
      expect(first.envVars.single.prompt, 'Search Co API key');
      expect(first.envVars.single.isSet, isFalse);
      expect(first.postSetup, isNull);
      expect(config.providers.last.postSetup, 'local_driver');
      expect(config.providers.last.status, ToolsetProviderStatus.needsSetup);
    });

    test('an unknown status is "needs setup", never ready', () {
      expect(
        ToolsetProviderStatus.parse('quantum'),
        ToolsetProviderStatus.needsSetup,
      );
      expect(
        ToolsetProviderStatus.parse(null),
        ToolsetProviderStatus.needsSetup,
      );
      expect(
        ToolsetProviderStatus.parse('needs_auth'),
        ToolsetProviderStatus.needsAuth,
      );
    });

    test('a key without a prompt is labelled with its name', () {
      final provider = ToolsetProvider.tryParse({
        'name': 'P',
        'env_vars': [
          {'key': 'P_KEY'},
          {'prompt': 'no key'},
        ],
      })!;

      expect(provider.envVars.single.prompt, 'P_KEY');
    });

    test('skips and counts providers without a name', () {
      final config = ToolsetConfig.parse({
        'has_category': true,
        'providers': [
          {'status': 'ready'},
          {'name': 'Ok', 'status': 'ready'},
        ],
      });

      expect(config.providers.single.name, 'Ok');
      expect(config.skipped, 1);
    });
  });

  test('a model catalog without models has none', () {
    final none = ToolsetModels.parse({
      'name': 'web',
      'has_models': false,
      'models': [],
    });
    final some = ToolsetModels.parse(imageModelsFixture);

    expect(none.hasModels, isFalse);
    expect(some.hasModels, isTrue);
    expect(some.models.single.price, r'$0.01/image');
    expect(some.defaultModel, 'fast-1');
    expect(some.current, 'fast-1');
  });

  test('terminal backends keep Hermes\' detail text and read an unknown '
      'status as unavailable', () {
    final backends = TerminalBackends.parse({
      ...backendsFixture,
      'backends': [
        ...(backendsFixture['backends']! as List),
        {'name': 'odd', 'status': 'melting'},
        {'label': 'nameless'},
      ],
    });

    expect(backends.active, 'local');
    expect(backends.skipped, 1);
    expect(backends.backends[1].status, BackendStatus.needsSetup);
    expect(backends.backends[1].detail, contains('Docker CLI'));
    expect(backends.backends.last.status, BackendStatus.unavailable);
  });

  group('computer use readiness', () {
    test('parses the fixture; a permission is only missing when false', () {
      final status = ComputerUseStatus.parse(computerUseFixture);

      expect(status.platform, 'darwin');
      expect(status.ready, isFalse);
      expect(status.accessibility, isTrue);
      expect(status.screenRecording, isFalse);
      expect(status.canOfferGrant, isTrue);
    });

    test('unknown permissions or a missing driver offer no grant', () {
      expect(
        ComputerUseStatus.parse({
          ...computerUseFixture,
          'screen_recording': null,
          'accessibility': null,
          'ready': null,
        }).canOfferGrant,
        isFalse,
      );
      expect(
        ComputerUseStatus.parse({...computerUseFixture, 'installed': false})
            .canOfferGrant,
        isFalse,
      );
      expect(ComputerUseStatus.parse({'ready': null}).ready, isNull);
    });
  });

  test('an action with no exit code that is not running is not a result', () {
    final status = ToolsActionStatus.parse({
      'running': false,
      'exit_code': null,
      'lines': ['a', 2, 'b'],
    });

    expect(status.running, isFalse);
    expect(status.exitCode, isNull);
    expect(status.lines, ['a', 'b']);
  });

  test('write answers read only what they carry', () {
    final switched = ToolsetSwitched.parse({
      'ok': true,
      'name': 'computer_use',
      'enabled': true,
      'post_setup_started': 'cua_driver',
    }, name: 'x');
    expect(switched.postSetupStarted, 'cua_driver');
    expect(ToolsetSwitched.parse(7, name: 'web').name, 'web');
    expect(
      ToolsetProviderPicked.parse({'ok': true, 'needs_nous_auth': true})
          .needsNousAuth,
      isTrue,
    );
    final saved = ToolsetEnvSaved.parse({
      'saved': ['A'],
      'skipped': ['B'],
      'is_set': {'A': true},
    });
    expect(saved.saved, ['A']);
    expect(saved.skipped, ['B']);
    expect(ToolsActionStarted.parse({'pid': 12}).pid, 12);
  });

  test('random and truncated input never throws', () {
    final random = Random(7);
    Object? junk(int depth) => switch (random.nextInt(depth > 3 ? 5 : 8)) {
      0 => null,
      1 => random.nextBool(),
      2 => random.nextInt(100),
      3 => 'text${random.nextInt(9)}',
      4 => '',
      5 => [for (var i = 0; i < 3; i++) junk(depth + 1)],
      _ => {
        for (final key in [
          'name',
          'providers',
          'models',
          'backends',
          'checks',
          'env_vars',
          'lines',
          'enabled',
          'status',
        ])
          if (random.nextBool()) key: junk(depth + 1),
      },
    };
    for (var i = 0; i < 300; i++) {
      final input = junk(0);
      expect(() => ToolsetList.parse(input), returnsNormally);
      expect(() => ToolsetConfig.parse(input), returnsNormally);
      expect(() => ToolsetModels.parse(input), returnsNormally);
      expect(() => TerminalBackends.parse(input), returnsNormally);
      expect(() => ComputerUseStatus.parse(input), returnsNormally);
      expect(() => ToolsActionStatus.parse(input), returnsNormally);
      expect(() => ToolsetEnvSaved.parse(input), returnsNormally);
      expect(() => ToolsetSwitched.parse(input, name: 'x'), returnsNormally);
    }
    // Truncated: what a half-read body parses to.
    expect(() => ToolsetList.parse(<Object?>[]), returnsNormally);
    expect(ToolsetList.parse(<Object?>[{}]).skipped, 1);
  });
}
