import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/secret_field_row.dart';

Widget _host(Widget child, {TargetPlatform platform = TargetPlatform.iOS}) =>
    MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: platform),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    bool busy = false,
    int? hideSignal,
    bool enabled = true,
    TargetPlatform platform = TargetPlatform.iOS,
  }) => tester.pumpWidget(
    _host(
      SecretFieldRow(
        label: 'API key',
        controller: controller,
        busy: busy,
        hideSignal: hideSignal,
        enabled: enabled,
      ),
      platform: platform,
    ),
  );

  Future<void> show(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Show key'));
    await tester.pump();
  }

  testWidgets('starts hidden and Show key reveals, Hide key hides', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(_editable(tester).obscureText, isTrue);
    expect(find.bySemanticsLabel('Hide key'), findsNothing);

    await show(tester);
    expect(_editable(tester).obscureText, isFalse);
    expect(find.bySemanticsLabel('Show key'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Hide key'));
    await tester.pump();
    expect(_editable(tester).obscureText, isTrue);
    handle.dispose();
  });

  testWidgets('says how many characters were typed, never when empty', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('character'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pump();
    expect(find.text('1 character entered'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'sk-12345');
    await tester.pump();
    expect(find.text('8 characters entered'), findsOneWidget);

    controller.clear();
    await tester.pump();
    expect(find.textContaining('character'), findsNothing);
  });

  testWidgets('the count line is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.enterText(find.byType(EditableText), 'abc');
    await tester.pump();
    expect(
      tester.getSemantics(find.text('3 characters entered')),
      isSemantics(label: '3 characters entered', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets(
    'hides a shown value whenever the app leaves resumed, text kept',
    (tester) async {
      void go(List<AppLifecycleState> path) {
        for (final state in path) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      await pump(tester);
      await tester.enterText(find.byType(EditableText), 'secret');
      final cases = {
        'inactive': [AppLifecycleState.inactive],
        'hidden': [AppLifecycleState.inactive, AppLifecycleState.hidden],
        'paused': [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ],
      };
      for (final MapEntry(key: name, value: path) in cases.entries) {
        await show(tester);
        expect(_editable(tester).obscureText, isFalse, reason: name);

        go(path);
        await tester.pump();
        expect(_editable(tester).obscureText, isTrue, reason: name);
        expect(controller.text, 'secret');

        go([...path.reversed.skip(1), AppLifecycleState.resumed]);
        await tester.pump();
        expect(_editable(tester).obscureText, isTrue, reason: 'resumed $name');
      }
    },
  );

  testWidgets('hides a shown value when a check or save starts', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(EditableText), 'secret');
    await show(tester);
    await pump(tester, busy: true);
    expect(_editable(tester).obscureText, isTrue);
    expect(controller.text, 'secret');
  });

  testWidgets('hides a shown value after a failed save, text kept', (
    tester,
  ) async {
    await pump(tester, hideSignal: 0);
    await tester.enterText(find.byType(EditableText), 'secret');
    await show(tester);
    await pump(tester, hideSignal: 0);
    expect(_editable(tester).obscureText, isFalse);

    await pump(tester, hideSignal: 1);
    expect(_editable(tester).obscureText, isTrue);
    expect(controller.text, 'secret');
  });

  testWidgets('the shown state is not kept by a new row', (tester) async {
    await pump(tester);
    await show(tester);
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(_editable(tester).obscureText, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).restorationId,
      isNull,
    );
  });

  testWidgets('stops listening to the lifecycle when it goes away', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('turns off autofill, suggestions and smart punctuation', (
    tester,
  ) async {
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.autofillHints, isNull);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
    expect(field.maxLines, 1);
    expect(field.textCapitalization, TextCapitalization.none);
  });

  testWidgets('Android asks for the visible-password keyboard', (tester) async {
    await pump(tester, platform: TargetPlatform.android);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.visiblePassword,
    );
  });

  testWidgets('the toggle is 44 pt on iOS and 48 dp on Android', (
    tester,
  ) async {
    await pump(tester);
    var size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    await pump(tester, platform: TargetPlatform.android);
    size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('on a Mac the toggle is a standard text button', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, platform: TargetPlatform.macOS);
    expect(find.byType(IconButton), findsNothing);
    expect(find.widgetWithText(TextButton, 'Show'), findsOneWidget);
    expect(find.bySemanticsLabel('Show key'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Show'));
    await tester.pump();
    expect(find.widgetWithText(TextButton, 'Hide'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide key'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the Mac toggle works from the accessibility tree', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, platform: TargetPlatform.macOS);
    tester.semantics.tap(find.semantics.byLabel('Show key'));
    await tester.pump();
    expect(_editable(tester).obscureText, isFalse);
    expect(find.bySemanticsLabel('Hide key'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a disabled Mac form cannot reveal the value', (tester) async {
    await pump(tester, enabled: false, platform: TargetPlatform.macOS);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });

  testWidgets('while busy the value stays hidden and the toggle is off', (
    tester,
  ) async {
    await pump(tester, busy: true);
    expect(_editable(tester).obscureText, isTrue);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a disabled form cannot reveal the value', (tester) async {
    await pump(tester, enabled: false);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });

  testWidgets('never writes the typed value to the log', (tester) async {
    final lines = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => lines.add(message);
    try {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), 'sk-very-secret');
      await show(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
    } finally {
      debugPrint = original;
    }
    expect(lines.join(), isNot(contains('sk-very-secret')));
  });

  testWidgets('a trailing control shows on every Apple layout', (tester) async {
    for (final lines in [1, 3]) {
      await tester.pumpWidget(
        _host(
          GroupedTextFieldRow(
            label: 'Notes',
            controller: controller,
            maxLines: lines,
            trailing: const Text('END'),
          ),
        ),
      );
      expect(find.text('END'), findsOneWidget, reason: 'maxLines $lines');
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('the label wraps at word breaks, not per character, at the '
        'largest text size on $platform', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecretFieldRow(
                label: 'Brightfetch API key',
                controller: controller,
              ),
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Brightfetch API key'),
      );
      final lines = {
        for (final box in paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 19),
        ))
          box.top,
      };
      // Whole words per line: far fewer lines than characters, and the
      // label gets the row's width rather than a sliver beside the field.
      expect(lines.length, lessThanOrEqualTo(4));
      expect(paragraph.size.width, greaterThan(200));
    });
  }
}
