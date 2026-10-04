import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    String query = '',
    bool active = false,
    FocusNode? focus,
  }) async {
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: MacToolbarSearchField(
              query: query,
              active: active,
              focusNode: focus,
              onChanged: (q) => events.add('changed:$q'),
              onEnd: () => events.add('end'),
              onBegin: () => events.add('begin'),
            ),
          ),
        ),
      ),
    );
    return events;
  }

  Finder field() => find.byType(MacToolbarSearchField);

  testWidgets('rests at 180 and grows to 240 while focused', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pump(tester, focus: focus);
    expect(tester.getSize(field()), const Size(180, 26));

    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(field()).width, 240);
  });

  testWidgets('getting the focus begins a search', (tester) async {
    final events = await pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(events, ['begin']);
  });

  testWidgets('typing reports the query', (tester) async {
    final events = await pump(tester);
    await tester.enterText(find.byType(TextField), 'backup');
    expect(events, ['begin', 'changed:backup']);
  });

  testWidgets('Escape ends the search', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final events = await pump(
      tester,
      query: 'backup',
      active: true,
      focus: focus,
    );
    focus.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(events, ['begin', 'end']);
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('the clear button ends the search', (tester) async {
    final events = await pump(tester, query: 'backup', active: true);
    await tester.tap(find.byKey(const Key('toolbar-search-clear')));
    expect(events, ['end']);
  });

  testWidgets('no clear button while idle', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('toolbar-search-clear')), findsNothing);
  });
}
