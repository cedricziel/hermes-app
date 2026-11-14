import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/toolset_risk.dart';
import 'package:hermes_app/src/tools/widgets/risk_note.dart';
import 'package:hermes_app/src/tools/widgets/toolset_detail_body.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';

import 'pump_tools.dart';

ToolsetDetailView _view({
  bool risky = false,
  bool needsSetup = false,
  String? error,
  bool unconfirmed = false,
  bool tryAgain = false,
  List<String> tools = const ['process', 'terminal'],
}) => ToolsetDetailView(
  name: 'Terminal',
  sentence: 'Run commands on the machine where Hermes runs.',
  enabled: true,
  needsSetup: needsSetup,
  where: 'Used in your chats in this app and in the terminal.',
  risk: risky ? toolsetRisk('terminal') : null,
  tools: tools,
  error: error,
  unconfirmed: unconfirmed,
  showTryAgain: tryAgain,
);

Widget _body(
  ToolsetDetailView view, {
  List<Widget> setup = const [],
  Widget? note,
  VoidCallback? onTryAgain,
  bool open = false,
}) => SizedBox(
  height: 900,
  child: ToolsetDetailBody(
    view: view,
    onChanged: (_) {},
    onTryAgain: onTryAgain,
    note: note,
    setup: setup,
    namesOpen: open,
  ),
);

void main() {
  testWidgets('shows header, risk note, where it applies and the names', (
    t,
  ) async {
    await pumpTools(
      t,
      _body(_view(risky: true)),
      platform: TargetPlatform.android,
    );

    expect(find.byType(ToolsetHeader), findsOneWidget);
    expect(find.byType(RiskNote), findsOneWidget);
    expect(find.text('Hermes asks before you switch it on.'), findsOneWidget);
    expect(find.text('Where it applies'), findsOneWidget);
    expect(
      find.text('Used in your chats in this app and in the terminal.'),
      findsOneWidget,
    );
    expect(find.text('What\'s inside (2)'), findsOneWidget);
    // Collapsed: the names are not in the tree until it opens.
    expect(find.text('terminal'), findsNothing);
  });

  testWidgets('opens the names in monospace with the helper line', (t) async {
    await pumpTools(t, _body(_view()));

    await t.tap(find.text('What\'s inside (2)'));
    await t.pumpAndSettle();

    expect(find.text('process'), findsOneWidget);
    expect(t.widget<Text>(find.text('process')).style?.fontFamily, 'monospace');
    expect(
      find.text('These are the names you see on tool cards in a chat.'),
      findsOneWidget,
    );
  });

  testWidgets('the opened names start at the left edge, like the title', (
    t,
  ) async {
    await pumpTools(t, _body(_view(), open: true));
    await t.pumpAndSettle();

    final title = t.getTopLeft(find.text('What\'s inside (2)')).dx;
    expect(t.getTopLeft(find.text('process')).dx, title);
    expect(t.getTopLeft(find.text('terminal')).dx, title);
  });

  testWidgets('has no risk note for a toolset outside the table and no '
      'names section for one without tools', (t) async {
    await pumpTools(t, _body(_view(tools: const [])));

    expect(find.byType(RiskNote), findsNothing);
    expect(find.textContaining('What\'s inside'), findsNothing);
  });

  testWidgets('shows the setup slot between the note and where it applies', (
    t,
  ) async {
    await pumpTools(
      t,
      _body(_view(risky: true), setup: const [Text('SETUP SECTIONS')]),
      platform: TargetPlatform.android,
    );

    final note = t.getTopLeft(find.byType(RiskNote)).dy;
    final setup = t.getTopLeft(find.text('SETUP SECTIONS')).dy;
    final where = t.getTopLeft(find.text('Where it applies')).dy;
    expect(note, lessThan(setup));
    expect(setup, lessThan(where));
  });

  testWidgets('says why a change failed and offers Try again where it must', (
    t,
  ) async {
    var tried = 0;
    await pumpTools(
      t,
      _body(
        _view(error: 'Planning is locked.', unconfirmed: true, tryAgain: true),
        onTryAgain: () => tried++,
      ),
    );

    expect(find.text('Planning is locked.'), findsOneWidget);
    expect(find.text('Couldn\'t confirm.'), findsOneWidget);
    await t.tap(find.text('Try again'));
    expect(tried, 1);
  });

  testWidgets('says "Pull to refresh" when there is a pull', (t) async {
    await pumpTools(t, _body(_view(unconfirmed: true)));

    expect(find.text('Couldn\'t confirm. Pull to refresh.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('holds at the largest text size', (t) async {
    await pumpTools(
      t,
      _body(_view(risky: true, needsSetup: true, error: 'Nope.')),
      textScale: 3,
    );

    expect(t.takeException(), isNull);
    expect(find.text('Terminal'), findsOneWidget);
  });
}
