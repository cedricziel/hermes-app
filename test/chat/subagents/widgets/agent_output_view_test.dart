import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_output_view.dart';

const _text =
    '12:04:31 tool    | -> read_file(path="go.sum")\n'
    '12:04:32 result  | 212 lines';

Future<void> _pump(
  WidgetTester tester,
  AgentOutputModel model, {
  VoidCallback? onJump,
  ValueChanged<bool>? onHolding,
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
  Size size = const Size(360, 800),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AgentOutputView(
            model: model,
            onJumpToLatest: onJump ?? () {},
            onHolding: onHolding,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('streaming shows the title, truncation note and text', (
    tester,
  ) async {
    await _pump(tester, const AgentOutputModel(text: _text, truncated: true));
    expect(find.text('Recent output'), findsOneWidget);
    expect(find.text('Showing the latest output'), findsOneWidget);
    expect(find.textContaining('read_file'), findsOneWidget);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('loading, none and never replace the box', (tester) async {
    await _pump(
      tester,
      const AgentOutputModel(status: AgentOutputStatus.loading),
    );
    expect(find.text('Reading output…'), findsOneWidget);
    expect(find.byType(SelectionArea), findsNothing);
    await _pump(tester, const AgentOutputModel(status: AgentOutputStatus.none));
    expect(find.text('No output yet'), findsOneWidget);
    await _pump(
      tester,
      const AgentOutputModel(status: AgentOutputStatus.never),
    );
    expect(find.text("Output isn't available here."), findsOneWidget);
    expect(find.byType(SelectionArea), findsNothing);
  });

  testWidgets('refresh failure keeps the text; last output retitles', (
    tester,
  ) async {
    await _pump(
      tester,
      const AgentOutputModel(text: _text, refreshFailed: true, last: true),
    );
    expect(find.text("Couldn't refresh the output."), findsOneWidget);
    expect(find.text('Last output'), findsOneWidget);
    expect(find.text('Recent output'), findsNothing);
    expect(find.textContaining('read_file'), findsOneWidget);
  });

  testWidgets('German copy', (tester) async {
    await _pump(
      tester,
      const AgentOutputModel(text: _text, paused: true),
      locale: const Locale('de'),
    );
    final de = lookupAppLocalizations(const Locale('de'));
    expect(find.text(de.chatSubagentsOutputTitle), findsOneWidget);
    expect(find.text(de.chatSubagentsOutputPaused), findsOneWidget);
    expect(find.text(de.chatSubagentsOutputJump), findsOneWidget);
  });

  testWidgets('paused shows the pill and Jump calls back', (tester) async {
    var jumped = 0;
    await _pump(
      tester,
      const AgentOutputModel(text: _text, paused: true),
      onJump: () => jumped++,
    );
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Jump to latest'));
    expect(jumped, 1);
  });

  for (final (platform, height) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
    (TargetPlatform.macOS, 28.0),
  ]) {
    testWidgets('Jump to latest is $height tall on $platform', (tester) async {
      await _pump(
        tester,
        const AgentOutputModel(text: _text, paused: true),
        platform: platform,
      );
      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, height);
    });
  }

  testWidgets('text is selectable plain text; links and markdown stay text', (
    tester,
  ) async {
    const link = '12:04:31 result  | see https://example.com **bold** [a](b)';
    await _pump(tester, const AgentOutputModel(text: link));
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.textContaining('https://example.com'), findsOneWidget);
    expect(find.textContaining('**bold** [a](b)'), findsOneWidget);
    final text = tester.widget<Text>(find.textContaining('https://'));
    expect(text.textSpan, isNull);
    final box = find.descendant(
      of: find.byType(AgentOutputView),
      matching: find.byType(GestureDetector),
    );
    for (final g in tester.widgetList<GestureDetector>(box)) {
      expect(g.onTap, isNull);
    }
    expect(
      find.descendant(
        of: find.byType(AgentOutputView),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && _hasRecognizer(w.text),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('the output area is labelled and not a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const AgentOutputModel(text: _text));
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Agent output')),
    );
    expect(node.label, contains('Agent output'));
    expect(node.flagsCollection.isLiveRegion, isFalse);
    expect(node.flagsCollection.isFocused.toString(), isNot('true'));
    handle.dispose();
  });

  testWidgets('long lines wrap under the message column, no sideways scroll', (
    tester,
  ) async {
    final long = '12:04:44 model    | ${'word ' * 40}';
    await _pump(
      tester,
      AgentOutputModel(text: long),
      size: const Size(320, 800),
    );
    final prefix = tester.getTopLeft(find.textContaining('12:04:44'));
    final body = tester.getTopLeft(find.textContaining('word word'));
    expect(body.dx, greaterThan(prefix.dx + 100));
    final bodySize = tester.getSize(find.textContaining('word word'));
    expect(bodySize.height, greaterThan(40));
    expect(tester.takeException(), isNull);
    final scrolls = tester.widgetList<SingleChildScrollView>(
      find.descendant(
        of: find.byType(AgentOutputView),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    for (final s in scrolls) {
      expect(s.scrollDirection, Axis.vertical);
    }
  });

  testWidgets('largest text drops the indent and keeps five lines', (
    tester,
  ) async {
    const short = '12:04:31 tool    | one\n12:04:32 tool    | two';
    await _pump(
      tester,
      const AgentOutputModel(text: short),
      scale: 3,
      size: const Size(390, 900),
    );
    final first = tester.getTopLeft(find.textContaining('12:04:31'));
    expect(tester.getTopLeft(find.textContaining('one')).dx, first.dx);
    expect(find.textContaining('12:04:31 tool    | one'), findsOneWidget);
    final text = tester.widget<Text>(find.textContaining('12:04:31'));
    final style = text.style!;
    expect(style.fontSize, 13);
    final lineHeight = 13 * 1.4 * 3;
    final boxHeight = tester
        .getSize(
          find
              .ancestor(
                of: find.byType(SelectionArea),
                matching: find.byType(Container),
              )
              .first,
        )
        .height;
    expect(boxHeight, greaterThanOrEqualTo(5 * lineHeight));
  });

  testWidgets('reports holding when scrolled away from the end', (
    tester,
  ) async {
    final events = <bool>[];
    final many = List.generate(
      80,
      (i) => '12:04:${(i % 60).toString().padLeft(2, '0')} tool    | line $i',
    ).join('\n');
    await _pump(tester, AgentOutputModel(text: many), onHolding: events.add);
    await tester.pump();
    await tester.drag(find.byType(SelectionArea), const Offset(0, 300));
    await tester.pump();
    expect(events, [true]);
  });

  testWidgets('Jump to latest ends the hold', (tester) async {
    final events = <bool>[];
    final many = List.generate(
      80,
      (i) => '12:04:${(i % 60).toString().padLeft(2, '0')} tool    | line $i',
    ).join('\n');
    await _pump(tester, AgentOutputModel(text: many), onHolding: events.add);
    await tester.pump();
    await tester.drag(find.byType(SelectionArea), const Offset(0, 300));
    await tester.pump();
    await _pump(
      tester,
      AgentOutputModel(text: many, paused: true),
      onHolding: events.add,
    );
    await tester.pump();
    await tester.tap(find.text('Jump to latest'));
    await tester.pump();
    expect(events, [true, false]);
  });
}

bool _hasRecognizer(InlineSpan span) {
  var found = false;
  span.visitChildren((s) {
    if (s is TextSpan && s.recognizer is TapGestureRecognizer) found = true;
    return true;
  });
  return found;
}
