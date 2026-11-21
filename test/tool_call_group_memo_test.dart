import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_expansion.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/test_localizations.dart';

/// A group the parent rebuilds in place, as the chat does on every streamed
/// tick, with everything the group reads settable from outside.
class _Host extends StatefulWidget {
  const _Host({super.key, this.store});
  final ToolCallExpansionStore? store;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  List<ToolCall> calls = const [];
  Map<int, ApprovalRequest> approvals = const {};
  Future<void> Function(String, String)? answer;
  ThemeData theme = buildHermesLightTheme();
  double textScale = 1;
  Locale locale = const Locale('en');

  void update(VoidCallback change) => setState(change);

  /// A new closure over the answer given at this build, as a parent makes one
  /// per build; it never reads [answer] later.
  Future<void> Function(String, String) _closeOver(
    Future<void> Function(String, String) given,
  ) =>
      (id, choice) => given(id, choice);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: theme,
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    // The shared delegates, less the app's own strings, which have no Arabic;
    // the locale test needs a right-to-left locale.
    localizationsDelegates: [
      for (final d in kTestLocalizationsDelegates)
        if (d.isSupported(locale)) d,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ToolCallGroup(
          // A fresh list, map and closure each build, as a parent makes them.
          calls: List.of(calls),
          approvals: Map.of(approvals),
          onAnswerApproval: answer == null ? null : _closeOver(answer!),
          expansion: widget.store,
          expansionScope: 'm1',
        ),
      ),
    ),
  );
}

ToolCall _call(String id, {String result = '', ToolCallStatus? status}) =>
    ToolCall(
      id: id,
      name: 'tool_$id',
      summary: '',
      args: const {'q': 'INPUT-MARK'},
      result: result,
      status: status ?? ToolCallStatus.completed,
    );

const _ask = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: '',
  choices: ['once', 'deny'],
);

/// How many cards and card sections were rebuilt, by the framework's count.
class _Rebuilds {
  var cards = 0;
  var sections = 0;

  void start() {
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final widget = element.widget;
      if (widget is ToolCallCard) cards++;
      if (widget.runtimeType.toString() == '_Section') sections++;
    };
  }

  void reset() {
    cards = 0;
    sections = 0;
  }
}

void main() {
  final host = GlobalKey<_HostState>();
  final rebuilds = _Rebuilds();
  final input = find.textContaining('INPUT-MARK');

  tearDown(() => debugOnRebuildDirtyWidget = null);

  Future<void> mount(
    WidgetTester tester,
    List<ToolCall> calls, {
    ToolCallExpansionStore? store,
  }) async {
    await tester.pumpWidget(_Host(key: host, store: store));
    host.currentState!.update(() => host.currentState!.calls = calls);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Opens the group and its first card.
  Future<void> openFirst(WidgetTester tester) async {
    await tapIt(
      tester,
      find
          .descendant(
            of: find.byType(ToolCallGroup),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tapIt(tester, find.byType(ToolCallCard).first);
    expect(input, findsOneWidget);
  }

  Future<void> parentRebuild(WidgetTester tester) async {
    host.currentState!.update(() {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  // Kill test: fails without the cache (every rebuild reaches the open card).
  testWidgets('parent rebuilds with the same calls leave an open card alone', (
    tester,
  ) async {
    await mount(tester, [_call('a'), _call('b')]);
    await openFirst(tester);

    rebuilds.start();
    for (var i = 0; i < 5; i++) {
      await parentRebuild(tester);
    }

    expect(rebuilds.cards, 0);
    expect(rebuilds.sections, 0);
    expect(input, findsOneWidget);
  });

  // Guard: a lone call is cached the same way.
  testWidgets('a lone open card is left alone too', (tester) async {
    await mount(tester, [_call('a')]);
    await tapIt(tester, find.byType(ToolCallCard));
    expect(input, findsOneWidget);

    rebuilds.start();
    for (var i = 0; i < 5; i++) {
      await parentRebuild(tester);
    }

    expect(rebuilds.cards, 0);
    expect(rebuilds.sections, 0);
  });

  // Guard: only a naive "never rebuild" memo fails it.
  testWidgets('a changed call rebuilds and shows what changed', (tester) async {
    await mount(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);
    await openFirst(tester);
    expect(find.text('Running tool_b…'), findsOneWidget);

    host.currentState!.update(
      () => host.currentState!.calls = [
        _call('a', result: 'RESULT-MARK'),
        _call('b'),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('RESULT-MARK'), findsOneWidget);
    expect(find.text('Used 2 tools'), findsOneWidget);

    host.currentState!.update(
      () => host.currentState!.calls = [
        _call('a', result: 'RESULT-MARK'),
        _call('b'),
        _call('c'),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Used 3 tools'), findsOneWidget);
    expect(find.byType(ToolCallCard), findsNWidgets(3));
  });

  // Guard: only a memo that ignores approvals fails it.
  testWidgets('changed approvals rebuild the card that holds one', (
    tester,
  ) async {
    await mount(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);
    await openFirst(tester);
    expect(find.byType(ApprovalCard), findsNothing);

    host.currentState!.update(() => host.currentState!.approvals = {1: _ask});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Waiting on tool_b'), findsOneWidget);
    expect(find.byType(ApprovalCard), findsOneWidget);

    host.currentState!.update(
      () => host.currentState!.approvals = {
        1: _ask.withStatus(InputRequestStatus.answered),
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Waiting on tool_b'), findsNothing);
  });

  // Guard: fails when the header reads the theme in the group's own build
  // (naive memo), since that dependency would stop at the cached subtree.
  testWidgets('a theme switch shows in the header and the open card', (
    tester,
  ) async {
    await mount(tester, [_call('a'), _call('b')]);
    await openFirst(tester);

    Color? headerColor() =>
        tester.widget<Text>(find.text('Used 2 tools')).style?.color;
    Color? cardColor() {
      final box =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(ToolCallCard).first,
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      return box.color;
    }

    final lightHeader = headerColor();
    final lightCard = cardColor();
    host.currentState!.update(
      () => host.currentState!.theme = buildHermesDarkTheme(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(headerColor(), isNot(lightHeader));
    expect(cardColor(), isNot(lightCard));
    expect(input, findsOneWidget);
  });

  testWidgets('a text scale change shows in the header and the open card', (
    tester,
  ) async {
    await mount(tester, [_call('a'), _call('b')]);
    await openFirst(tester);
    final header = tester.getSize(find.text('Used 2 tools'));
    final name = tester.getSize(find.text('tool_a'));

    host.currentState!.update(() => host.currentState!.textScale = 2);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester.getSize(find.text('Used 2 tools')).width,
      greaterThan(header.width * 1.5),
    );
    expect(
      tester.getSize(find.text('tool_a')).width,
      greaterThan(name.width * 1.5),
    );
  });

  testWidgets('a locale change shows in the open card', (tester) async {
    await mount(tester, [_call('a'), _call('b')]);
    await openFirst(tester);
    double iconBeforeName() =>
        tester
            .getCenter(
              find.descendant(
                of: find.byType(ToolCallCard).first,
                matching: find.byType(ToolCallStatusIcon),
              ),
            )
            .dx -
        tester.getCenter(find.text('tool_a')).dx;
    expect(iconBeforeName(), lessThan(0));

    host.currentState!.update(
      () => host.currentState!.locale = const Locale('ar'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(iconBeforeName(), greaterThan(0));
    expect(input, findsOneWidget);
  });

  // Guard: the toggle clears the cache; open, close, open shows the card.
  testWidgets('folding and opening again shows the card the reader opened', (
    tester,
  ) async {
    await mount(tester, [_call('a'), _call('b')]);
    await openFirst(tester);

    await tapIt(tester, find.text('Used 2 tools'));
    expect(find.byType(ToolCallCard), findsNothing);
    await parentRebuild(tester);
    await tapIt(tester, find.text('Used 2 tools'));

    expect(find.byType(ToolCallCard), findsNWidgets(2));
    expect(input, findsOneWidget);
  });

  // Guard: the store, not the cache, carries expansion across a remount.
  testWidgets('the opened card survives the group mounting anew', (
    tester,
  ) async {
    final store = ToolCallExpansionStore();
    await mount(tester, [_call('a'), _call('b')], store: store);
    await openFirst(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_Host(key: GlobalKey<_HostState>(), store: store));
    final fresh = tester.state<_HostState>(find.byType(_Host));
    fresh.update(() => fresh.calls = [_call('a'), _call('b')]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ToolCallCard), findsNWidgets(2));
    expect(input, findsOneWidget);
  });

  // Kill test for a memo that keeps the callback of the build it was made in.
  testWidgets('an approval answered after a rebuild reaches the newest '
      'callback', (tester) async {
    final first = <String>[];
    final second = <String>[];
    await mount(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);
    host.currentState!.update(() {
      host.currentState!.approvals = {1: _ask};
      host.currentState!.answer = (id, choice) async =>
          first.add('$id:$choice');
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    host.currentState!.update(() {
      host.currentState!.answer = (id, choice) async =>
          second.add('$id:$choice');
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text(approvalChoiceLabels['once'] ?? 'once'));

    expect(first, isEmpty);
    expect(second, ['r1:once']);
  });

  // Kill test for a memo that ignores whether a callback is given: a card made
  // while none was set would keep refusing the answer.
  testWidgets('a callback set while an approval is pending enables its '
      'choices', (tester) async {
    final answered = <String>[];
    await mount(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);
    host.currentState!.update(() => host.currentState!.approvals = {1: _ask});
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final once = find.text(approvalChoiceLabels['once'] ?? 'once');
    expect(once, findsOneWidget);
    await tapIt(tester, once);
    expect(answered, isEmpty);

    host.currentState!.update(
      () =>
          host.currentState!.answer = (id, choice) async =>
              answered.add('$id:$choice'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, once);

    expect(answered, ['r1:once']);
  });
}
