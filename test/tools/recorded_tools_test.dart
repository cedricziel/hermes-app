import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/tools/toolset_risk.dart';

import '../support/fake_hermes_server.dart';
import 'recorded_tools_fixtures.dart';
import 'tools_fixtures.dart';

T ok<T>(ToolsResult<T> result) {
  expect(result, isA<ToolsOk<T>>(), reason: '$result');
  return (result as ToolsOk<T>).value;
}

/// The recorded answers of Hermes d923a5eb (task 1.2) through the real
/// repository and parsers.
void main() {
  late FakeHermesServer server;
  late HermesToolsRepository repository;

  setUp(() {
    server = FakeHermesServer();
    serveRecordedTools(server);
    repository = toolsRepository(server);
  });

  test('the list parses without a skipped row and keeps the server\'s '
      'order', () async {
    final list = ok(await repository.list());

    expect(list.skipped, 0);
    expect(list.toolsets, hasLength(27));
    expect(list.toolsets.first.name, 'web');
    final byName = {for (final t in list.toolsets) t.name: t};
    expect(byName['vision']!.enabled, isTrue);
    expect(byName['vision']!.configured, isTrue);
    expect(byName['kanban']!.enabled, isFalse);
    expect(byName['discord']!.platform, 'discord');
    expect(
      byName['terminal']!.tools,
      containsAll(['terminal', 'process_manage']),
    );
  });

  test('twelve listed names have no decision in the risk table yet', () async {
    // The same set as the contract test's list of names still to decide.
    final list = ok(await repository.list());
    final undecided = {
      for (final t in list.toolsets)
        if (!kToolsetRisks.containsKey(t.name) &&
            !kNoRiskToolsets.contains(t.name))
          t.name,
    };

    expect(undecided, {
      'vision',
      'video',
      'x_search',
      'skills',
      'kanban',
      'memory',
      'context_engine',
      'connections',
      'clarify',
      'discord',
      'yuanbao',
      'a2a',
    });
  });

  test('the web matrix has no active provider while a backend is active, '
      'and every status is one the app knows', () async {
    final config = ok(await repository.config('web'));

    expect(config.skipped, 0);
    expect(config.activeProvider, isNull);
    expect(config.activeSearchBackend, 'keenable');
    expect(config.providers.where((p) => p.isActive), isEmpty);
    final statuses = {for (final p in config.providers) p.name: p.status};
    expect(statuses['Firecrawl Self-Hosted'], ToolsetProviderStatus.needsKeys);
    expect(statuses['DuckDuckGo (ddgs)'], ToolsetProviderStatus.needsSetup);
    expect(statuses['Exa · Free (keyless)'], ToolsetProviderStatus.ready);
    expect(statuses['xAI Web Search (Grok)'], ToolsetProviderStatus.needsAuth);
    final ddgs = config.providers.firstWhere((p) => p.postSetup == 'ddgs');
    expect(ddgs.capabilities, ['search']);
    final selfHosted = config.providers.firstWhere(
      (p) => p.name == 'Firecrawl Self-Hosted',
    );
    expect(selfHosted.envVars.single.key, 'FIRECRAWL_API_URL');
    expect(selfHosted.envVars.single.isSet, isFalse);
  });

  test('the other matrices read, and terminal has none', () async {
    final browser = ok(await repository.config('browser'));
    final statuses = {for (final p in browser.providers) p.name: p.status};
    expect(statuses['Local Browser'], ToolsetProviderStatus.needsSetup);
    // Its URL had been saved by then.
    expect(statuses['Camofox'], ToolsetProviderStatus.ready);
    expect(
      browser.providers
          .firstWhere((p) => p.name == 'Camofox')
          .envVars
          .single
          .isSet,
      isTrue,
    );
    // `Browser Use` read `ready` and active on a fresh profile; its status
    // follows what is installed on the server at that moment.
    expect(statuses['Browser Use'], ToolsetProviderStatus.needsSetup);
    expect(
      statuses['Nous Subscription (Browser Use cloud)'],
      ToolsetProviderStatus.needsAuth,
    );
    expect(
      browser.providers
          .firstWhere((p) => p.name.startsWith('Nous'))
          .requiresNousAuth,
      isTrue,
    );
    expect(ok(await repository.config('image_gen')).providers, isNotEmpty);
    expect(ok(await repository.config('tts')).providers, isNotEmpty);
    final computerUse = ok(await repository.config('computer_use'));
    expect(computerUse.providers.single.postSetup, 'cua_driver');
    final terminal = ok(await repository.config('terminal'));
    expect(terminal.hasCategory, isFalse);
    expect(terminal.providers, isEmpty);
  });

  test('a toolset without a catalog says so, and one with a catalog lists '
      'its models with a current that differs from the default', () async {
    expect(ok(await repository.models('web')).hasModels, isFalse);

    final models = ok(await repository.models('image_gen'));

    expect(models.hasModels, isTrue);
    expect(models.models, hasLength(3));
    expect(models.current, 'image-model-b');
    expect(models.defaultModel, 'image-model-a');
    expect(models.provider, 'Image Co');
  });

  test('the terminal backends name an active one, and the rest need setup '
      'with a detail', () async {
    final backends = ok(await repository.terminalBackends());

    expect(backends.skipped, 0);
    expect(backends.active, 'local');
    expect(backends.backends, hasLength(6));
    final byName = {for (final b in backends.backends) b.name: b};
    expect(byName['local']!.status, BackendStatus.ready);
    expect(byName['docker']!.status, BackendStatus.needsSetup);
    expect(byName['docker']!.detail, isNotEmpty);
  });

  test('the computer use status of a Linux server cannot be granted', () async {
    final status = ok(await repository.computerUseStatus());

    expect(status.platform, 'linux');
    expect(status.installed, isFalse);
    expect(status.canGrant, isFalse);
    expect(status.ready, isNull);
    expect(status.accessibility, isNull);
    expect(status.screenRecording, isNull);
  });

  test('the write answers parse', () async {
    server
      ..on('PUT', '/api/tools/toolsets/web', recordedSwitchAnswer)
      ..on('PUT', '/api/tools/toolsets/computer_use', recordedSwitchOnAnswer)
      ..on(
        'PUT',
        '/api/tools/toolsets/image_gen/provider',
        recordedProviderAnswer,
      )
      ..on('PUT', '/api/tools/toolsets/image_gen/env', recordedEnvAnswer)
      ..on('PUT', '/api/tools/toolsets/image_gen/model', recordedModelAnswer)
      ..on('PUT', '/api/tools/terminal/backend', recordedBackendAnswer)
      ..on(
        'POST',
        '/api/tools/toolsets/browser/post-setup',
        recordedPostSetupAnswer,
      )
      ..on(
        'GET',
        '/api/actions/tools-post-setup/status',
        recordedPostSetupFailed,
      );

    final off = ok(await repository.switchToolset('web', enabled: false));
    expect(off.enabled, isFalse);
    expect(off.postSetupStarted, isNull);
    final on = ok(
      await repository.switchToolset('computer_use', enabled: true),
    );
    expect(on.postSetupStarted, 'cua_driver');
    expect(
      ok(await repository.pickProvider('image_gen', 'FAL.ai')).needsNousAuth,
      isFalse,
    );
    final saved = ok(await repository.saveEnv('image_gen', {'FAL_KEY': 'x'}));
    expect(saved.saved, ['FAL_KEY']);
    expect(saved.isSet['FAL_KEY'], isTrue);
    expect(saved.isSet['OPENAI_API_KEY'], isFalse);
    ok(await repository.pickModel('image_gen', 'image-model-b'));
    ok(await repository.pickTerminalBackend('docker'));
    final started = ok(await repository.startPostSetup('browser', 'camofox'));
    expect(started.pid, 21001);
    final status = ok(await repository.postSetupStatus());
    expect(status.running, isFalse);
    expect(status.exitCode, 1);
    expect(status.pid, 21001);
    expect(status.lines, isNotEmpty);
  });
}
