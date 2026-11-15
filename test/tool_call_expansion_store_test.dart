import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_expansion.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

ToolCall _call(String id) => ToolCall(
  id: id,
  name: 'tool_$id',
  summary: '',
  args: const {'q': 'INPUT-MARK'},
  status: ToolCallStatus.completed,
);

/// Holds a store above a group under a key that [_HostState.remount] changes,
/// as the chat list does when it mounts anew or a row scrolls out and back.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.calls,
    required this.store,
    this.scope = 'm1',
  });
  final List<ToolCall> calls;
  final ToolCallExpansionStore? store;
  final String scope;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var _mounts = 0;
  void remount() => setState(() => _mounts++);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: KeyedSubtree(
          key: ValueKey(_mounts),
          child: ToolCallGroup(
            calls: widget.calls,
            expansion: widget.store,
            expansionScope: widget.scope,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final host = GlobalKey<_HostState>();
  final input = find.textContaining('INPUT-MARK');

  Future<void> pumpHost(
    WidgetTester tester,
    List<ToolCall> calls,
    ToolCallExpansionStore? store, {
    String scope = 'm1',
  }) => tester.pumpWidget(
    _Host(key: host, calls: calls, store: store, scope: scope),
  );

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> remount(WidgetTester tester) async {
    host.currentState!.remount();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('an opened lone card is open after a remount', (tester) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('a')], store);
    await tapIt(tester, find.byType(ToolCallCard));
    expect(input, findsOneWidget);

    await remount(tester);

    expect(input, findsOneWidget);
  });

  testWidgets('an opened group and its opened card survive a remount', (
    tester,
  ) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('a'), _call('b')], store);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.byType(ToolCallCard).first);
    expect(input, findsOneWidget);

    await remount(tester);

    expect(find.byType(ToolCallCard), findsNWidgets(2));
    expect(input, findsOneWidget);
  });

  testWidgets('a folded group stays folded after a remount', (tester) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('a'), _call('b')], store);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.text('Used 2 tools'));
    expect(find.byType(ToolCallCard), findsNothing);

    await remount(tester);

    expect(find.byType(ToolCallCard), findsNothing);
  });

  testWidgets('a closed card stays closed after a remount', (tester) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('a')], store);
    await tapIt(tester, find.byType(ToolCallCard));
    await tapIt(tester, find.byType(ToolCallCard));

    await remount(tester);

    expect(input, findsNothing);
  });

  testWidgets('without a store a remount closes them, as before', (
    tester,
  ) async {
    await pumpHost(tester, [_call('a')], null);
    await tapIt(tester, find.byType(ToolCallCard));
    expect(input, findsOneWidget);

    await remount(tester);

    expect(input, findsNothing);
  });

  testWidgets('runs of different messages do not share state', (tester) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('a')], store, scope: 'm1');
    await tapIt(tester, find.byType(ToolCallCard));

    await pumpHost(tester, [_call('a')], store, scope: 'm2');
    await remount(tester);

    expect(input, findsNothing);
  });

  testWidgets('cleared, nothing is open after a remount', (tester) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('a'), _call('b')], store);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.byType(ToolCallCard).first);

    store.clear();
    await remount(tester);

    expect(find.byType(ToolCallCard), findsNothing);
    expect(store.isEmpty, isTrue);
  });

  testWidgets('a call that gets its id keeps its open card in the store', (
    tester,
  ) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call('')], store);
    await tapIt(tester, find.byType(ToolCallCard));
    expect(store.cardOpen('m1', 'at:0'), isTrue);

    await pumpHost(tester, [_call('a')], store);
    await tester.pump();

    expect(store.cardOpen('m1', 'id:a'), isTrue);
    expect(store.cardOpen('m1', 'at:0'), isFalse);
  });

  testWidgets('a re-split run drops the positional keys it no longer has', (
    tester,
  ) async {
    final store = ToolCallExpansionStore();
    await pumpHost(tester, [_call(''), _call('')], store);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.byType(ToolCallCard).last);
    expect(store.cardOpen('m1', 'at:1'), isTrue);

    await pumpHost(tester, [_call('')], store);
    await tester.pump();

    expect(store.cardOpen('m1', 'at:1'), isFalse);
  });
}
