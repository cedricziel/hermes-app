import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';

void main() {
  late MacCommandRegistry registry;
  late int notified;

  setUp(() {
    registry = MacCommandRegistry();
    notified = 0;
    registry.addListener(() => notified++);
  });

  Widget host(Widget child) => MacCommandScope.root(
    registry: registry,
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('a mounted scope offers its commands until it is disposed', (
    tester,
  ) async {
    var created = 0;
    await tester.pumpWidget(
      host(
        MacCommandScope(
          commands: {MacCommand.newChat: MacCommandHandler(() => created++)},
          child: const SizedBox(),
        ),
      ),
    );
    expect(registry.invoke(MacCommand.newChat), isTrue);
    expect(created, 1);
    expect(notified, 1);

    await tester.pumpWidget(host(const SizedBox()));
    expect(registry.handlerFor(MacCommand.newChat), isNull);
    expect(registry.invoke(MacCommand.newChat), isFalse);
    expect(notified, 2);
  });

  testWidgets('a command nobody registered is missing', (tester) async {
    await tester.pumpWidget(host(const SizedBox()));
    expect(registry.handlerFor(MacCommand.deleteThread), isNull);
  });

  testWidgets('a null callback shows the command disabled', (tester) async {
    await tester.pumpWidget(
      host(
        const MacCommandScope(
          commands: {MacCommand.pinThread: MacCommandHandler(null)},
          child: SizedBox(),
        ),
      ),
    );
    expect(registry.handlerFor(MacCommand.pinThread)!.enabled, isFalse);
    expect(registry.invoke(MacCommand.pinThread), isFalse);
  });

  testWidgets('the inner scope takes over a command both offer', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      host(
        MacCommandScope(
          commands: {
            MacCommand.newChat: MacCommandHandler(() => calls.add('outer')),
            MacCommand.find: MacCommandHandler(() => calls.add('outer find')),
          },
          child: MacCommandScope(
            commands: {
              MacCommand.newChat: MacCommandHandler(() => calls.add('inner')),
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );
    registry.invoke(MacCommand.newChat);
    registry.invoke(MacCommand.find);
    expect(calls, ['inner', 'outer find']);
  });

  testWidgets('a higher priority wins over a later scope', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      host(
        MacCommandScope(
          priority: 1,
          commands: {
            MacCommand.closeWindow: MacCommandHandler(() => calls.add('key')),
          },
          child: MacCommandScope(
            commands: {
              MacCommand.closeWindow: MacCommandHandler(
                () => calls.add('main'),
              ),
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );
    registry.invoke(MacCommand.closeWindow);
    expect(calls, ['key']);
  });

  testWidgets('a hidden page offers nothing until it is shown', (tester) async {
    Widget pages(int index) => host(
      IndexedStack(
        index: index,
        children: [
          MacCommandScope(
            commands: {MacCommand.find: MacCommandHandler(() {})},
            child: const SizedBox(),
          ),
          const SizedBox(),
        ],
      ),
    );
    await tester.pumpWidget(pages(0));
    expect(registry.handlerFor(MacCommand.find), isNotNull);
    await tester.pumpWidget(pages(1));
    expect(registry.handlerFor(MacCommand.find), isNull);
    await tester.pumpWidget(pages(0));
    expect(registry.handlerFor(MacCommand.find), isNotNull);
  });

  testWidgets('a new callback alone does not notify; a new title does', (
    tester,
  ) async {
    Widget scope(String title) => host(
      MacCommandScope(
        commands: {
          MacCommand.pinThread: MacCommandHandler(() {}, title: title),
        },
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(scope('Pin'));
    expect(notified, 1);
    await tester.pumpWidget(scope('Pin'));
    expect(notified, 1);
    await tester.pumpWidget(scope('Unpin'));
    expect(notified, 2);
    expect(registry.handlerFor(MacCommand.pinThread)!.title, 'Unpin');
  });

  test('the window list notifies only when it changes', () {
    void select() {}
    registry.windows = [
      MacWindowEntry(id: 'a', title: 'Trip', onSelect: select),
    ];
    expect(notified, 1);
    registry.windows = [
      MacWindowEntry(id: 'a', title: 'Trip', onSelect: select),
    ];
    expect(notified, 1);
    registry.windows = const [];
    expect(notified, 2);
  });

  test('a scope registering outside a frame, as the first build at start-up '
      'does, notifies once that build is done', () async {
    final registration = registry.register({
      MacCommand.pinThread: MacCommandHandler(() {}),
    });
    expect(notified, 0);

    await Future<void>.delayed(Duration.zero);
    expect(notified, 1);

    registration.dispose();
    expect(notified, 1);
    await Future<void>.delayed(Duration.zero);
    expect(notified, 2);
  });
}
