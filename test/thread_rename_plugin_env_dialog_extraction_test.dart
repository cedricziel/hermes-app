import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/thread_rename_dialog.dart';
import 'package:hermes_app/src/plugins/widgets/plugin_missing_env_dialog.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

import 'support/test_localizations.dart';

/// Opens [dialog] the way the app does and records what it returns.
class _Host {
  _Host(this.tester);

  final WidgetTester tester;
  Object? result = _pending;
  static const _pending = Object();

  Future<void> open(Widget dialog, {TargetPlatform? platform}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform ?? TargetPlatform.android),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => AppThemeScopes(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAppDialog<Object>(
                  context: context,
                  builder: (_) => dialog,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool get returned => !identical(result, _pending);
}

void main() {
  group('ThreadRenameDialog', () {
    Finder save() => find.widgetWithText(FilledButton, 'Save');

    testWidgets('fills the field with the title and focuses it', (
      tester,
    ) async {
      await _Host(tester).open(const ThreadRenameDialog(initial: 'Old name'));

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, 'Old name');
      expect(field.focusNode.hasFocus, isTrue);
      expect(find.text('Rename chat'), findsOneWidget);
    });

    testWidgets('Save is off until the title has a non-blank character', (
      tester,
    ) async {
      final host = _Host(tester);
      await host.open(const ThreadRenameDialog(initial: ''));
      expect(tester.widget<FilledButton>(save()).onPressed, isNull);

      await tester.enterText(find.byType(EditableText), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(save()).onPressed, isNull);

      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(tester.widget<FilledButton>(save()).onPressed, isNotNull);
    });

    testWidgets('Save returns the trimmed title', (tester) async {
      final host = _Host(tester);
      await host.open(const ThreadRenameDialog(initial: ''));

      await tester.enterText(find.byType(EditableText), '  New name \n');
      await tester.pump();
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(host.result, 'New name');
      expect(find.text('Rename chat'), findsNothing);
    });

    testWidgets('the keyboard submit saves too, and not an empty title', (
      tester,
    ) async {
      final host = _Host(tester);
      await host.open(const ThreadRenameDialog(initial: ''));

      await tester.enterText(find.byType(EditableText), '  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(host.returned, isFalse);
      expect(find.text('Rename chat'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Typed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(host.result, 'Typed');
    });

    testWidgets('Cancel closes it with no title', (tester) async {
      final host = _Host(tester);
      await host.open(const ThreadRenameDialog(initial: 'Old name'));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(host.result, isNull);
      expect(find.text('Rename chat'), findsNothing);
    });
  });

  group('PluginMissingEnvDialog', () {
    testWidgets('lists every name in order, in monospace, under the title', (
      tester,
    ) async {
      await _Host(tester).open(
        const PluginMissingEnvDialog(missingEnv: ['B_TOKEN', 'A_KEY', 'C']),
      );

      expect(find.text('Set these on the server'), findsOneWidget);
      final names = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          )
          .where((t) => t.style?.fontFamily == 'monospace')
          .map((t) => t.data)
          .toList();
      expect(names, ['B_TOKEN', 'A_KEY', 'C']);
    });

    testWidgets('OK closes it and returns nothing', (tester) async {
      final host = _Host(tester);
      await host.open(const PluginMissingEnvDialog(missingEnv: ['API_KEY']));

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(host.result, isNull);
      expect(find.text('API_KEY'), findsNothing);
    });
  });
}
