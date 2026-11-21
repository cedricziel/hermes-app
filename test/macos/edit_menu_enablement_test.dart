import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_menu_bar.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/macos/menu_selection_area.dart';

import 'mac_menu_bar_test.dart' show FakeMenuChannel;

// Flutter records an edit on the undo stack after a short pause.
const _undoSettles = Duration(seconds: 1);

const _items = ['Undo', 'Redo', 'Cut', 'Copy', 'Paste', 'Select All'];

void main() {
  setUp(() => MacWindow.enabled = true);
  tearDown(() => MacWindow.enabled = false);

  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  String? clipboard;

  void mockClipboard(WidgetTester tester, {String? text}) {
    clipboard = text;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String;
          case 'Clipboard.getData':
            return {'text': clipboard};
          case 'Clipboard.hasStrings':
            return {'value': clipboard != null && clipboard!.isNotEmpty};
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
  }

  Future<FakeMenuChannel> pump(WidgetTester tester, Widget home) async {
    final channel = FakeMenuChannel(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            MacMenuBar(navigatorKey: navigatorKey, child: child!),
        home: Scaffold(body: home),
      ),
    );
    await tester.pump();
    return channel;
  }

  /// The Edit items that are on, in menu order.
  Set<String> on(FakeMenuChannel channel) => {
    for (final label in _items)
      if (channel.enabled('Edit', label)) label,
  };

  testWidgets('without focus all six items are off', (tester) async {
    mockClipboard(tester, text: 'on the pasteboard');
    final channel = await pump(tester, const Text('nothing to edit'));
    expect(on(channel), isEmpty);
  }, variant: mac);

  group('in a text field', () {
    late TextEditingController text;

    setUp(() {
      text = TextEditingController();
    });

    tearDown(() {
      text.dispose();
    });

    Future<FakeMenuChannel> pumpField(
      WidgetTester tester, {
      bool readOnly = false,
      bool obscure = false,
      UndoHistoryController? undo,
    }) async {
      final channel = await pump(
        tester,
        TextField(
          controller: text,
          autofocus: true,
          readOnly: readOnly,
          obscureText: obscure,
          undoController: undo,
        ),
      );
      await tester.pump();
      await tester.pump();
      return channel;
    }

    testWidgets('an empty field with an empty pasteboard takes Select All', (
      tester,
    ) async {
      mockClipboard(tester);
      final channel = await pumpField(tester);
      expect(on(channel), {'Select All'});
    }, variant: mac);

    testWidgets('an empty field with text on the pasteboard takes Paste', (
      tester,
    ) async {
      mockClipboard(tester, text: 'pasteboard');
      final channel = await pumpField(tester);
      expect(on(channel), {'Paste', 'Select All'});
    }, variant: mac);

    testWidgets('a selection turns on Cut and Copy', (tester) async {
      mockClipboard(tester);
      text.text = 'first line second';
      final channel = await pumpField(tester);
      expect(on(channel), {'Select All'});
      text.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();
      expect(on(channel), {'Cut', 'Copy', 'Select All'});
      text.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      expect(on(channel), {'Select All'});
    }, variant: mac);

    Future<void> type(WidgetTester tester, String value) async {
      await tester.enterText(find.byType(TextField), value);
      await tester.pump(_undoSettles);
      await tester.pump();
    }

    testWidgets('typing turns on Undo and undoing turns on Redo', (
      tester,
    ) async {
      mockClipboard(tester);
      final channel = await pumpField(tester);
      expect(channel.enabled('Edit', 'Undo'), isFalse);
      await type(tester, 'one');
      await type(tester, 'one two');
      expect(on(channel), containsAll(['Undo', 'Select All']));
      expect(channel.enabled('Edit', 'Redo'), isFalse);

      await channel.select('Edit', 'Undo');
      await tester.pump();
      expect(text.text, 'one');
      expect(channel.enabled('Edit', 'Redo'), isTrue);

      await channel.select('Edit', 'Redo');
      await tester.pump();
      expect(text.text, 'one two');
      expect(channel.enabled('Edit', 'Redo'), isFalse);
      expect(channel.enabled('Edit', 'Undo'), isTrue);
    }, variant: mac);

    testWidgets("a field's own undo history decides Undo and Redo", (
      tester,
    ) async {
      mockClipboard(tester);
      final undo = UndoHistoryController();
      addTearDown(undo.dispose);
      final channel = await pumpField(tester, undo: undo);
      expect(channel.enabled('Edit', 'Undo'), isFalse);
      await type(tester, 'one');
      await type(tester, 'one two');
      expect(channel.enabled('Edit', 'Undo'), isTrue);
      expect(channel.enabled('Edit', 'Redo'), isFalse);
      await channel.select('Edit', 'Undo');
      await tester.pump(_undoSettles);
      await tester.pump();
      expect(text.text, 'one');
      expect(channel.enabled('Edit', 'Redo'), isTrue);
      await channel.select('Edit', 'Undo');
      await tester.pump(_undoSettles);
      await tester.pump();
      expect(channel.enabled('Edit', 'Undo'), isFalse);
    }, variant: mac);

    testWidgets('a read-only field cannot be cut from or pasted into', (
      tester,
    ) async {
      mockClipboard(tester, text: 'pasteboard');
      text.text = 'fixed';
      final channel = await pumpField(tester, readOnly: true);
      text.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();
      expect(on(channel), {'Copy', 'Select All'});
    }, variant: mac);

    testWidgets('a password field cannot be cut or copied', (tester) async {
      mockClipboard(tester);
      text.text = 'secret';
      final channel = await pumpField(tester, obscure: true);
      text.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
      await tester.pump();
      expect(on(channel), {'Select All'});
    }, variant: mac);

    testWidgets('the items go off again when focus leaves the field', (
      tester,
    ) async {
      mockClipboard(tester, text: 'pasteboard');
      final channel = await pumpField(tester);
      expect(on(channel), isNotEmpty);
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(on(channel), isEmpty);
    }, variant: mac);
  });

  group('in the transcript', () {
    testWidgets('selected text keeps Copy on and nothing else', (tester) async {
      mockClipboard(tester, text: 'pasteboard');
      final channel = await pump(
        tester,
        const Center(child: MenuSelectionArea(child: Text('reply text'))),
      );
      expect(on(channel), isEmpty);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('reply text')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pump(kDoubleTapMinTime);
      await gesture.down(tester.getCenter(find.text('reply text')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(on(channel), {'Copy'});

      await channel.select('Edit', 'Copy');
      expect(clipboard, anyOf('reply', 'text'));

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      expect(on(channel), isEmpty);
    }, variant: mac);
  });
}
