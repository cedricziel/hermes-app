import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

const _report = SharedFile(path: '/tmp/a/report.pdf', name: 'report.pdf');
const _photo = SharedFile(
  path: '/tmp/a/photo.png',
  name: 'photo.png',
  isImage: true,
);

class _Harness {
  _Harness() : chatController = InMemoryChatController();

  final InMemoryChatController chatController;
  final controller = TextEditingController();
  final sent = <String>[];
  final removed = <SharedFile>[];

  Widget build({List<SharedFile> attachments = const []}) {
    return MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: FlyerMaterialScope(
          child: Chat(
            currentUserId: 'user',
            resolveUser: (id) async => User(id: id),
            chatController: chatController,
            onMessageSend: sent.add,
            builders: Builders(
              composerBuilder: buildChatComposer(
                controller: controller,
                attachments: attachments,
                onRemoveAttachment: removed.add,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The package's empty-chat placeholder starts a 50ms timer that must
  /// elapse before the test ends.
  Future<void> pump(
    WidgetTester tester, {
    List<SharedFile> attachments = const [],
  }) async {
    await tester.pumpWidget(build(attachments: attachments));
    await tester.pump(const Duration(milliseconds: 100));
  }

  void dispose() {
    controller.dispose();
    chatController.dispose();
  }
}

IconButton _sendButton(WidgetTester tester) => tester.widget<IconButton>(
  find.ancestor(
    of: find.byIcon(Icons.arrow_upward),
    matching: find.byType(IconButton),
  ),
);

void main() {
  late _Harness h;

  setUp(() => h = _Harness());
  tearDown(() => h.dispose());

  testWidgets('renders the Hermes composer with the Hermes hint', (
    tester,
  ) async {
    await h.pump(tester);

    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text('Message Hermes…'), findsOneWidget);
  });

  testWidgets('reports its height to the chat, and again as it grows', (
    tester,
  ) async {
    await h.pump(tester);
    final notifier = tester
        .element(find.byType(ChatComposer))
        .read<ComposerHeightNotifier>();
    final oneLine = tester.getSize(find.byType(ChatComposer)).height;
    expect(notifier.height, oneLine);

    await tester.enterText(find.byType(EditableText), 'a\nb\nc');
    await tester.pump();
    await tester.pump();

    final threeLines = tester.getSize(find.byType(ChatComposer)).height;
    expect(threeLines, greaterThan(oneLine));
    expect(notifier.height, threeLines);
  });

  testWidgets('Enter sends and Shift+Enter breaks the line', (tester) async {
    await h.pump(tester);
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(h.sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.sent, ['hello']);
  });

  testWidgets('shows the prefilled controller text in the field', (
    tester,
  ) async {
    h.controller.text = 'Look at this\nhttps://example.com';
    await h.pump(tester);

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller, same(h.controller));
    expect(find.text('Look at this\nhttps://example.com'), findsOneWidget);
  });

  testWidgets('renders a removable chip per attachment', (tester) async {
    await h.pump(tester, attachments: [_report, _photo]);

    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('renders no chips without attachments', (tester) async {
    await h.pump(tester);

    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('adds no note under the chips: the files are sent', (
    tester,
  ) async {
    await h.pump(tester, attachments: [_report, _photo]);

    expect(find.textContaining('file names'), findsNothing);
    expect(find.textContaining('not their contents'), findsNothing);
  });

  testWidgets('tapping a chip remove control reports that file', (
    tester,
  ) async {
    await h.pump(tester, attachments: [_report, _photo]);

    await tester.tap(find.byTooltip('Remove photo.png'));
    await tester.pump();

    expect(h.removed, [_photo]);
  });

  testWidgets('chips follow the attachments passed on rebuild', (tester) async {
    await h.pump(tester, attachments: [_report, _photo]);
    await h.pump(tester, attachments: [_report]);

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.png'), findsNothing);
  });

  testWidgets('send is disabled with no text and no attachments', (
    tester,
  ) async {
    await h.pump(tester);

    expect(_sendButton(tester).onPressed, isNull);
  });

  testWidgets(
    'typing text enables send and sending leaves the field to the screen',
    (tester) async {
      await h.pump(tester);

      await tester.enterText(find.byType(EditableText), 'hello');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(h.sent, ['hello']);
      expect(h.controller.text, 'hello');
    },
  );

  testWidgets('attachments alone are enough to send', (tester) async {
    await h.pump(tester, attachments: [_report]);

    expect(_sendButton(tester).onPressed, isNotNull);
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(h.sent, ['']);
  });
}
