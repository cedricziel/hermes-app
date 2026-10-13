import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/navigation/desktop_navigation_history.dart';
import 'package:hermes_app/src/widgets/root_navigation_queue.dart';

class _HeldWillPopRoute extends MaterialPageRoute<void> {
  _HeldWillPopRoute(this.answer)
    : super(
        settings: const RouteSettings(
          arguments: WorkersNavigationTarget(boardSlug: 'ops'),
        ),
        builder: (_) => const Scaffold(body: Text('guarded workers')),
      );
  final Future<RoutePopDisposition> answer;

  @override
  Future<RoutePopDisposition> willPop() => answer;
}

void main() {
  late GlobalKey<NavigatorState> key;
  late DesktopNavigationHistory history;
  late bool allowed;
  const target = WorkersNavigationTarget(boardSlug: 'ops');

  Future<void> pump(WidgetTester tester) async {
    key = GlobalKey<NavigatorState>();
    allowed = true;
    history = DesktopNavigationHistory(
      canNavigate: () => allowed,
      resolve: (_) async => MaterialPageRoute<void>(
        settings: const RouteSettings(arguments: target),
        builder: (_) => const Scaffold(body: Text('workers')),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [history],
        home: const Scaffold(body: Text('root')),
      ),
    );
    addTearDown(history.dispose);
  }

  Route<void> detail({bool guarded = false, bool eligible = true}) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(arguments: eligible ? target : null),
        builder: (_) => PopScope(
          canPop: !guarded,
          child: const Scaffold(body: Text('workers')),
        ),
      );

  testWidgets('successful eligible Back reconstructs Forward', (tester) async {
    await pump(tester);
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isTrue);
    await history.forward();
    await tester.pumpAndSettle();
    expect(find.text('workers'), findsOneWidget);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('refused Back leaves route and history intact', (tester) async {
    await pump(tester);
    unawaited(key.currentState!.push(detail(guarded: true)));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    expect(find.text('workers'), findsOneWidget);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('new ineligible page clears Forward branch', (tester) async {
    await pump(tester);
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    unawaited(key.currentState!.push(detail(eligible: false)));
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isFalse);
  });

  testWidgets('modal pauses Forward without entering history', (tester) async {
    await pump(tester);
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: key.currentContext!,
        builder: (_) => const AlertDialog(title: Text('modal')),
      ),
    );
    await tester.pumpAndSettle();
    expect(history.canGoForward, isFalse);
    await history.back();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isTrue);
  });

  testWidgets('programmatic pop does not create Forward', (tester) async {
    await pump(tester);
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isFalse);
  });

  testWidgets('external queue unwind does not create Forward', (tester) async {
    await pump(tester);
    final root = history.currentRoute!;
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    var committed = false;
    final queue = RootNavigationQueue(
      navigator: key.currentState!,
      root: root,
      canNavigate: () => true,
      history: history,
    );
    addTearDown(queue.dispose);
    queue.request((_) => committed = true);
    await tester.pumpAndSettle();
    expect(committed, isTrue);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('gate prevents Back and Forward', (tester) async {
    await pump(tester);
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    allowed = false;
    await history.back();
    await tester.pumpAndSettle();
    expect(find.text('workers'), findsOneWidget);
    expect(history.canGoBack, isFalse);
  });

  testWidgets('branch invalidation cancels pending resolution', (tester) async {
    await pump(tester);
    final resolved = Completer<Route<void>?>();
    history.resolve = (_) => resolved.future;
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    final replay = history.forward();
    history.clear();
    resolved.complete(detail());
    await replay;
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(history.canGoForward, isFalse);
  });
  testWidgets('late modal cancels Forward resolution', (tester) async {
    await pump(tester);
    final resolved = Completer<Route<void>?>();
    history.resolve = (_) => resolved.future;
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    final replay = history.forward();
    unawaited(
      showDialog<void>(
        context: key.currentContext!,
        builder: (_) => const AlertDialog(title: Text('modal')),
      ),
    );
    await tester.pumpAndSettle();
    resolved.complete(detail());
    await replay;
    await tester.pumpAndSettle();
    expect(find.text('modal'), findsOneWidget);
    expect(find.text('workers'), findsNothing);
  });

  testWidgets('async discard guard records only accepted Back', (tester) async {
    await pump(tester);
    var dirty = true;
    unawaited(
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: target),
          builder: (context) => PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final discard = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep editing'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              );
              if (discard == true && context.mounted) {
                dirty = false;
                Navigator.pop(context);
              }
            },
            child: const Scaffold(body: Text('editor')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
    expect(history.canGoForward, isFalse);
    await history.back();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(history.canGoForward, isTrue);
  });

  testWidgets('history breadcrumbs contain fixed outcomes only', (
    tester,
  ) async {
    await pump(tester);
    final trail = BreadcrumbTrail();
    history.breadcrumbs = Breadcrumbs.of(trail);
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    await history.forward();
    await tester.pumpAndSettle();
    expect(
      [for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}'],
      [
        'nav.history.back {outcome: popped}',
        'nav.history.forward {outcome: opened}',
      ],
    );
  });
  testWidgets('unavailable Forward leaves current page intact', (tester) async {
    await pump(tester);
    history.resolve = (_) async => null;
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    await history.forward();
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(history.canGoForward, isFalse);
  });

  testWidgets('gate pause retains pending Forward', (tester) async {
    await pump(tester);
    final resolved = Completer<Route<void>?>();
    history.resolve = (_) => resolved.future;
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    final replay = history.forward();
    allowed = false;
    history.gateChanged();
    resolved.complete(detail());
    await replay;
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(history.canGoForward, isFalse);
    allowed = true;
    history.gateChanged();
    expect(history.canGoForward, isTrue);
  });
  testWidgets('cancelled external unwind releases history suppression', (
    tester,
  ) async {
    await pump(tester);
    final root = history.currentRoute!;
    final canPop = ValueNotifier(false);
    addTearDown(canPop.dispose);
    unawaited(
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: target),
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: canPop,
            builder: (_, value, _) => PopScope(
              canPop: value,
              child: const Scaffold(body: Text('workers')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    var committed = false;
    final queue = RootNavigationQueue(
      navigator: key.currentState!,
      root: root,
      canNavigate: () => true,
      history: history,
    );
    addTearDown(queue.dispose);
    queue.request((_) => committed = true);
    await tester.pumpAndSettle();
    queue.cancel();
    await tester.pump();
    canPop.value = true;
    await tester.pump();
    await history.back();
    await tester.pumpAndSettle();
    expect(committed, isFalse);
    expect(find.text('root'), findsOneWidget);
    expect(history.canGoForward, isTrue);
  });
  testWidgets('cancel then new request keeps newest external intent', (
    tester,
  ) async {
    await pump(tester);
    final root = history.currentRoute!;
    final canPop = ValueNotifier(false);
    addTearDown(canPop.dispose);
    unawaited(
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: target),
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: canPop,
            builder: (_, value, _) => PopScope(
              canPop: value,
              child: const Scaffold(body: Text('workers')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final committed = <String>[];
    final queue = RootNavigationQueue(
      navigator: key.currentState!,
      root: root,
      canNavigate: () => true,
      history: history,
    );
    addTearDown(queue.dispose);
    queue.request((_) => committed.add('old'));
    await tester.pumpAndSettle();
    queue.cancel();
    queue.request((_) => committed.add('new'));
    await tester.pump();
    canPop.value = true;
    await tester.pump();
    await history.back();
    await tester.pumpAndSettle();
    expect(committed, ['new']);
    expect(find.text('root'), findsOneWidget);
    expect(history.canGoForward, isFalse);
  });
  testWidgets('cancel releases suppression while framework willPop is held', (
    tester,
  ) async {
    await pump(tester);
    final root = history.currentRoute!;
    final answer = Completer<RoutePopDisposition>();
    unawaited(key.currentState!.push(_HeldWillPopRoute(answer.future)));
    await tester.pumpAndSettle();
    unawaited(key.currentState!.push(detail()));
    await tester.pumpAndSettle();
    await history.back();
    await tester.pumpAndSettle();
    expect(history.canGoForward, isTrue);
    final committed = <String>[];
    final queue = RootNavigationQueue(
      navigator: key.currentState!,
      root: root,
      canNavigate: () => true,
      history: history,
    );
    addTearDown(queue.dispose);
    queue.request((_) => committed.add('retired'));
    await tester.pumpAndSettle();
    queue.cancel();
    await tester.pump();
    expect(history.canGoForward, isTrue);
    expect(answer.isCompleted, isFalse);
    answer.complete(RoutePopDisposition.doNotPop);
    await tester.pumpAndSettle();
    expect(committed, isEmpty);
    expect(find.text('guarded workers'), findsOneWidget);
    queue.request((_) => committed.add('newest'));
    await tester.pumpAndSettle();
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(committed, ['newest']);
    expect(history.canGoForward, isFalse);
  });
}
