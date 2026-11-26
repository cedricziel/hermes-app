import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoActionSheet;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/code_tool_body.dart';
import 'package:hermes_app/src/chat/widgets/link_preview_card.dart';
import 'package:material_ui/material_ui.dart';

import 'support/pump_on_platform.dart';

const _page = 'https://example.com/docs/start?x=1';

Future<void> _pump(
  WidgetTester tester,
  LinkPreviewCard card, {
  TargetPlatform platform = TargetPlatform.android,
}) => pumpOnPlatform(
  tester,
  Align(alignment: Alignment.topLeft, child: card),
  platform: platform,
);

LinkPreviewCard _card(
  String address, {
  LinkPreviewState state = LinkPreviewState.ready,
  List<CodeNote> notes = const [],
  required ValueChanged<Uri>? onOpen,
}) => LinkPreviewCard(
  address: address,
  title: 'Getting started',
  excerpt: 'Install it, then run the first command.',
  state: state,
  runningLabel: 'Opening…',
  notes: notes,
  onOpen: onOpen,
);

/// Collects what the card puts on the clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

Future<void> _longPress(WidgetTester tester) async {
  await tester.longPress(find.byType(LinkPreviewCard));
  // Not settled: a running card's progress bar never stops.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('a tap calls onOpen with the address', (tester) async {
    final opened = <Uri>[];
    await _pump(tester, _card(_page, onOpen: opened.add));
    await tester.tap(find.text('Getting started'));
    expect(opened, [Uri.parse(_page)]);
  });

  testWidgets('shows the title, the host and path and the excerpt', (
    tester,
  ) async {
    await _pump(tester, _card(_page, onOpen: (_) {}));
    expect(find.text('Getting started'), findsOneWidget);
    expect(
      find.textContaining('example.com/docs/start?x=1', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Install it, then run the first command.'), findsOne);
    expect(find.text('E'), findsOneWidget);
  });

  group('a page with no tap', () {
    for (final state in [LinkPreviewState.failed, LinkPreviewState.running]) {
      testWidgets('$state', (tester) async {
        final opened = <Uri>[];
        await _pump(tester, _card(_page, state: state, onOpen: opened.add));
        await tester.tap(find.text('Getting started'));
        await _longPress(tester);
        expect(opened, isEmpty);
        expect(find.text('Open in browser'), findsNothing);
        expect(find.text('Copy link'), findsNothing);
      });
    }

    testWidgets('a running page says it is opening', (tester) async {
      await _pump(
        tester,
        _card(_page, state: LinkPreviewState.running, onOpen: (_) {}),
      );
      expect(find.text('Opening…'), findsOneWidget);
    });

    testWidgets('a failed page shows its note', (tester) async {
      await _pump(
        tester,
        _card(
          _page,
          state: LinkPreviewState.failed,
          notes: const [
            CodeNote(
              CodeNoteTone.error,
              "Couldn't read this page.",
              detail: 'Timed out.',
            ),
          ],
          onOpen: (_) {},
        ),
      );
      expect(find.text("Couldn't read this page."), findsOneWidget);
      expect(find.text('Timed out.'), findsOneWidget);
    });
  });

  group('the press menu', () {
    testWidgets('of a web address opens it or copies it', (tester) async {
      final opened = <Uri>[];
      final copied = _clipboard(tester);
      await _pump(tester, _card(_page, onOpen: opened.add));

      await _longPress(tester);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied, [_page]);

      await _longPress(tester);
      await tester.tap(find.text('Open in browser'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(_page)]);
    });

    testWidgets('is an action sheet on iOS', (tester) async {
      await _pump(
        tester,
        _card(_page, onOpen: (_) {}),
        platform: TargetPlatform.iOS,
      );
      await _longPress(tester);
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    });

    testWidgets('of an address with credentials only copies it, without them', (
      tester,
    ) async {
      final opened = <Uri>[];
      final copied = _clipboard(tester);
      await _pump(
        tester,
        _card('https://user:secret@example.com/private', onOpen: opened.add),
      );
      expect(find.textContaining('secret', findRichText: true), findsNothing);
      expect(find.textContaining('user:', findRichText: true), findsNothing);
      expect(find.textContaining('example.com', findRichText: true), findsOne);

      await tester.tap(find.text('Getting started'));
      expect(opened, isEmpty);

      await _longPress(tester);
      expect(find.text('Open in browser'), findsNothing);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied, ['https://example.com/private']);
      expect(
        find.text('Not opened: the address holds a user name or password.'),
        findsOneWidget,
      );
    });

    testWidgets('of another scheme has neither entry', (tester) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        _card('ftp://files.example.com/a.txt', onOpen: opened.add),
      );
      await tester.tap(find.text('Getting started'));
      await _longPress(tester);
      expect(opened, isEmpty);
      expect(find.text('Open in browser'), findsNothing);
      expect(find.text('Copy link'), findsNothing);
      expect(
        find.text('Not opened: only web addresses open from here'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a copy the clipboard refuses is reported, not thrown', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final reported = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => reported.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);
    await _pump(tester, _card(_page, onOpen: (_) {}));
    await _longPress(tester);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      reported.whereType<PlatformException>(),
      isEmpty,
      reason: 'the failure must not reach the framework unhandled',
    );
  });

  testWidgets('a title with no spaces stays inside the card', (tester) async {
    await _pump(
      tester,
      LinkPreviewCard(
        address: 'https://${'a' * 80}.example.com/${'b' * 200}',
        title: 'W' * 300,
        onOpen: (_) {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LinkPreviewCard)).width, 393);
  });
}
