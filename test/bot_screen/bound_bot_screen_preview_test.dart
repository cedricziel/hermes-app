import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/bot_screen/widgets/bound_bot_screen_preview.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';
import 'bot_screen_repository_test.dart' show jpeg, statusJson;

/// What makes the transcript preview ask for frames: being on screen, not
/// being built in a list's cache extent.
void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late BotScreenController controller;
  final scroll = ScrollController();

  int calls(String method) => gateway.methods.where((m) => m == method).length;

  setUp(() {
    gateway = FakeGateway();
    gateway.handlers['display.status'] = (_) => statusJson();
    gateway.handlers['display.thumbnail'] = (_) => {
      'data_url': 'data:image/jpeg;base64,${base64Encode(jpeg)}',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    controller = BotScreenController(
      BotScreenRepository(transport.requestKeepingConnection),
      transport.connectionEvents,
      profile: 'work',
    );
  });

  tearDown(() async {
    controller.dispose();
    await transport.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  /// A list tall enough that the preview, with [before] pixels above it, can
  /// be built and still be off screen.
  Future<void> pumpList(
    WidgetTester tester, {
    required double before,
    bool pageShown = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TickerMode(
          enabled: pageShown,
          child: ListView(
            controller: scroll,
            scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
            children: [
              SizedBox(height: before),
              BoundBotScreenPreview(
                controller: controller,
                replyId: 'r1',
                startedAt: DateTime.utc(2026),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(transport.close);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a preview on screen holds a watch and asks for frames', (
    tester,
  ) async {
    await pumpList(tester, before: 0);
    await settle(tester);

    expect(find.byType(BotScreenPreview), findsOne);
    expect(calls('display.status'), 1);
    expect(calls('display.thumbnail'), greaterThan(0));
    await end(tester);
  });

  testWidgets('a preview built in the cache extent but off screen asks for '
      'nothing', (tester) async {
    await pumpList(tester, before: 1500);
    await settle(tester);
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);

    expect(
      find.byType(BoundBotScreenPreview, skipOffstage: false),
      findsOne,
      reason: 'the list built it',
    );
    expect(calls('display.status'), 0);
    expect(calls('display.thumbnail'), 0);
    await end(tester);
  });

  testWidgets('scrolling the preview off screen stops the requests and '
      'scrolling back asks again', (tester) async {
    await pumpList(tester, before: 300);
    scroll.jumpTo(0);
    await tester.pump();
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(0));

    scroll.jumpTo(1400);
    await tester.pump();
    await settle(tester);
    final before = calls('display.thumbnail');
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
    expect(
      find.byType(BoundBotScreenPreview, skipOffstage: false),
      findsOne,
      reason: 'still built in the cache extent',
    );
    expect(calls('display.thumbnail'), before);

    scroll.jumpTo(300);
    await tester.pump();
    await settle(tester);
    expect(calls('display.thumbnail'), greaterThan(before));
    await end(tester);
  });

  testWidgets('a page covered by another route counts as off screen', (
    tester,
  ) async {
    await pumpList(tester, before: 0, pageShown: false);
    await settle(tester);
    await tester.pump(const Duration(seconds: 12));

    expect(calls('display.status'), 0);
    expect(calls('display.thumbnail'), 0);
    await end(tester);
  });

  testWidgets(
    'leaving the app\'s foreground, and App Lock, stop the requests',
    (tester) async {
      await pumpList(tester, before: 0);
      await settle(tester);
      var before = calls('display.thumbnail');
      expect(before, greaterThan(0));

      controller.foreground = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);
      expect(calls('display.thumbnail'), before);
      controller.foreground = true;
      await tester.pump();
      await settle(tester);
      before = calls('display.thumbnail');

      controller.unlocked = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      await settle(tester);
      expect(calls('display.thumbnail'), before);
      await end(tester);
    },
  );

  testWidgets('of two pending replies only the newer shows the preview, and '
      'the older one takes it back when the newer ends', (tester) async {
    final older = DateTime.utc(2026, 1, 1);
    final newer = DateTime.utc(2026, 1, 2);
    Widget app({required bool withNewer}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            BoundBotScreenPreview(
              key: BoundBotScreenPreview.keyFor(controller, 'old'),
              controller: controller,
              replyId: 'old',
              startedAt: older,
            ),
            if (withNewer)
              BoundBotScreenPreview(
                key: BoundBotScreenPreview.keyFor(controller, 'new'),
                controller: controller,
                replyId: 'new',
                startedAt: newer,
              ),
          ],
        ),
      ),
    );
    final old = find.byKey(BoundBotScreenPreview.keyFor(controller, 'old'));
    final recent = find.byKey(BoundBotScreenPreview.keyFor(controller, 'new'));
    Finder drawn(Finder owner) =>
        find.descendant(of: owner, matching: find.byType(BotScreenPreview));

    await tester.pumpWidget(app(withNewer: false));
    await tester.pump();
    await settle(tester);
    expect(drawn(old), findsOne);

    await tester.pumpWidget(app(withNewer: true));
    await tester.pump();
    await settle(tester);
    await tester.pump();
    expect(drawn(recent), findsOne);
    expect(drawn(old), findsNothing);

    await tester.pumpWidget(app(withNewer: false));
    await tester.pump();
    await settle(tester);
    await tester.pump();
    expect(drawn(old), findsOne);
    await end(tester);
  });
}
