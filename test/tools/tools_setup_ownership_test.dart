import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/terminal_backends_panel.dart';
import 'package:hermes_app/src/tools/tools_setup_registry.dart';
import 'package:hermes_app/src/tools/tools_write.dart';

import 'tools_setup_harness.dart';
import 'tools_setup_world.dart';

/// A panel the layout rebuilds without the user leaving (a details page
/// opened again during the pop animation) is built before the old one is
/// disposed: the old one must not clear what the new one shows.
void main() {
  late SetupWorld world;
  late SetupHarness h;

  const web = '/api/tools/toolsets/web';
  const webText = 'Look things up on the web and read pages.';

  Future<void> start(
    WidgetTester tester, {
    void Function(SetupWorld)? prepare,
  }) async {
    world = SetupWorld();
    prepare?.call(world);
    h = SetupHarness(tester, world);
    await h.pump();
  }

  /// Back, and the same details again while the page is still leaving.
  Future<void> reopenDuringPop(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 60));
    final row = find.descendant(
      of: find.byKey(const Key('tools-list')),
      matching: find.text(webText),
    );
    await tester.tap(row.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
  }

  testWidgets('reopening the details during the pop keeps a failed save, '
      'its typed key and a working Save', (tester) async {
    await start(tester);
    await h.openWeb();
    world.server.on('PUT', '$web/env', {'detail': 'boom'}, status: 500);
    await h.type(typedKey);
    await h.tapText('Save');
    expect(find.text("Couldn't save the key. Try again."), findsOneWidget);

    await reopenDuringPop(tester);

    expect(find.text("Couldn't save the key. Try again."), findsOneWidget);
    expect(h.fieldText, typedKey);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    // The typed key is the controller's too: Save sends it.
    world.server.on('PUT', '$web/env', {'ok': true, 'saved': []});
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(world.server.requestsTo('PUT', '$web/env'), hasLength(2));
    expect(
      world.server.requestsTo('PUT', '$web/env').last.data.toString(),
      contains(typedKey),
    );
    await h.close();
  });

  testWidgets('leaving for good still drops the typed key and the result', (
    tester,
  ) async {
    await start(tester);
    await h.openWeb();
    world.server.on('PUT', '$web/env', {'detail': 'boom'}, status: 500);
    await h.type(typedKey);
    await h.tapText('Save');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await h.openWeb();

    expect(find.text("Couldn't save the key. Try again."), findsNothing);
    expect(h.fieldText, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await h.close();
  });

  testWidgets('reopening Terminal during the pop keeps its refused pick', (
    tester,
  ) async {
    await start(tester);
    world.server.onRequest(
      'PUT',
      '/api/tools/terminal/backend',
      (_) => (status: 400, body: {'detail': 'Unknown backend.'}),
    );
    await h.openTerminal();
    await tester.ensureVisible(h.provider('docker'));
    await tester.tap(h.provider('docker'));
    await tester.pumpAndSettle();
    expect(find.text('Unknown backend.'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 60));
    final row = find.descendant(
      of: find.byKey(const Key('tools-list')),
      matching: find.text('Run commands on the machine where Hermes runs.'),
    );
    await tester.tap(row.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    // What the old panel's dispose would have cleared silently: the shown
    // text may only catch up on the next change, so the controller is asked.
    final backends = tester
        .widget<TerminalBackendsPanel>(find.byType(TerminalBackendsPanel))
        .env
        .registry
        .backends;
    expect(backends.pickState, ToolsWriteState.refused);
    expect(backends.refusalDetail, 'Unknown backend.');
    expect(find.text('Unknown backend.'), findsOneWidget);
    await h.close();
  });

  test('the registry hands an owner over, and only the owner releases', () {
    final registry = ToolsSetupRegistry(
      repository: HermesToolsRepository(
        SetupWorld().server.client().raw,
        profile: 'work',
      ),
      confirmLocal: () async => true,
      confirmGrant: () async => true,
      onWritten: () {},
      onBusyChanged: (_, {required busy}) {},
    );
    addTearDown(registry.dispose);
    final old = Object();
    final next = Object();
    registry.claim('setup:web', old);
    registry.claim('setup:web', next);

    expect(registry.release('setup:web', old), isFalse);
    expect(registry.release('setup:web', next), isTrue);
    expect(registry.release('setup:web', next), isFalse);
  });
}
